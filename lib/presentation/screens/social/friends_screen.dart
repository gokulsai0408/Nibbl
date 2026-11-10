import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/entities/social.dart';
import '../../providers/social_providers.dart';
import '../../widgets/common.dart';
import 'social_widgets.dart';

/// Find people by username, handle requests and manage friends.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<SocialProfile>? _results;
  bool _searching = false;
  final _busy = <String>{};

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    if (q.trim().replaceAll('@', '').length < 2) {
      setState(() {
        _results = null;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _searching = true);
      try {
        final r = await ref.read(socialBackendProvider).search(q);
        if (mounted && q == _search.text) setState(() => _results = r);
      } catch (e) {
        if (mounted) showAppSnack(context, e.toString());
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _add(SocialProfile p) async {
    setState(() => _busy.add(p.id));
    try {
      final r = await ref.read(friendsProvider.notifier).send(p);
      Haptics.success();
      if (!mounted) return;
      showAppSnack(context, switch (r) {
        RequestResult.sent => 'Request sent to ${p.handle}',
        RequestResult.accepted => 'You and ${p.displayName} are now friends 🎉',
        RequestResult.alreadySent => 'Already sent. Waiting for ${p.displayName}',
        RequestResult.alreadyFriends => 'You\'re already friends',
      });
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy.remove(p.id));
    }
  }

  Future<void> _respond(FriendLink l, bool accept) async {
    Haptics.light();
    try {
      await ref.read(friendsProvider.notifier).respond(l, accept: accept);
      if (accept && mounted) showAppSnack(context, 'You and ${l.other.displayName} are now friends 🎉');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    }
  }

  Future<void> _remove(FriendLink l) async {
    if (l.isFriend) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Remove ${l.other.displayName}?'),
          content: const Text('You\'ll stop seeing each other\'s posts.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await ref.read(friendsProvider.notifier).remove(l);
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myProfileProvider).value;
    final links = ref.watch(friendsProvider);
    final all = links.value ?? const <FriendLink>[];
    final incoming = [
      for (final l in all)
        if (l.incoming && !l.isFriend) l,
    ];
    final sent = [
      for (final l in all)
        if (!l.incoming && !l.isFriend) l,
    ];
    final friends = [
      for (final l in all)
        if (l.isFriend) l,
    ]..sort((a, b) => b.other.streak.compareTo(a.other.streak));
    final linkByUser = {for (final l in all) l.other.id: l};

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(friendsProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xl),
          children: [
            // ---- Search
            TextField(
              controller: _search,
              autocorrect: false,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search by username or name',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
            ),
            if (_results != null) ...[
              const SizedBox(height: Space.sm),
              if (_results!.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Text(
                    'No one found. Check the spelling, or share your username with them.',
                    style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                )
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  child: Column(children: [for (final p in _results!) _personTile(p, linkByUser[p.id])]),
                ),
            ],

            // ---- Share my username
            if (me != null) ...[
              const SizedBox(height: Space.md),
              AppCard(
                padding: const EdgeInsets.all(Space.md),
                child: Row(
                  children: [
                    SocialAvatar(profile: me, size: 44),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your username', style: context.text.labelMedium),
                          Text(me.handle, style: context.text.titleMedium),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(text: 'Add me on Nibbl: ${me.handle} 🍽️\nLet\'s keep each other on track!'),
                      ),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Share'),
                    ),
                  ],
                ),
              ),
            ],

            ...links.when(
              loading: () => [
                const Padding(
                  padding: EdgeInsets.all(Space.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (e, _) => [ErrorState(message: e.toString(), onRetry: () => ref.invalidate(friendsProvider))],
              data: (_) => [
                if (incoming.isNotEmpty) ...[
                  const SizedBox(height: Space.lg),
                  SectionHeader(title: 'Requests · ${incoming.length}'),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: Space.xs),
                    child: Column(
                      children: [
                        for (final l in incoming)
                          ListTile(
                            onTap: () => openProfile(context, l.other),
                            leading: SocialAvatar(profile: l.other),
                            title: Text(l.other.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(l.other.handle, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Decline',
                                  onPressed: () => _respond(l, false),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                                IconButton.filled(
                                  tooltip: 'Accept',
                                  onPressed: () => _respond(l, true),
                                  icon: const Icon(Icons.check_rounded),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: Space.lg),
                SectionHeader(title: friends.isEmpty ? 'Friends' : 'Friends · ${friends.length}'),
                if (friends.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.xs),
                    child: Text(
                      'No friends yet. Search above or share your username.',
                      style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  )
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: Space.xs),
                    child: Column(
                      children: [
                        for (final l in friends)
                          ListTile(
                            onTap: () => openProfile(context, l.other),
                            leading: SocialAvatar(profile: l.other),
                            title: Text(l.other.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: StreakBadge(profile: l.other),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Options',
                              onSelected: (_) => _remove(l),
                              itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Remove friend'))],
                            ),
                          ),
                      ],
                    ),
                  ),
                if (sent.isNotEmpty) ...[
                  const SizedBox(height: Space.lg),
                  SectionHeader(title: 'Sent · ${sent.length}'),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: Space.xs),
                    child: Column(
                      children: [
                        for (final l in sent)
                          ListTile(
                            leading: SocialAvatar(profile: l.other),
                            title: Text(l.other.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: const Text('Waiting for them to accept'),
                            trailing: TextButton(onPressed: () => _remove(l), child: const Text('Cancel')),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _personTile(SocialProfile p, FriendLink? link) {
    final busy = _busy.contains(p.id);
    final Widget trailing;
    if (link?.isFriend ?? false) {
      trailing = Text('Friends', style: context.text.labelLarge?.copyWith(color: context.palette.success));
    } else if (link != null && !link.incoming) {
      trailing = Text('Requested', style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant));
    } else {
      trailing = FilledButton(
        onPressed: busy ? null : () => _add(p),
        child: busy
            ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(link != null ? 'Accept' : 'Add'),
      );
    }
    return ListTile(
      onTap: () => openProfile(context, p),
      leading: SocialAvatar(profile: p),
      title: Text(p.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(p.handle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing,
    );
  }
}
