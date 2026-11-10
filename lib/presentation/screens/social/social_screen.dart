import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/entities/social.dart';
import '../../providers/social_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/mascot.dart';
import '../../widgets/motion.dart';
import 'challenges.dart';
import 'social_widgets.dart';
import 'story_row.dart';

/// Friends hub: set up a username, then see what friends are cooking.
class SocialScreen extends ConsumerWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myProfileProvider);
    final live = ref.watch(socialBackendProvider).isLive;
    final profile = me.value;
    if (profile != null) return _SocialHome(me: profile, live: live);

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: Column(
        children: [
          if (!live) const _DemoBanner(),
          Expanded(
            child: me.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: ErrorState(message: e.toString(), onRetry: () => ref.invalidate(myProfileProvider)),
              ),
              data: (_) => const UsernameSetup(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Signed-up view: Feed and Challenges tabs.
class _SocialHome extends ConsumerStatefulWidget {
  const _SocialHome({required this.me, required this.live});
  final SocialProfile me;
  final bool live;

  @override
  ConsumerState<_SocialHome> createState() => _SocialHomeState();
}

class _SocialHomeState extends ConsumerState<_SocialHome> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _showCreateMenu(BuildContext context) {
    Haptics.light();
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      sheetAnimationStyle: kSheetAnimation,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create', style: ctx.text.titleLarge),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  _CreateTile(
                    icon: Icons.add_a_photo_outlined,
                    label: 'Post',
                    hint: 'Meal, workout, any win',
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/social/new');
                    },
                  ),
                  const SizedBox(width: Space.sm),
                  _CreateTile(
                    icon: Icons.auto_awesome_outlined,
                    label: 'Story',
                    hint: 'Gone in 24 h',
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/social/story');
                    },
                  ),
                  const SizedBox(width: Space.sm),
                  _CreateTile(
                    icon: Icons.flag_outlined,
                    label: 'Challenge',
                    hint: 'With friends',
                    onTap: () {
                      Navigator.pop(ctx);
                      showNewChallengeSheet(context, ref);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(incomingRequestCountProvider);
    final onFeed = _tabs.index == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            tooltip: requests > 0 ? 'Friends, $requests new requests' : 'Find friends',
            onPressed: () => context.push('/social/friends'),
            icon: Badge(
              isLabelVisible: requests > 0,
              label: Text('$requests'),
              child: const Icon(Icons.person_add_alt_1_outlined),
            ),
          ),
          IconButton(
            tooltip: 'My profile',
            onPressed: () => openProfile(context, widget.me),
            icon: SocialAvatar(profile: widget.me, size: 30),
          ),
          const SizedBox(width: Space.xs),
        ],
        bottom: PillTabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Feed'),
            Tab(text: 'Challenges'),
          ],
        ),
      ),
      floatingActionButton: AnimatedScale(
        scale: onFeed ? 1 : 0,
        duration: motionDuration(context, AppDurations.medium),
        curve: Curves.easeOutBack,
        child: FloatingActionButton(
          tooltip: 'Create',
          onPressed: onFeed ? () => _showCreateMenu(context) : null,
          child: const Icon(Icons.add_rounded),
        ),
      ),
      body: Column(
        children: [
          if (!widget.live)
            const Padding(
              padding: EdgeInsets.only(top: Space.xs),
              child: _DemoBanner(),
            ),
          Expanded(
            child: TabBarView(controller: _tabs, children: const [_Feed(), ChallengesTab()]),
          ),
        ],
      ),
    );
  }
}

class _CreateTile extends StatelessWidget {
  const _CreateTile({required this.icon, required this.label, required this.hint, required this.onTap});
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: context.colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(color: context.colors.outlineVariant),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: Radii.mdAll),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md, horizontal: Space.xs),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: context.colors.onSurface, shape: BoxShape.circle),
                  child: Icon(icon, size: 22, color: context.colors.surface),
                ),
                const SizedBox(height: Space.xs),
                Text(label, style: context.text.titleSmall),
                Text(
                  hint,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xs),
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
      decoration: BoxDecoration(color: context.colors.tertiary.withValues(alpha: 0.12), borderRadius: Radii.smAll),
      child: Text(
        'Demo mode: sample friends, nothing is shared. Connect Supabase to go live.',
        style: context.text.labelMedium?.copyWith(color: context.colors.tertiary),
      ),
    );
  }
}

// --------------------------------------------------------------- setup

/// Pick a username, display name and avatar. Also used to edit them.
class UsernameSetup extends ConsumerStatefulWidget {
  const UsernameSetup({super.key, this.existing, this.onDone});
  final SocialProfile? existing;
  final VoidCallback? onDone;

  @override
  ConsumerState<UsernameSetup> createState() => _UsernameSetupState();
}

class _UsernameSetupState extends ConsumerState<UsernameSetup> {
  static const _emojis = ['🙂', '😎', '🥑', '🍳', '💪', '🏃', '🌸', '🔥', '🍕', '🥗', '🐼', '🦊', '🌻', '⚡'];

  late final _username = TextEditingController(text: widget.existing?.username ?? '');
  late final _name = TextEditingController(text: widget.existing?.displayName ?? '');
  late String _emoji = widget.existing?.avatarEmoji ?? '🙂';
  late final _bio = TextEditingController(text: widget.existing?.bio ?? '');
  Uint8List? _newPhoto;
  bool _removePhoto = false;
  Timer? _debounce;
  bool? _available;
  bool _checking = false;
  bool _saving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _username.dispose();
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  String get _u => _username.text.trim().toLowerCase();

  void _onUsername(String _) {
    _debounce?.cancel();
    setState(() {
      _available = null;
      _checking = false;
    });
    if (validateUsername(_u) != null) return;
    if (_u == widget.existing?.username) {
      setState(() => _available = true);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final value = _u;
      setState(() => _checking = true);
      try {
        final ok = await ref.read(socialBackendProvider).isUsernameAvailable(value);
        if (mounted && value == _u) setState(() => _available = ok);
      } catch (_) {
        if (mounted) setState(() => _available = null);
      } finally {
        if (mounted) setState(() => _checking = false);
      }
    });
  }

  Future<void> _save() async {
    final err = validateUsername(_u);
    if (err != null || _name.text.trim().isEmpty) {
      Haptics.warning();
      showAppSnack(context, err ?? 'Add your name');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(myProfileProvider.notifier)
          .save(
            username: _u,
            displayName: _name.text.trim(),
            emoji: _emoji,
            bio: _bio.text.trim(),
            photo: _newPhoto,
            removePhoto: _removePhoto,
          );
      Haptics.success();
      widget.onDone?.call();
    } catch (e) {
      Haptics.warning();
      if (mounted) showAppSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _hasPhoto => _newPhoto != null || (!_removePhoto && widget.existing?.avatarUrl != null);

  Future<void> _photoOptions() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      sheetAnimationStyle: kSheetAnimation,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (_hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Remove photo (use emoji)'),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'remove') {
      setState(() {
        _newPhoto = null;
        _removePhoto = true;
      });
      return;
    }
    final file = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    Haptics.light();
    setState(() {
      _newPhoto = bytes;
      _removePhoto = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final err = _u.isEmpty ? null : validateUsername(_u);
    final existing = widget.existing;
    final preview = existing != null && !_removePhoto && _newPhoto == null && existing.avatarUrl != null
        ? SocialAvatar(profile: existing, size: 96)
        : null;
    final editing = widget.existing != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.xl),
      children: [
        if (!editing) ...[
          const Center(child: Mascot(mood: MascotMood.excited, size: 110)),
          const SizedBox(height: Space.sm),
          Text('Better together', textAlign: TextAlign.center, style: context.text.headlineSmall),
          const SizedBox(height: Space.xxs),
          Text(
            'Pick a username so friends can find you, follow your progress and cheer you on.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: Space.lg),
        ],
        Center(
          child: Semantics(
            button: true,
            label: 'Change profile photo',
            child: GestureDetector(
              onTap: _photoOptions,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: context.colors.surfaceContainerHigh),
                    child: _newPhoto != null
                        ? Image.memory(_newPhoto!, width: 96, height: 96, fit: BoxFit.cover)
                        : preview ?? Text(_emoji, style: const TextStyle(fontSize: 46)),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                      ),
                      child: const Icon(Icons.photo_camera_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ).popIn(context),
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          _hasPhoto ? 'Tap to change photo' : 'Tap to add a photo, or pick an emoji',
          textAlign: TextAlign.center,
          style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Space.xxs,
          runSpacing: Space.xxs,
          children: [
            for (final e in _emojis)
              ChoiceChip(
                label: Text(e, style: const TextStyle(fontSize: 18)),
                selected: e == _emoji,
                showCheckmark: false,
                onSelected: (_) {
                  Haptics.tap();
                  setState(() => _emoji = e);
                },
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Your name', counterText: ''),
        ),
        const SizedBox(height: Space.sm),
        TextField(
          controller: _bio,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Bio (optional)',
            hintText: 'e.g. Training for a 10k · home cook',
          ),
        ),
        const SizedBox(height: Space.sm),
        TextField(
          controller: _username,
          autocorrect: false,
          maxLength: 20,
          onChanged: _onUsername,
          decoration: InputDecoration(
            labelText: 'Username',
            prefixText: '@',
            counterText: '',
            errorText: err ?? (_available == false ? 'Taken, try another' : null),
            helperText: _available == true ? 'Available ✓' : 'Lowercase letters, numbers, _ and .',
            suffixIcon: _checking
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : _available == true
                ? Icon(Icons.check_circle_rounded, color: context.palette.success)
                : null,
          ),
        ),
        const SizedBox(height: Space.lg),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _saving || _available == false ? null : _save,
          child: _saving
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Text(editing ? 'Save' : 'Continue'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- feed

class _Feed extends ConsumerStatefulWidget {
  const _Feed();

  @override
  ConsumerState<_Feed> createState() => _FeedState();
}

class _FeedState extends ConsumerState<_Feed> with AutomaticKeepAliveClientMixin {
  /// Null = everything.
  PostCategory? _filter;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = ref.watch(feedProvider);
    final me = ref.watch(myProfileProvider).value!;
    final friends = [
      for (final l in ref.watch(friendsProvider).value ?? const <FriendLink>[])
        if (l.isFriend) l.other,
    ];

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.read(feedProvider.notifier).refresh(),
          ref.read(friendsProvider.notifier).refresh(),
          ref.read(storiesProvider.notifier).refresh(),
        ]);
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) ref.read(feedProvider.notifier).loadMore();
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 96),
          children: [
            // ---- Stories (also a streak leaderboard of friends)
            const StoryRow(),
            const SizedBox(height: Space.xs),

            // ---- Filter
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _filter == null,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  for (final c in PostCategory.values) ...[
                    const SizedBox(width: Space.xs),
                    ChoiceChip(
                      avatar: Text(c.emoji),
                      label: Text(c.label),
                      selected: _filter == c,
                      showCheckmark: false,
                      onSelected: (_) {
                        Haptics.tap();
                        setState(() => _filter = _filter == c ? null : c);
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Space.sm),

            // ---- Posts
            ...feed.when(
              loading: () => [
                const Padding(
                  padding: EdgeInsets.all(Space.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (e, _) => [ErrorState(message: e.toString(), onRetry: () => ref.invalidate(feedProvider))],
              data: (all) {
                final posts = _filter == null
                    ? all
                    : [
                        for (final p in all)
                          if (p.category == _filter) p,
                      ];
                if (posts.isEmpty) {
                  return [
                    EmptyState(
                      emoji: friends.isEmpty ? '👋' : (_filter?.emoji ?? '✨'),
                      title: friends.isEmpty
                          ? 'Add your first friend'
                          : _filter == null
                          ? 'Nothing here yet'
                          : 'No ${_filter!.label.toLowerCase()} posts yet',
                      message: friends.isEmpty
                          ? 'Search by username, or share yours so friends can add you.'
                          : 'Share a meal, a workout, a good night\'s sleep or any win. Friends will see it here.',
                      actionLabel: friends.isEmpty ? 'Find friends' : 'Share something',
                      onAction: () => context.push(friends.isEmpty ? '/social/friends' : '/social/new'),
                    ),
                  ];
                }
                return [
                  for (final (i, p) in posts.indexed) ...[
                    PostCard(post: p, isMine: p.author.id == me.id).entrance(context, index: i.clamp(0, 6)),
                    const SizedBox(height: Space.md),
                  ],
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}
