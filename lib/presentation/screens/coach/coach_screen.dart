import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_x.dart';
import '../../../domain/entities/tracking.dart';
import '../../providers/coach_provider.dart';
import '../../providers/kitchen_providers.dart';
import '../../providers/log_providers.dart';
import '../../providers/mochi_providers.dart';
import '../../providers/profile_settings_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/mascot.dart';
import '../../widgets/motion.dart';

/// A quick question: short chip label + the full prompt sent to Mochi.
typedef _Prompt = ({IconData icon, String label, String prompt});

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final has = _input.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = preset ?? _input.text;
    if (text.trim().isEmpty || ref.read(chatProvider).isTyping) return;
    Haptics.light();
    _input.clear();
    ref.read(chatProvider.notifier).send(text);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: motionDuration(context, AppDurations.medium),
        curve: AppCurves.easeOut,
      );
    });
  }

  List<_Prompt> _prompts(DaySummary today) {
    final kcal = today.remainingKcal.round();
    final protein = (today.targets.protein - today.totals.protein).round().clamp(0, 999);
    return [
      (
        icon: Icons.restaurant_rounded,
        label: 'Dinner ideas',
        prompt: kcal > 0
            ? 'What should I eat for dinner with $kcal kcal and ${protein}g protein left?'
            : 'I\'m over my calories today. What should I do now?',
      ),
      (icon: Icons.cookie_rounded, label: 'Snack', prompt: 'Give me a healthy snack under 200 kcal.'),
      (icon: Icons.egg_alt_rounded, label: 'More protein', prompt: 'How can I hit my protein goal today?'),
      (icon: Icons.insights_rounded, label: 'My week', prompt: 'How am I doing this week?'),
    ];
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text('This removes your conversation with Mochi from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) ref.read(chatProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final today = ref.watch(daySummaryProvider(DateTime.now().dayKey));
    final name = ref.watch(profileProvider.select((p) => p?.name ?? ''));
    final prompts = _prompts(today);
    ref.listen(chatProvider.select((s) => s.messages.length + (s.isTyping ? 1 : 0)), (prev, next) => _scrollToEnd());

    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final empty = chat.messages.isEmpty && !chat.isTyping;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _Header(onClear: chat.messages.isEmpty ? null : _confirmClear),
          Expanded(
            child: empty
                ? _Welcome(name: name, prompts: prompts, onPick: _send)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.sm),
                    itemCount: chat.messages.length + (chat.isTyping ? 1 : 0) + (chat.error != null ? 1 : 0),
                    itemBuilder: (context, i) {
                      final msgs = chat.messages;
                      if (i < msgs.length) {
                        final m = msgs[i];
                        final next = i + 1 < msgs.length ? msgs[i + 1] : null;
                        // Show Mochi's face on the last bubble of each of its message groups.
                        final showAvatar =
                            m.role == ChatRole.assistant &&
                            (next == null || next.role != ChatRole.assistant) &&
                            !(chat.isTyping && next == null);
                        return _Bubble(message: m, showAvatar: showAvatar);
                      }
                      if (chat.isTyping && i == msgs.length) return const _TypingBubble();
                      return _ErrorBubble(message: chat.error!, onRetry: () => ref.read(chatProvider.notifier).retry());
                    },
                  ),
          ),
          if (!empty && !chat.isTyping) _QuickReplies(prompts: prompts, onPick: _send),
          Padding(
            padding: EdgeInsets.fromLTRB(
              Space.md,
              Space.xs,
              Space.md,
              keyboardOpen ? Space.sm : MediaQuery.paddingOf(context).bottom + Space.sm,
            ),
            child: _Composer(controller: _input, canSend: _hasText && !chat.isTyping, onSend: _send),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- Header

class _Header extends StatelessWidget {
  const _Header({required this.onClear});
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.xs, Space.xs),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Haptics.light();
              context.push('/mochi');
            },
            child: SizedBox.square(
              dimension: 52,
              child: Stack(
                children: [
                  const Mascot(mood: MascotMood.happy, size: 52, interactive: false),
                  Positioned(
                    right: 4,
                    bottom: 6,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: context.palette.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.theme.scaffoldBackgroundColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text('Mochi', style: context.text.headlineSmall)),
                Consumer(
                  builder: (context, ref, _) {
                    final p = ref.watch(mochiProgressProvider);
                    return Text(
                      'Level ${p.level} · ${p.stage.label} · your nutrition coach',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                    );
                  },
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'My kitchen',
            onPressed: () {
              Haptics.light();
              context.push('/kitchen');
            },
            icon: const Icon(Icons.soup_kitchen_outlined),
          ),
          IconButton(
            tooltip: "Mochi's wardrobe",
            onPressed: () {
              Haptics.light();
              context.push('/mochi');
            },
            icon: const Icon(Icons.checkroom_rounded),
          ),
          if (onClear != null)
            IconButton(tooltip: 'Clear chat', onPressed: onClear, icon: const Icon(Icons.delete_sweep_outlined)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- Welcome

class _Welcome extends StatelessWidget {
  const _Welcome({required this.name, required this.prompts, required this.onPick});
  final String name;
  final List<_Prompt> prompts;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.xl, Space.lg, Space.lg),
      children: [
        const Center(child: Mascot(mood: MascotMood.excited, size: 140)),
        const SizedBox(height: Space.md),
        Text(
          name.isEmpty ? 'Hi, I\'m Mochi!' : 'Hi $name, I\'m Mochi!',
          textAlign: TextAlign.center,
          style: context.text.headlineSmall,
        ),
        const SizedBox(height: Space.xxs),
        Text(
          'Ask me about meals, macros or habits.',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: Space.xl),
        const _KitchenCard().entrance(context),
        const SizedBox(height: Space.sm),
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: Space.sm),
          Row(
            children: [
              for (var col = 0; col < 2; col++) ...[
                if (col > 0) const SizedBox(width: Space.sm),
                Expanded(
                  child: _PromptCard(
                    prompt: prompts[row * 2 + col],
                    onTap: onPick,
                  ).entrance(context, index: 1 + row * 2 + col),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// Wide card that opens "My kitchen".
class _KitchenCard extends ConsumerWidget {
  const _KitchenCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pantryCountProvider);
    return AppCard(
      gradient: BrandSurfaces.hero(context.isDark),
      padding: const EdgeInsets.all(Space.md),
      onTap: () {
        Haptics.light();
        context.push('/kitchen');
      },
      semanticLabel: 'Cook with what I have. Open my kitchen',
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.colors.surface.withValues(alpha: context.isDark ? 0.5 : 0.85),
              borderRadius: Radii.smAll,
            ),
            child: const Text('🍳', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cook with what I have', style: context.text.titleSmall),
                Text(
                  count == 0 ? 'Add your ingredients and get a recipe' : '$count ingredients in your kitchen',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.prompt, required this.onTap});
  final _Prompt prompt;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: prompt.prompt,
      excludeSemantics: true,
      child: Pressable(
        child: Material(
          color: context.colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: Radii.mdAll,
            side: BorderSide(color: context.isDark ? BrandColors.darkOutline : BrandColors.lightOutline),
          ),
          child: InkWell(
            borderRadius: Radii.mdAll,
            onTap: () => onTap(prompt.prompt),
            child: Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: context.isDark ? 0.18 : 0.1),
                      borderRadius: Radii.smAll,
                    ),
                    child: Icon(prompt.icon, size: 18, color: context.colors.primary),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(prompt.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Messages

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.showAvatar});
  final ChatMessage message;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final maxW = MediaQuery.sizeOf(context).width * 0.74;
    const tail = Radius.circular(6);
    const round = Radius.circular(Radii.md);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      decoration: BoxDecoration(
        gradient: isUser ? context.palette.heroGradient : null,
        color: isUser ? null : context.colors.surface,
        border: isUser ? null : Border.all(color: context.isDark ? BrandColors.darkOutline : BrandColors.lightOutline),
        borderRadius: BorderRadius.only(
          topLeft: round,
          topRight: round,
          bottomLeft: isUser || !showAvatar ? round : tail,
          bottomRight: isUser ? tail : round,
        ),
      ),
      child: SelectableText(
        message.text,
        style: context.text.bodyMedium?.copyWith(
          color: isUser ? context.palette.onHero : context.colors.onSurface,
          height: 1.45,
        ),
      ),
    );

    return Semantics(
      label: isUser ? 'You said' : 'Mochi said',
      child: Padding(
        padding: EdgeInsets.only(bottom: showAvatar || isUser ? Space.md : Space.xxs),
        child: Row(
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              SizedBox.square(
                dimension: 32,
                child: showAvatar ? const Mascot(mood: MascotMood.happy, size: 32, interactive: false) : null,
              ),
              const SizedBox(width: Space.xs),
            ],
            Flexible(child: bubble.entrance(context)),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    return Semantics(
      label: 'Mochi is typing',
      child: Padding(
        padding: const EdgeInsets.only(bottom: Space.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Mascot(mood: MascotMood.happy, size: 32, interactive: false),
            const SizedBox(width: Space.xs),
            Container(
              height: 44,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border.all(color: context.isDark ? BrandColors.darkOutline : BrandColors.lightOutline),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(Radii.md),
                  topRight: Radius.circular(Radii.md),
                  bottomRight: Radius.circular(Radii.md),
                  bottomLeft: Radius.circular(6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(color: context.colors.onSurfaceVariant, shape: BoxShape.circle),
                        )
                        .animate(onPlay: (c) => reduce ? c.stop() : c.repeat(reverse: true), delay: (i * 160).ms)
                        .scaleXY(begin: 0.6, end: 1.0, duration: 420.ms, curve: Curves.easeInOut)
                        .fadeIn(begin: 0.35, duration: 420.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Space.md, left: 40),
      padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.xs, Space.xs),
      decoration: BoxDecoration(
        color: context.colors.error.withValues(alpha: 0.08),
        borderRadius: Radii.mdAll,
        border: Border.all(color: context.colors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: context.colors.error),
          const SizedBox(width: Space.xs),
          Expanded(child: Text(message, style: context.text.bodySmall)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- Composer

class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.prompts, required this.onPick});
  final List<_Prompt> prompts;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 4),
        itemCount: prompts.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.xs),
        itemBuilder: (context, i) {
          final p = prompts[i];
          return ActionChip(
            avatar: Icon(p.icon, size: 16, color: context.colors.primary),
            label: Text(p.label),
            onPressed: () => onPick(p.prompt),
          );
        },
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.canSend, required this.onSend});
  final TextEditingController controller;
  final bool canSend;
  final void Function([String? preset]) onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.md, 4, 4, 4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: context.isDark ? BrandColors.darkStrongOutline : BrandColors.lightStrongOutline),
        boxShadow: context.isDark ? null : context.palette.floatShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Message Mochi…',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Send',
            excludeSemantics: true,
            child: Pressable(
              enabled: canSend,
              child: GestureDetector(
                onTap: canSend ? () => onSend() : null,
                child: AnimatedContainer(
                  duration: motionDuration(context, AppDurations.medium),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: canSend ? context.palette.heroGradient : null,
                    color: canSend ? null : context.colors.surfaceContainerHigh,
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: canSend ? context.palette.onHero : context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
