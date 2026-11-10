import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/social/demo_social_backend.dart';
import '../../../domain/entities/social.dart';
import '../../providers/kitchen_providers.dart';
import '../../providers/social_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../kitchen/recipe_screen.dart';

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${t.day}/${t.month}';
}

/// Round avatar: the profile photo when there is one, otherwise the emoji.
class SocialAvatar extends ConsumerWidget {
  const SocialAvatar({super.key, required this.profile, this.size = 40});
  final SocialProfile profile;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = profile.avatarUrl;
    Widget emoji() => Center(
      child: Text(profile.avatarEmoji, style: TextStyle(fontSize: size * 0.5)),
    );
    Widget? photo;
    if (url != null) {
      final backend = ref.watch(socialBackendProvider);
      if (url.startsWith('memory://') && backend is DemoSocialBackend) {
        final bytes = backend.avatarBytes[url];
        if (bytes != null) photo = Image.memory(Uint8List.fromList(bytes), fit: BoxFit.cover);
      } else if (url.startsWith('http')) {
        photo = Image.network(
          url,
          fit: BoxFit.cover,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
          errorBuilder: (_, _, _) => emoji(),
        );
      }
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.primary.withValues(alpha: context.isDark ? 0.35 : 0.18),
            context.palette.success.withValues(alpha: context.isDark ? 0.3 : 0.15),
          ],
        ),
      ),
      child: photo ?? emoji(),
    );
  }
}

/// Small "🔥 12 · Lv 4" stat line.
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.profile});
  final SocialProfile profile;

  @override
  Widget build(BuildContext context) {
    return Text(
      '🔥 ${profile.streak}  ·  Lv ${profile.mochiLevel}',
      style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
    );
  }
}

void openProfile(BuildContext context, SocialProfile p) {
  Haptics.light();
  context.push('/social/u/${p.id}', extra: p);
}

class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, required this.isMine, this.onChanged});
  final Post post;
  final bool isMine;

  /// For lists that don't come from the feed provider (profile pages).
  final ValueChanged<Post?>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = post;
    final hasPhoto = p.photoUrl != null || p.photoBytes != null;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Header
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.xs, Space.xs),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => openProfile(context, p.author),
                  child: SocialAvatar(profile: p.author),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: GestureDetector(
                    onTap: () => openProfile(context, p.author),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.author.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall,
                        ),
                        Text(
                          '${p.author.handle} · ${timeAgo(p.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isMine)
                  PopupMenuButton<String>(
                    tooltip: 'Post options',
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (_) => _delete(context, ref),
                    itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete post'))],
                  ),
              ],
            ),
          ),

          // ---- Photo
          if (hasPhoto)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: p.photoBytes != null
                  ? Image.memory(
                      Uint8List.fromList(p.photoBytes!),
                      fit: BoxFit.cover,
                      cacheWidth: _decodeWidth(context),
                    )
                  : Image.network(
                      p.photoUrl!,
                      fit: BoxFit.cover,
                      cacheWidth: _decodeWidth(context),
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : ColoredBox(color: context.colors.surfaceContainerHigh),
                      errorBuilder: (context, _, _) => ColoredBox(
                        color: context.colors.surfaceContainerHigh,
                        child: const Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Category & activity
                if (p.category != PostCategory.food || p.activity != null) ...[
                  Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Pill('${p.category.emoji} ${p.category.label}'),
                      if (p.activity != null) Text(p.activity!.summary, style: context.text.titleSmall),
                    ],
                  ),
                  const SizedBox(height: Space.xxs),
                ],
                // ---- Dish
                if (p.dishName != null)
                  Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('${p.emoji ?? '🍽️'} ${p.dishName}', style: context.text.titleSmall),
                      if (p.kcal != null) _Pill('${p.kcal} kcal'),
                      if (p.protein != null) _Pill('${p.protein}g protein'),
                    ],
                  ),
                if (p.caption.isNotEmpty) ...[
                  if (p.dishName != null) const SizedBox(height: Space.xxs),
                  Text(p.caption, style: context.text.bodyMedium),
                ],

                // ---- Recipe
                if (p.recipe != null) ...[const SizedBox(height: Space.sm), _RecipeAttachment(post: p)],
              ],
            ),
          ),

          // ---- Reactions & comments
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.xs, Space.xs, Space.xs),
            child: Row(
              children: [
                // Scrolls sideways on very narrow screens instead of overflowing.
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final e in postReactions) _ReactionButton(post: p, emoji: e, onChanged: onChanged),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showCommentsSheet(
                    context,
                    p,
                    onCount: (n) {
                      ref.read(feedProvider.notifier).setCommentCount(p.id, n);
                      onChanged?.call(p.copyWith(commentCount: n));
                    },
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: Text(p.commentCount == 0 ? '' : '${p.commentCount}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(feedProvider.notifier).delete(post);
      onChanged?.call(null);
    } catch (e) {
      if (context.mounted) showAppSnack(context, e.toString());
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: context.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(text, style: context.text.labelSmall?.copyWith(color: context.colors.primary)),
    );
  }
}

class _ReactionButton extends ConsumerWidget {
  const _ReactionButton({required this.post, required this.emoji, this.onChanged});
  final Post post;
  final String emoji;
  final ValueChanged<Post?>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = post.myReaction == emoji;
    final count = post.reactions[emoji] ?? 0;
    return Semantics(
      button: true,
      selected: mine,
      label: 'React $emoji, $count',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.9,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.pill),
          onTap: () async {
            Haptics.tap();
            onChanged?.call(post.withMyReaction(mine ? null : emoji));
            try {
              if (onChanged != null && ref.read(feedProvider).value?.any((p) => p.id == post.id) != true) {
                await ref.read(socialBackendProvider).react(post.id, mine ? null : emoji);
              } else {
                await ref.read(feedProvider.notifier).react(post, emoji);
              }
            } catch (e) {
              onChanged?.call(post);
              if (context.mounted) showAppSnack(context, e.toString());
            }
          },
          child: AnimatedContainer(
            duration: motionDuration(context, AppDurations.fast),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: 4),
            decoration: BoxDecoration(
              color: mine ? context.colors.primary.withValues(alpha: context.isDark ? 0.25 : 0.14) : null,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: mine ? 1.15 : 1,
                  duration: motionDuration(context, AppDurations.medium),
                  curve: Curves.easeOutBack,
                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 3),
                  Text(
                    '$count',
                    style: context.text.labelMedium?.copyWith(
                      color: mine ? context.colors.primary : context.colors.onSurfaceVariant,
                      fontWeight: mine ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A Mochi recipe attached to a post: friends can open and save it.
class _RecipeAttachment extends ConsumerWidget {
  const _RecipeAttachment({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = post.recipe!;
    final saved = ref.watch(savedRecipesProvider.select((l) => l.any((x) => x.id == r.id)));
    return Material(
      color: context.colors.surfaceContainerHigh,
      borderRadius: Radii.smAll,
      child: InkWell(
        borderRadius: Radii.smAll,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RecipeScreen.saved(recipe: r))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.sm, Space.xs, Space.xxs, Space.xs),
          child: Row(
            children: [
              const Icon(Icons.menu_book_rounded, size: 20),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  'Recipe · ${r.minutes} min · ${r.steps.length} steps',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge,
                ),
              ),
              TextButton(
                onPressed: () {
                  Haptics.light();
                  ref.read(savedRecipesProvider.notifier).toggle(r);
                  showAppSnack(context, saved ? 'Removed from your recipes' : 'Saved to My kitchen');
                },
                child: Text(saved ? 'Saved' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ comments

Future<void> showCommentsSheet(BuildContext context, Post post, {ValueChanged<int>? onCount}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: kSheetAnimation,
    builder: (ctx) => _CommentsSheet(post: post, onCount: onCount),
  );
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.post, this.onCount});
  final Post post;
  final ValueChanged<int>? onCount;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _ctrl = TextEditingController();
  List<PostComment>? _comments;
  Object? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await ref.read(socialBackendProvider).comments(widget.post.id);
      if (mounted) setState(() => _comments = c);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final c = await ref.read(socialBackendProvider).addComment(widget.post.id, text);
      _ctrl.clear();
      Haptics.light();
      if (!mounted) return;
      setState(() => _comments = [...?_comments, c]);
      widget.onCount?.call(_comments!.length);
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(PostComment c) async {
    final prev = _comments;
    setState(() => _comments = [...?_comments?.where((x) => x.id != c.id)]);
    try {
      await ref.read(socialBackendProvider).deleteComment(c.id);
      widget.onCount?.call(_comments!.length);
    } catch (e) {
      if (mounted) {
        setState(() => _comments = prev);
        showAppSnack(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myProfileProvider).value;
    final comments = _comments;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
              child: Text('Comments', style: context.text.titleMedium),
            ),
            Flexible(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(Space.lg),
                      child: Text(_error.toString(), textAlign: TextAlign.center),
                    )
                  : comments == null
                  ? const Padding(padding: EdgeInsets.all(Space.xl), child: CircularProgressIndicator())
                  : comments.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(Space.xl),
                      child: Text(
                        'No comments yet. Say something nice!',
                        style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: Space.md),
                      itemCount: comments.length,
                      itemBuilder: (context, i) {
                        final c = comments[i];
                        final canDelete = me != null && (c.author.id == me.id || widget.post.author.id == me.id);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: SocialAvatar(profile: c.author, size: 36),
                          title: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${c.author.displayName}  ',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                TextSpan(text: c.body),
                              ],
                            ),
                            style: context.text.bodyMedium,
                          ),
                          subtitle: Text(timeAgo(c.createdAt), style: context.text.labelSmall),
                          trailing: canDelete
                              ? IconButton(
                                  tooltip: 'Delete comment',
                                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                  onPressed: () => _delete(c),
                                )
                              : null,
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.xs, Space.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        maxLength: 300,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(hintText: 'Add a comment…', counterText: ''),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Send',
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Decode photos at the size they're shown, not full camera resolution.
int _decodeWidth(BuildContext context) =>
    (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round();
