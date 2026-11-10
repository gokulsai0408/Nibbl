import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/entities/social.dart';
import '../../providers/social_providers.dart';
import 'social_widgets.dart';
import 'story_viewer_screen.dart';

/// Story bubbles: me (add / watch mine), friends with stories (ring), then
/// friends without stories (with their streak), like a leaderboard.
class StoryRow extends ConsumerWidget {
  const StoryRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myProfileProvider).value;
    if (me == null) return const SizedBox.shrink();
    final groups = ref.watch(storyGroupsProvider);
    final mineIndex = groups.indexWhere((g) => g.author.id == me.id);
    final others = [
      for (final g in groups)
        if (g.author.id != me.id) g,
    ];
    final withStories = {for (final g in groups) g.author.id};
    final quiet = [
      for (final l in ref.watch(friendsProvider).value ?? const <FriendLink>[])
        if (l.isFriend && !withStories.contains(l.other.id)) l.other,
    ]..sort((a, b) => b.streak.compareTo(a.streak));

    // The viewer plays mine first (if any), then friends in row order.
    final playlist = [if (mineIndex >= 0) groups[mineIndex], ...others];

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: SizedBox(
        height: 108,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _Bubble(
              profile: me,
              label: 'Your story',
              ring: mineIndex < 0 ? _Ring.none : _Ring.seen,
              showAdd: true,
              onTap: () {
                if (mineIndex >= 0) {
                  openStories(context, playlist, 0);
                } else {
                  Haptics.light();
                  context.push('/social/story');
                }
              },
              onAdd: () {
                Haptics.light();
                context.push('/social/story');
              },
            ),
            for (final (i, g) in others.indexed)
              _Bubble(
                profile: g.author,
                label: g.author.displayName,
                ring: g.allViewed ? _Ring.seen : _Ring.fresh,
                onTap: () => openStories(context, playlist, i + (mineIndex >= 0 ? 1 : 0)),
              ),
            for (final f in quiet)
              _Bubble(
                profile: f,
                label: f.displayName,
                ring: _Ring.none,
                dim: true,
                sub: '🔥 ${f.streak}',
                onTap: () => openProfile(context, f),
              ),
          ],
        ),
      ),
    );
  }
}

enum _Ring { none, seen, fresh }

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.profile,
    required this.label,
    required this.ring,
    required this.onTap,
    this.onAdd,
    this.showAdd = false,
    this.dim = false,
    this.sub,
  });

  final SocialProfile profile;
  final String label;
  final _Ring ring;
  final VoidCallback onTap;
  final VoidCallback? onAdd;
  final bool showAdd;
  final bool dim;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    final Gradient? gradient = switch (ring) {
      _Ring.fresh => const SweepGradient(
        colors: [Color(0xFFFF8A5B), Color(0xFFFF5C8A), Color(0xFF7C5CFF), Color(0xFFFFC94D), Color(0xFFFF8A5B)],
      ),
      _Ring.seen => LinearGradient(colors: [context.colors.outlineVariant, context.colors.outlineVariant]),
      _Ring.none => null,
    };
    return Semantics(
      button: true,
      label: ring == _Ring.fresh ? '$label, new story' : label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: dim ? 0.75 : 1,
          child: Padding(
            padding: const EdgeInsets.only(right: Space.sm),
            child: SizedBox(
              width: 70,
              child: Column(
                children: [
                  SizedBox.square(
                    dimension: size + 6,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).scaffoldBackgroundColor,
                            ),
                            child: SocialAvatar(profile: profile, size: size - 6),
                          ),
                        ),
                        if (showAdd)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: onAdd,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: context.colors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                                ),
                                child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall),
                  if (sub != null)
                    Text(sub!, style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
