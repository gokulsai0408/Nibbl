import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/social/demo_social_backend.dart';
import '../../../domain/entities/social.dart';
import '../../providers/social_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'social_widgets.dart';

/// Friend challenges: daily check-ins for anything (steps, water, reading…).
class ChallengesTab extends ConsumerWidget {
  const ChallengesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(challengesProvider);
    final trophies = ref.watch(trophyCountProvider);
    return RefreshIndicator(
      onRefresh: () => ref.read(challengesProvider.notifier).refresh(),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [ErrorState(message: e.toString(), onRetry: () => ref.invalidate(challengesProvider))],
        ),
        data: (all) {
          final mine = [
            for (final c in all)
              if (c.joined && !c.isOver) c,
          ];
          final open = [
            for (final c in all)
              if (!c.joined && c.isActive) c,
          ];
          final done = [
            for (final c in all)
              if (c.joined && c.isOver) c,
          ];
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 96),
            children: [
              // ---- Intro / trophies
              AppCard(
                gradient: BrandSurfaces.hero(context.isDark),
                padding: const EdgeInsets.all(Space.md),
                child: Row(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 34)),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trophies == 0
                                ? 'Challenge your friends'
                                : '$trophies trophy${trophies == 1 ? '' : 's'} earned',
                            style: context.text.titleMedium,
                          ),
                          Text(
                            'Steps, water, workouts, sleep, reading: check in daily together.',
                            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.md),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => showNewChallengeSheet(context, ref),
                icon: const Icon(Icons.flag_rounded),
                label: const Text('Start a challenge'),
              ),
              if (mine.isNotEmpty) ...[
                const SizedBox(height: Space.lg),
                const SectionHeader(title: 'Your challenges'),
                for (final (i, c) in mine.indexed) ...[
                  ChallengeCard(challenge: c).entrance(context, index: i.clamp(0, 5)),
                  const SizedBox(height: Space.sm),
                ],
              ],
              if (open.isNotEmpty) ...[
                const SizedBox(height: Space.lg),
                const SectionHeader(title: 'Join your friends'),
                for (final c in open) ...[ChallengeCard(challenge: c), const SizedBox(height: Space.sm)],
              ],
              if (done.isNotEmpty) ...[
                const SizedBox(height: Space.lg),
                const SectionHeader(title: 'Finished'),
                for (final c in done) ...[ChallengeCard(challenge: c), const SizedBox(height: Space.sm)],
              ],
              if (all.isEmpty) ...[
                const SizedBox(height: Space.lg),
                Text(
                  'No challenges yet. Start one and your friends can join.',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Summary card: progress, who's in, and today's check-in button.
class ChallengeCard extends ConsumerWidget {
  const ChallengeCard({super.key, required this.challenge});
  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = challenge;
    final progress = c.myDays.length / c.days;
    final status = c.isOver
        ? (c.completed ? 'Completed 🏆' : 'Ended · ${c.myDays.length}/${c.days} days')
        : c.dayNumber < 1
        ? 'Starts soon'
        : 'Day ${c.dayNumber} of ${c.days} · ${c.daysLeft} left';
    return AppCard(
      padding: const EdgeInsets.all(Space.md),
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChallengeScreen(challengeId: c.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: context.isDark ? 0.18 : 0.1),
                  borderRadius: Radii.smAll,
                ),
                child: Text(c.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (c.toReview > 0)
                Container(
                  margin: const EdgeInsets.only(right: Space.xs),
                  padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.colors.onSurface,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(
                    '${c.toReview} to verify',
                    style: context.text.labelSmall?.copyWith(color: context.colors.surface),
                  ),
                ),
              _Faces(members: c.members),
            ],
          ),
          if (c.joined) ...[
            const SizedBox(height: Space.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: progress.clamp(0, 1).toDouble()),
                duration: motionDuration(context, AppDurations.slow),
                curve: AppCurves.easeOut,
                builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 8),
              ),
            ),
          ],
          if (c.isActive) ...[
            const SizedBox(height: Space.sm),
            if (c.joined)
              CheckInButton(challenge: c)
            else
              OutlinedButton.icon(
                onPressed: () async {
                  Haptics.light();
                  try {
                    await ref.read(challengesProvider.notifier).join(c);
                    if (context.mounted) showAppSnack(context, 'You joined ${c.title} 💪');
                  } catch (e) {
                    if (context.mounted) showAppSnack(context, e.toString());
                  }
                },
                icon: const Icon(Icons.group_add_outlined),
                label: Text('Join ${c.creator.displayName}'),
              ),
          ],
        ],
      ),
    );
  }
}

/// Big one-tap daily check-in.
class CheckInButton extends ConsumerWidget {
  const CheckInButton({super.key, required this.challenge});
  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = challenge.checkedToday;
    final success = context.palette.success;
    return AnimatedContainer(
      duration: motionDuration(context, AppDurations.medium),
      child: done
          ? OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: success,
                side: BorderSide(color: success.withValues(alpha: 0.6)),
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () => _set(context, ref, false),
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Done for today · tap to undo'),
            )
          : FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              onPressed: () => _checkInWithProof(context, ref),
              icon: const Icon(Icons.photo_camera_rounded),
              label: const Text('Check in with a photo'),
            ),
    );
  }

  Future<void> _checkInWithProof(BuildContext context, WidgetRef ref) async {
    final proof = await showModalBottomSheet<(Uint8List, String)>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: kSheetAnimation,
      builder: (ctx) => _ProofSheet(challenge: challenge),
    );
    if (proof == null || !context.mounted) return;
    await _set(context, ref, true, photo: proof.$1, note: proof.$2);
  }

  Future<void> _set(BuildContext context, WidgetRef ref, bool done, {List<int>? photo, String note = ''}) async {
    done ? Haptics.success() : Haptics.tap();
    try {
      await ref.read(challengesProvider.notifier).checkIn(challenge, done: done, photo: photo, note: note);
      if (done && context.mounted) {
        final n = challenge.myDays.length + 1;
        showAppSnack(
          context,
          n >= challenge.days
              ? 'Challenge complete! 🏆'
              : 'Checked in · $n of ${challenge.days} 🔥 Friends will verify your photo.',
        );
      }
    } catch (e) {
      if (context.mounted) showAppSnack(context, e.toString());
    }
  }
}

class _Faces extends StatelessWidget {
  const _Faces({required this.members});
  final List<ChallengeMember> members;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(3).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: 22.0 * shown.length + 10 + (members.length > 3 ? 26 : 0),
      height: 32,
      child: Stack(
        children: [
          for (final (i, m) in shown.indexed)
            Positioned(
              left: i * 22.0,
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(shape: BoxShape.circle, color: context.colors.surface),
                child: SocialAvatar(profile: m.profile, size: 29),
              ),
            ),
          if (members.length > 3)
            Positioned(
              left: shown.length * 22.0 + 10,
              top: 8,
              child: Text('+${members.length - 3}', style: context.text.labelSmall),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- detail

class ChallengeScreen extends ConsumerWidget {
  const ChallengeScreen({super.key, required this.challengeId});
  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = (ref.watch(challengesProvider).value ?? const <Challenge>[])
        .where((x) => x.id == challengeId)
        .firstOrNull;
    final me = ref.watch(myProfileProvider).value;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This challenge is no longer available.')),
      );
    }
    final board = c.leaderboard;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Invite friends',
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text:
                    'Join my "${c.title}" ${c.emoji} challenge on Nibbl! '
                    'Add me: ${me?.handle ?? ''} and find it under Friends → Challenges.',
              ),
            ),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          if (c.joined)
            PopupMenuButton<String>(
              tooltip: 'Options',
              onSelected: (_) async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Leave this challenge?'),
                    content: const Text('Your check-ins will be removed.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
                    ],
                  ),
                );
                if (ok != true) return;
                await ref.read(challengesProvider.notifier).leave(c);
                if (context.mounted) Navigator.of(context).pop();
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'leave', child: Text('Leave challenge'))],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(challengesProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.xl),
          children: [
            AppCard(
              gradient: BrandSurfaces.hero(context.isDark),
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                children: [
                  Text(c.emoji, style: const TextStyle(fontSize: 52)),
                  const SizedBox(height: Space.xs),
                  Text(c.title, textAlign: TextAlign.center, style: context.text.headlineSmall),
                  if (c.description.isNotEmpty) ...[
                    const SizedBox(height: Space.xxs),
                    Text(
                      c.description,
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: Space.md),
                  Row(
                    children: [
                      _Stat(
                        value: c.isOver ? 'Done' : (c.dayNumber < 1 ? '–' : '${c.dayNumber}/${c.days}'),
                        label: 'day',
                      ),
                      _Stat(value: '${c.myDays.length}', label: 'my check-ins'),
                      _Stat(value: '🔥 ${c.myStreak}', label: 'in a row'),
                    ],
                  ),
                  if (c.isActive) ...[
                    const SizedBox(height: Space.md),
                    if (c.joined)
                      CheckInButton(challenge: c)
                    else
                      FilledButton.icon(
                        onPressed: () => ref.read(challengesProvider.notifier).join(c),
                        icon: const Icon(Icons.group_add_outlined),
                        label: const Text('Join challenge'),
                      ),
                  ],
                ],
              ),
            ),
            if (c.joined) _ReviewQueue(challenge: c),
            if (c.joined) ...[
              const SizedBox(height: Space.lg),
              const SectionHeader(title: 'Your days'),
              const _Legend(),
              const SizedBox(height: Space.xs),
              _DayGrid(challenge: c),
            ],
            const SizedBox(height: Space.lg),
            SectionHeader(title: 'Leaderboard · ${board.length}'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Column(
                children: [
                  for (final (i, m) in board.indexed)
                    ListTile(
                      onTap: () => openProfile(context, m.profile),
                      leading: SizedBox(
                        width: 72,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 26,
                              child: Text(
                                i < 3 ? ['🥇', '🥈', '🥉'][i] : '${i + 1}',
                                textAlign: TextAlign.center,
                                style: context.text.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 6),
                            SocialAvatar(profile: m.profile, size: 38),
                          ],
                        ),
                      ),
                      title: Text(
                        m.profile.id == me?.id ? 'You' : m.profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(m.checkedToday ? 'Checked in today ✓' : 'Not yet today'),
                      trailing: Text(
                        '${m.checkins}/${c.days}',
                        style: context.text.titleMedium?.copyWith(color: context.colors.primary),
                      ),
                    ),
                ],
              ),
            ),
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

/// One dot per challenge day: filled when checked in, ringed for today.
class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.challenge});
  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    final success = context.palette.success;
    return AppCard(
      padding: const EdgeInsets.all(Space.md),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < c.days; i++)
            Builder(
              builder: (context) {
                final day = c.startsOn.add(Duration(days: i));
                final status = c.statusOf(day);
                final done = status != CheckinStatus.none;
                final isToday = day == c.today;
                final past = day.isBefore(c.today);
                final (fill, icon) = switch (status) {
                  CheckinStatus.verified => (success, Icons.check_rounded),
                  CheckinStatus.pending => (const Color(0xFFF5A524), Icons.schedule_rounded),
                  CheckinStatus.rejected => (context.colors.error, Icons.close_rounded),
                  CheckinStatus.none => (Colors.transparent, Icons.circle),
                };
                return Tooltip(
                  message: switch (status) {
                    CheckinStatus.verified => 'Day ${i + 1}: verified by friends',
                    CheckinStatus.pending => 'Day ${i + 1}: waiting for friends to verify',
                    CheckinStatus.rejected => 'Day ${i + 1}: friends said not quite',
                    CheckinStatus.none => 'Day ${i + 1}',
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? fill
                          : past
                          ? context.colors.errorContainer.withValues(alpha: 0.5)
                          : context.colors.surfaceContainerHigh,
                      border: isToday ? Border.all(color: context.colors.primary, width: 2) : null,
                    ),
                    child: done
                        ? Icon(icon, size: 18, color: Colors.white)
                        : Text('${i + 1}', style: context.text.labelSmall),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- create

Future<void> showNewChallengeSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: kSheetAnimation,
    builder: (ctx) => const _NewChallengeSheet(),
  );
}

class _NewChallengeSheet extends ConsumerStatefulWidget {
  const _NewChallengeSheet();

  @override
  ConsumerState<_NewChallengeSheet> createState() => _NewChallengeSheetState();
}

class _NewChallengeSheetState extends ConsumerState<_NewChallengeSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _emoji = '🏁';
  int _days = 7;
  bool _saving = false;

  static const _emojis = ['🏁', '🚶', '🏃', '🏋️', '🧘', '💧', '🥗', '🍬', '📚', '😴', '📵', '🚴', '🙏', '✍️'];

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.length < 2) {
      showAppSnack(context, 'Give your challenge a name');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(challengesProvider.notifier)
          .create(title: title, emoji: _emoji, description: _desc.text.trim(), days: _days);
      Haptics.success();
      if (!mounted) return;
      Navigator.pop(context);
      showAppSnack(context, 'Challenge started! Your friends can join it now.');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg + MediaQuery.paddingOf(context).bottom),
        children: [
          Text('Start a challenge', style: context.text.titleLarge),
          const SizedBox(height: Space.sm),
          const SectionHeader(title: 'Quick picks'),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              for (final (emoji, title, desc) in challengeTemplates)
                ActionChip(
                  avatar: Text(emoji),
                  label: Text(title),
                  onPressed: () {
                    Haptics.tap();
                    setState(() {
                      _emoji = emoji;
                      _title.text = title;
                      _desc.text = desc;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final e in _emojis)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(e, style: const TextStyle(fontSize: 18)),
                      selected: e == _emoji,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _emoji = e),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.sm),
          TextField(
            controller: _title,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Challenge',
              hintText: 'e.g. 10k steps a day',
              counterText: '',
            ),
          ),
          const SizedBox(height: Space.sm),
          TextField(
            controller: _desc,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Rules (optional)', counterText: ''),
          ),
          const SizedBox(height: Space.md),
          Text('How long?', style: context.text.titleSmall),
          const SizedBox(height: Space.xs),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 7, label: Text('7 days')),
              ButtonSegment(value: 14, label: Text('14')),
              ButtonSegment(value: 21, label: Text('21')),
              ButtonSegment(value: 30, label: Text('30')),
            ],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.first),
          ),
          const SizedBox(height: Space.lg),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _saving ? null : _create,
            icon: _saving
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.flag_rounded),
            label: const Text('Start today'),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Your friends see it under Challenges and can join any time before it ends.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Camera/gallery + note; returns the proof photo and note.
class _ProofSheet extends StatefulWidget {
  const _ProofSheet({required this.challenge});
  final Challenge challenge;

  @override
  State<_ProofSheet> createState() => _ProofSheetState();
}

class _ProofSheetState extends State<_ProofSheet> {
  final _note = TextEditingController();
  Uint8List? _photo;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 78);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _photo = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg + MediaQuery.paddingOf(context).bottom),
        children: [
          Text('${c.emoji}  Day ${c.dayNumber} proof', style: context.text.titleLarge),
          const SizedBox(height: Space.xxs),
          Text(
            'Snap something that shows you did it: your steps screen, the gym, your water bottle, the book…',
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: Space.md),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: Radii.mdAll,
              child: _photo != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(_photo!, fit: BoxFit.cover),
                        Positioned(
                          top: Space.xs,
                          right: Space.xs,
                          child: IconButton.filledTonal(
                            tooltip: 'Retake',
                            onPressed: () => _pick(ImageSource.camera),
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ),
                      ],
                    )
                  : Material(
                      color: context.colors.surfaceContainerHigh,
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pick(ImageSource.camera),
                              child: const _PickLabel(icon: Icons.photo_camera_rounded, label: 'Camera'),
                            ),
                          ),
                          VerticalDivider(width: 1, color: context.colors.outlineVariant),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pick(ImageSource.gallery),
                              child: const _PickLabel(icon: Icons.photo_library_rounded, label: 'Screenshot'),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: Space.sm),
          TextField(
            controller: _note,
            maxLength: 140,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Add a note (optional)', counterText: ''),
          ),
          const SizedBox(height: Space.md),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _photo == null ? null : () => Navigator.pop(context, (_photo!, _note.text.trim())),
            icon: const Icon(Icons.check_rounded),
            label: Text(_photo == null ? 'Add a photo to check in' : 'Check in'),
          ),
          const SizedBox(height: Space.xs),
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 16, color: context.colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Members of this challenge see it once and verify it.',
                  style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickLabel extends StatelessWidget {
  const _PickLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: context.colors.primary),
            const SizedBox(height: 4),
            Text(label, style: context.text.labelLarge?.copyWith(color: context.colors.primary)),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, IconData i, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          child: Icon(i, size: 11, color: Colors.white),
        ),
        const SizedBox(width: 4),
        Text(label, style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
      ],
    );
    return Wrap(
      spacing: Space.md,
      runSpacing: Space.xxs,
      children: [
        item(context.palette.success, Icons.check_rounded, 'Verified'),
        item(const Color(0xFFF5A524), Icons.schedule_rounded, 'Waiting'),
        item(context.colors.error, Icons.close_rounded, 'Not accepted'),
      ],
    );
  }
}

/// Friends' proofs to verify, each shown once.
class _ReviewQueue extends ConsumerStatefulWidget {
  const _ReviewQueue({required this.challenge});
  final Challenge challenge;

  @override
  ConsumerState<_ReviewQueue> createState() => _ReviewQueueState();
}

class _ReviewQueueState extends ConsumerState<_ReviewQueue> {
  List<CheckinReview>? _reviews;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(socialBackendProvider).checkinsToReview(widget.challenge.id);
      if (mounted) setState(() => _reviews = r);
    } catch (_) {
      if (mounted) setState(() => _reviews = const []);
    }
  }

  Future<void> _vote(CheckinReview r, bool approve) async {
    approve ? Haptics.success() : Haptics.tap();
    setState(() => _reviews = [...?_reviews?.where((x) => x != r)]);
    try {
      await ref.read(socialBackendProvider).voteCheckin(r, approve: approve);
      ref.read(challengesProvider.notifier).refresh().ignore();
      if (mounted) {
        showAppSnack(context, approve ? 'Verified ${r.profile.displayName}\'s day ✅' : 'Thanks for keeping it honest');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _reviews = [r, ...?_reviews]);
        showAppSnack(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviews = _reviews;
    if (reviews == null || reviews.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.lg),
        SectionHeader(title: 'Verify your friends · ${reviews.length}'),
        for (final r in reviews) ...[
          _ReviewCard(review: r, onVote: (ok) => _vote(r, ok)),
          const SizedBox(height: Space.sm),
        ],
      ],
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({required this.review, required this.onVote});
  final CheckinReview review;
  final ValueChanged<bool> onVote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = review;
    final today = DateUtils.dateOnly(DateTime.now());
    final when = r.day == today
        ? 'today'
        : (r.day == today.subtract(const Duration(days: 1)) ? 'yesterday' : '${r.day.day}/${r.day.month}');
    Widget photo;
    if (r.photoBytes != null) {
      photo = Image.memory(Uint8List.fromList(r.photoBytes!), fit: BoxFit.cover);
    } else if (r.photoUrl != null) {
      photo = Image.network(
        r.photoUrl!,
        fit: BoxFit.cover,
        cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
        loadingBuilder: (context, child, p) =>
            p == null ? child : ColoredBox(color: context.colors.surfaceContainerHigh),
        errorBuilder: (context, _, _) => ColoredBox(
          color: context.colors.surfaceContainerHigh,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );
    } else {
      // Demo check-ins have no real photo.
      final demo = ref.watch(socialBackendProvider) is DemoSocialBackend;
      photo = DecoratedBox(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2BB673), Color(0xFF14A3A3)])),
        child: Center(
          child: Text(demo ? '📸 Proof photo' : 'No photo', style: const TextStyle(color: Colors.white, fontSize: 18)),
        ),
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: SocialAvatar(profile: r.profile),
            title: Text(r.profile.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('Checked in $when'),
          ),
          AspectRatio(aspectRatio: 4 / 3, child: photo),
          if (r.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
              child: Text(r.note, style: context.text.bodyMedium),
            ),
          Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onVote(false),
                    icon: const Icon(Icons.close_rounded),
                    label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Not quite')),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onVote(true),
                    icon: const Icon(Icons.check_rounded),
                    label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Legit')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
