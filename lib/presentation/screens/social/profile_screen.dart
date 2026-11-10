import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/entities/social.dart';
import '../../providers/social_providers.dart';
import '../../widgets/common.dart';
import 'social_screen.dart';
import 'social_widgets.dart';

/// A person's page: stats, friendship actions and their posts.
class SocialProfileScreen extends ConsumerStatefulWidget {
  const SocialProfileScreen({super.key, required this.userId, this.initial});
  final String userId;
  final SocialProfile? initial;

  @override
  ConsumerState<SocialProfileScreen> createState() => _SocialProfileScreenState();
}

class _SocialProfileScreenState extends ConsumerState<SocialProfileScreen> {
  List<Post>? _posts;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await ref.read(socialBackendProvider).postsBy(widget.userId);
      if (mounted) setState(() => _posts = p);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _update(int i, Post? p) {
    final list = [...?_posts];
    if (p == null) {
      list.removeAt(i);
    } else {
      list[i] = p;
    }
    setState(() => _posts = list);
  }

  Future<void> _editProfile(SocialProfile me) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: const Text('Edit profile')),
          body: UsernameSetup(existing: me, onDone: () => Navigator.pop(ctx)),
        ),
      ),
    );
  }

  Future<void> _friendAction(FriendLink? link, SocialProfile p) async {
    setState(() => _busy = true);
    final n = ref.read(friendsProvider.notifier);
    try {
      if (link == null) {
        await n.send(p);
        Haptics.success();
      } else if (link.incoming && !link.isFriend) {
        await n.respond(link, accept: true);
        Haptics.success();
        await _load();
      } else if (link.isFriend) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Remove ${p.displayName}?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
            ],
          ),
        );
        if (ok == true) {
          await n.remove(link);
          if (mounted) setState(() => _posts = const []);
        }
      } else {
        await n.remove(link);
      }
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myProfileProvider).value;
    final links = ref.watch(friendsProvider).value ?? const <FriendLink>[];
    final link = links.where((l) => l.other.id == widget.userId).firstOrNull;
    final isMe = me?.id == widget.userId;
    final p = isMe ? me! : (link?.other ?? widget.initial);

    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final (label, icon) = switch (link) {
      null => ('Add friend', Icons.person_add_alt_1_rounded),
      FriendLink(isFriend: true) => ('Friends', Icons.check_rounded),
      FriendLink(incoming: true) => ('Accept request', Icons.how_to_reg_rounded),
      _ => ('Requested', Icons.schedule_rounded),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(p.handle),
        actions: [
          if (isMe)
            PopupMenuButton<String>(
              tooltip: 'Options',
              onSelected: (v) async {
                if (v == 'edit') {
                  await _editProfile(p);
                } else if (v == 'signout') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign out of Friends?'),
                      content: const Text(
                        'Your account is tied to this phone. If you sign out you won\'t be able to get this username back.',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref.read(myProfileProvider.notifier).signOut();
                    if (context.mounted) context.pop();
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit profile')),
                PopupMenuItem(value: 'signout', child: Text('Sign out')),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.xl),
          children: [
            AppCard(
              gradient: BrandSurfaces.hero(context.isDark),
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                children: [
                  SocialAvatar(profile: p, size: 80),
                  const SizedBox(height: Space.sm),
                  Text(p.displayName, style: context.text.headlineSmall, textAlign: TextAlign.center),
                  Text(p.handle, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                  if (p.bio.isNotEmpty) ...[
                    const SizedBox(height: Space.xs),
                    Text(p.bio, textAlign: TextAlign.center, style: context.text.bodyMedium),
                  ],
                  const SizedBox(height: Space.md),
                  Row(
                    children: [
                      _Stat(value: '🔥 ${p.streak}', label: 'day streak'),
                      _Stat(value: 'Lv ${p.mochiLevel}', label: 'Mochi'),
                      _Stat(value: '${_posts?.length ?? '–'}', label: 'posts'),
                      if (isMe) _Stat(value: '🏆 ${ref.watch(trophyCountProvider)}', label: 'trophies'),
                    ],
                  ),
                  if (!isMe) ...[
                    const SizedBox(height: Space.md),
                    SizedBox(
                      width: double.infinity,
                      child: (link?.isFriend ?? false)
                          ? OutlinedButton.icon(
                              onPressed: _busy ? null : () => _friendAction(link, p),
                              icon: Icon(icon),
                              label: Text(label),
                            )
                          : FilledButton.icon(
                              onPressed: _busy || (link != null && !link.incoming)
                                  ? null
                                  : () => _friendAction(link, p),
                              icon: Icon(icon),
                              label: Text(label),
                            ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Space.lg),
            if (_error != null)
              ErrorState(message: _error.toString(), onRetry: _load)
            else if (_posts == null)
              const Padding(
                padding: EdgeInsets.all(Space.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_posts!.isEmpty)
              Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Text(
                  isMe
                      ? 'You haven\'t shared anything yet.'
                      : (link?.isFriend ?? false)
                      ? '${p.displayName} hasn\'t shared anything yet.'
                      : 'Become friends to see ${p.displayName}\'s posts.',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              )
            else
              for (final (i, post) in _posts!.indexed) ...[
                PostCard(post: post, isMine: isMe, onChanged: (np) => _update(i, np)),
                const SizedBox(height: Space.md),
              ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: context.text.titleLarge),
          ),
          Text(label, style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
