import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/entities/social.dart';
import '../../providers/kitchen_providers.dart';
import '../../providers/social_providers.dart';
import '../../widgets/common.dart';
import '../kitchen/recipe_screen.dart';
import 'compose_story_screen.dart';
import 'social_widgets.dart';
import 'story_progress_card.dart';

/// Opens the full-screen viewer at [groupIndex] in [groups].
Future<void> openStories(BuildContext context, List<StoryGroup> groups, int groupIndex) {
  Haptics.light();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => StoryViewerScreen(groups: groups, initialGroup: groupIndex),
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(a), child: child),
      ),
    ),
  );
}

class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({super.key, required this.groups, required this.initialGroup});
  final List<StoryGroup> groups;
  final int initialGroup;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  late final _pages = PageController(initialPage: widget.initialGroup);
  double _drag = 0;

  void _nextGroup() {
    final page = _pages.page?.round() ?? widget.initialGroup;
    if (page >= widget.groups.length - 1) {
      Navigator.of(context).pop();
    } else {
      _pages.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  void _prevGroup() {
    final page = _pages.page?.round() ?? widget.initialGroup;
    if (page > 0) _pages.previousPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: GestureDetector(
        // Swipe down to close.
        onVerticalDragUpdate: (d) => setState(() => _drag = (_drag + d.delta.dy).clamp(0, 400)),
        onVerticalDragEnd: (d) {
          if (_drag > 120 || (d.primaryVelocity ?? 0) > 700) {
            Navigator.of(context).pop();
          } else {
            setState(() => _drag = 0);
          }
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: _drag == 0 ? 200 : 0),
          transform: Matrix4.translationValues(0, _drag, 0),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: PageView.builder(
              controller: _pages,
              itemCount: widget.groups.length,
              itemBuilder: (context, i) =>
                  _GroupView(group: widget.groups[i], onDone: _nextGroup, onBackAtStart: _prevGroup, paused: _drag > 0),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupView extends ConsumerStatefulWidget {
  const _GroupView({required this.group, required this.onDone, required this.onBackAtStart, required this.paused});
  final StoryGroup group;
  final VoidCallback onDone;
  final VoidCallback onBackAtStart;
  final bool paused;

  @override
  ConsumerState<_GroupView> createState() => _GroupViewState();
}

class _GroupViewState extends ConsumerState<_GroupView> with SingleTickerProviderStateMixin {
  static const _duration = Duration(seconds: 6);
  late final _timer = AnimationController(vsync: this, duration: _duration)..addStatusListener(_onTick);
  late int _index = widget.group.firstUnseen;
  late List<Story> _stories = List.of(widget.group.stories);
  bool _holding = false;
  bool _sheetOpen = false;
  String? _sentReaction;

  Story get _story => _stories[_index];
  bool get _mine => ref.read(myProfileProvider).value?.id == widget.group.author.id;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_GroupView old) {
    super.didUpdateWidget(old);
    _syncPause();
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  void _start() {
    _sentReaction = null;
    // Mark as seen after this frame: changing providers while the viewer is
    // being built (initState) is not allowed and showed a red error screen.
    final story = _story;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(storiesProvider.notifier).markViewed(story);
    });
    _timer.forward(from: 0);
  }

  void _syncPause() {
    final paused = widget.paused || _holding || _sheetOpen;
    if (paused && _timer.isAnimating) {
      _timer.stop();
    } else if (!paused && !_timer.isAnimating && _timer.value < 1) {
      _timer.forward();
    }
  }

  void _onTick(AnimationStatus s) {
    if (s == AnimationStatus.completed) _next();
  }

  void _next() {
    if (_index < _stories.length - 1) {
      setState(() => _index++);
      _start();
    } else {
      widget.onDone();
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index--);
      _start();
    } else {
      widget.onBackAtStart();
      _timer.forward(from: 0);
    }
  }

  Future<void> _react(String emoji) async {
    Haptics.medium();
    setState(() => _sentReaction = emoji);
    ref.read(storiesProvider.notifier).markViewed(_story, reaction: emoji);
    showAppSnack(context, 'Sent $emoji to ${widget.group.author.displayName}');
  }

  Future<void> _withSheet(Future<void> Function() open) async {
    setState(() => _sheetOpen = true);
    _syncPause();
    await open();
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    _syncPause();
  }

  Future<void> _showViewers() => _withSheet(
    () => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      sheetAnimationStyle: kSheetAnimation,
      builder: (ctx) => _ViewersSheet(story: _story),
    ),
  );

  Future<void> _delete() async {
    await _withSheet(() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete this story?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
          ],
        ),
      );
      if (ok != true) return;
      final story = _story;
      try {
        await ref.read(storiesProvider.notifier).delete(story);
      } catch (e) {
        if (mounted) showAppSnack(context, e.toString());
        return;
      }
      if (!mounted) return;
      if (_stories.length == 1) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _stories = [
          for (final s in _stories)
            if (s.id != story.id) s,
        ];
        _index = _index.clamp(0, _stories.length - 1);
      });
      _start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    final author = widget.group.author;
    final mine = _mine;
    final pad = MediaQuery.paddingOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        // ---- Content
        ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
          child: switch (story.kind) {
            StoryKind.progress when story.progress != null => StoryProgressCard(
              progress: story.progress!,
              caption: story.caption,
            ),
            _ => Stack(
              fit: StackFit.expand,
              children: [
                _PhotoContent(story: story),
                if (story.progress != null)
                  Positioned(
                    left: Space.md,
                    top: MediaQuery.paddingOf(context).top + 84,
                    child: StatsSticker(progress: story.progress!),
                  ),
              ],
            ),
          },
        ),

        // ---- Tap zones: left third back, rest forward; hold to pause.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (d) {
              final w = MediaQuery.sizeOf(context).width;
              d.localPosition.dx < w / 3 ? _prev() : _next();
            },
            onLongPressStart: (_) {
              setState(() => _holding = true);
              _syncPause();
            },
            onLongPressEnd: (_) {
              setState(() => _holding = false);
              _syncPause();
            },
          ),
        ),

        // ---- Top: progress bars and author
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99000000), Color(0x00000000)],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(Space.sm, pad.top + Space.xs, Space.xs, Space.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < _stories.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: AnimatedBuilder(
                              animation: _timer,
                              builder: (context, _) => LinearProgressIndicator(
                                minHeight: 3,
                                value: i < _index ? 1 : (i == _index ? _timer.value : 0),
                                color: Colors.white,
                                backgroundColor: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  Row(
                    children: [
                      SocialAvatar(profile: author, size: 34),
                      const SizedBox(width: Space.xs),
                      Flexible(
                        child: Text(
                          mine ? 'Your story' : author.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: Space.xs),
                      Text(
                        timeAgo(story.createdAt),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                      ),
                      const Spacer(),
                      if (mine)
                        IconButton(
                          tooltip: 'Delete story',
                          onPressed: _delete,
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                        ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ---- Bottom: caption, recipe, reactions / viewers
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xB3000000), Color(0x00000000)],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(Space.md, Space.xxl, Space.md, pad.bottom + Space.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (story.kind == StoryKind.photo && story.caption.isNotEmpty) ...[
                    Text(
                      story.caption,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: Space.sm),
                  ],
                  if (story.recipe != null) ...[
                    _RecipeChip(story: story, onOpen: _withSheet),
                    const SizedBox(height: Space.sm),
                  ],
                  if (mine)
                    Center(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        onPressed: _showViewers,
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(story.viewCount == null ? 'Seen by' : 'Seen by ${story.viewCount}'),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final e in storyReactions)
                          _ReactionBubble(emoji: e, sent: _sentReaction == e, onTap: () => _react(e)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoContent extends StatelessWidget {
  const _PhotoContent({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    if (story.photoBytes != null) {
      return Image.memory(Uint8List.fromList(story.photoBytes!), fit: BoxFit.cover);
    }
    if (story.photoUrl != null) {
      return Image.network(
        story.photoUrl!,
        fit: BoxFit.cover,
        cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
        errorBuilder: (context, _, _) =>
            const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48)),
      );
    }
    // Text-only story.
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFF8A5B), Color(0xFF7C5CFF)])),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Text(
            story.caption,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _ReactionBubble extends StatelessWidget {
  const _ReactionBubble({required this.emoji, required this.sent, required this.onTap});
  final String emoji;
  final bool sent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'React $emoji',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: sent ? 1.35 : 1,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: sent ? 0.35 : 0.16),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
        ),
      ),
    );
  }
}

class _RecipeChip extends ConsumerWidget {
  const _RecipeChip({required this.story, required this.onOpen});
  final Story story;
  final Future<void> Function(Future<void> Function()) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = story.recipe!;
    final saved = ref.watch(savedRecipesProvider.select((l) => l.any((x) => x.id == r.id)));
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onOpen(
          () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RecipeScreen.saved(recipe: r))),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.sm, Space.xs, Space.xxs, Space.xs),
          child: Row(
            children: [
              Text(r.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  '${r.title} · ${r.minutes} min',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () {
                  Haptics.light();
                  ref.read(savedRecipesProvider.notifier).toggle(r);
                },
                child: Text(saved ? 'Saved ✓' : 'Save recipe'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewersSheet extends ConsumerWidget {
  const _ViewersSheet({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<StoryViewer>>(
      future: ref.read(socialBackendProvider).storyViewers(story.id),
      builder: (context, snap) {
        final viewers = snap.data;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
                  child: Text(
                    viewers == null ? 'Seen by' : 'Seen by ${viewers.length}',
                    style: context.text.titleMedium,
                  ),
                ),
                if (snap.hasError)
                  Padding(padding: const EdgeInsets.all(Space.lg), child: Text(snap.error.toString()))
                else if (viewers == null)
                  const Padding(
                    padding: EdgeInsets.all(Space.xl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (viewers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(Space.xl),
                    child: Text(
                      'No views yet.',
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final v in viewers)
                          ListTile(
                            leading: SocialAvatar(profile: v.viewer),
                            title: Text(v.viewer.displayName),
                            subtitle: Text('${v.viewer.handle} · ${timeAgo(v.viewedAt)}'),
                            trailing: v.reaction == null
                                ? null
                                : Text(v.reaction!, style: const TextStyle(fontSize: 24)),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
