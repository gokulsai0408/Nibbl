import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_x.dart';
import '../../../domain/entities/food_log.dart';
import '../../../domain/entities/kitchen.dart';
import '../../../domain/entities/social.dart';
import '../../providers/kitchen_providers.dart';
import '../../providers/log_providers.dart';
import '../../providers/social_providers.dart';
import '../../widgets/common.dart';

/// Share a dish: photo, caption, and optionally the food log or recipe it
/// came from (so friends see calories and can cook it too).
class ComposePostScreen extends ConsumerStatefulWidget {
  const ComposePostScreen({super.key, this.recipe});
  final Recipe? recipe;

  @override
  ConsumerState<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends ConsumerState<ComposePostScreen> {
  final _caption = TextEditingController();
  Uint8List? _photo;
  LoggedFood? _food;
  late Recipe? _recipe = widget.recipe;
  bool _posting = false;
  PostCategory _category = PostCategory.food;
  String _activityType = 'Gym';
  final _minutes = TextEditingController();
  final _burned = TextEditingController();
  final _distance = TextEditingController();

  static const _workoutTypes = ['Gym', 'Yoga', 'Sport', 'HIIT', 'Home workout', 'Swim'];
  static const _cardioTypes = ['Walk', 'Run', 'Cycle', 'Hike', 'Steps'];

  @override
  void dispose() {
    _caption.dispose();
    _minutes.dispose();
    _burned.dispose();
    _distance.dispose();
    super.dispose();
  }

  PostActivity? _activity() {
    if (!_category.hasActivity) return null;
    int? n(TextEditingController c) => int.tryParse(c.text.trim());
    final dist = double.tryParse(_distance.text.trim().replaceAll(',', '.'));
    final isSteps = _activityType == 'Steps';
    return PostActivity(
      type: _activityType,
      minutes: isSteps ? null : n(_minutes),
      kcal: n(_burned),
      distanceKm: isSteps ? null : dist,
      steps: isSteps ? n(_distance) : null,
    );
  }

  String get _captionHint => switch (_category) {
    PostCategory.food => 'What did you make? How did it turn out?',
    PostCategory.workout => 'How did the session go?',
    PostCategory.cardio => 'Where did you go? How did it feel?',
    PostCategory.sleep => 'How did you sleep?',
    PostCategory.mind => 'What helped you feel good today?',
    PostCategory.milestone => 'What did you achieve? 🎉',
    PostCategory.life => 'Share a moment from your day',
  };

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1440, maxHeight: 1440, imageQuality: 82);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    Haptics.light();
    setState(() => _photo = bytes);
  }

  Future<void> _attachFood() async {
    final today = ref.read(logsByDayProvider)[DateTime.now().dayKey] ?? const <FoodLog>[];
    final recent = [...today.reversed];
    if (recent.isEmpty) {
      showAppSnack(context, 'Nothing logged today yet.');
      return;
    }
    final picked = await showModalBottomSheet<LoggedFood>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      sheetAnimationStyle: kSheetAnimation,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: Space.lg),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
              child: Text('From today\'s log', style: ctx.text.titleMedium),
            ),
            for (final l in recent)
              ListTile(
                leading: Text(l.food.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(l.food.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${l.meal.label} · ${l.food.macros.kcal.round()} kcal'),
                onTap: () => Navigator.pop(ctx, l.food),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _food = picked);
  }

  Future<void> _attachRecipe() async {
    final saved = ref.read(savedRecipesProvider);
    if (saved.isEmpty) {
      showAppSnack(context, 'Save a recipe in My kitchen first.');
      return;
    }
    final picked = await showModalBottomSheet<Recipe>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      sheetAnimationStyle: kSheetAnimation,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: Space.lg),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
              child: Text('Your saved recipes', style: ctx.text.titleMedium),
            ),
            for (final r in saved)
              ListTile(
                leading: Text(r.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${r.minutes} min · ${r.perServing.kcal.round()} kcal'),
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _recipe = picked);
  }

  Future<void> _post() async {
    if (_photo == null && _caption.text.trim().isEmpty && _food == null && _recipe == null && _activity() == null) {
      showAppSnack(context, 'Add a photo or a few words first.');
      return;
    }
    setState(() => _posting = true);
    final isFood = _category == PostCategory.food;
    final food = isFood ? _food : null;
    final recipe = isFood ? _recipe : null;
    try {
      await ref
          .read(feedProvider.notifier)
          .create(
            NewPost(
              caption: _caption.text,
              photo: _photo,
              dishName: food?.name ?? recipe?.title,
              emoji: food?.emoji ?? recipe?.emoji,
              kcal: (food?.macros.kcal ?? recipe?.perServing.kcal)?.round(),
              protein: (food?.macros.protein ?? recipe?.perServing.protein)?.round(),
              recipe: recipe,
              category: _category,
              activity: _activity(),
            ),
          );
      Haptics.success();
      if (!mounted) return;
      showAppSnack(context, 'Shared with your friends');
      context.pop();
    } catch (e) {
      Haptics.warning();
      if (mounted) showAppSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = _food;
    final recipe = _recipe;
    return Scaffold(
      appBar: AppBar(title: const Text('Share')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.lg),
              children: [
                // ---- What it's about
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final c in PostCategory.values) ...[
                        ChoiceChip(
                          avatar: Text(c.emoji),
                          label: Text(c.label),
                          showCheckmark: false,
                          selected: c == _category,
                          onSelected: (_) {
                            Haptics.tap();
                            setState(() {
                              _category = c;
                              if (c == PostCategory.workout) _activityType = _workoutTypes.first;
                              if (c == PostCategory.cardio) _activityType = _cardioTypes.first;
                            });
                          },
                        ),
                        const SizedBox(width: Space.xs),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Space.md),

                // ---- Photo
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
                                  tooltip: 'Remove photo',
                                  onPressed: () => setState(() => _photo = null),
                                  icon: const Icon(Icons.close_rounded),
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
                                    child: const _PickOption(icon: Icons.photo_camera_rounded, label: 'Camera'),
                                  ),
                                ),
                                VerticalDivider(width: 1, color: context.colors.outlineVariant),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _pick(ImageSource.gallery),
                                    child: const _PickOption(icon: Icons.photo_library_rounded, label: 'Gallery'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: Space.md),
                TextField(
                  controller: _caption,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: _captionHint),
                ),
                const SizedBox(height: Space.sm),

                // ---- Workout / cardio details
                if (_category.hasActivity) ...[
                  const SectionHeader(title: 'Activity'),
                  Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xs,
                    children: [
                      for (final t in _category == PostCategory.workout ? _workoutTypes : _cardioTypes)
                        ChoiceChip(
                          label: Text(t),
                          selected: t == _activityType,
                          onSelected: (_) => setState(() => _activityType = t),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  Row(
                    children: [
                      if (_activityType != 'Steps') ...[
                        Expanded(
                          child: _NumField(controller: _minutes, label: 'Minutes'),
                        ),
                        const SizedBox(width: Space.xs),
                      ],
                      if (_category == PostCategory.cardio) ...[
                        Expanded(
                          child: _NumField(
                            controller: _distance,
                            label: _activityType == 'Steps' ? 'Steps' : 'Km',
                            decimal: _activityType != 'Steps',
                          ),
                        ),
                        const SizedBox(width: Space.xs),
                      ],
                      Expanded(
                        child: _NumField(controller: _burned, label: 'Kcal burned'),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                ],

                // ---- Attachments (food)
                if (_category == PostCategory.food) ...[
                  const SectionHeader(title: 'Attach (optional)'),
                  if (food != null)
                    _Attached(
                      emoji: food.emoji,
                      title: food.name,
                      subtitle: '${food.macros.kcal.round()} kcal · ${food.macros.protein.round()}g protein',
                      onRemove: () => setState(() => _food = null),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _attachFood,
                      icon: const Icon(Icons.restaurant_rounded),
                      label: const Text('From today\'s log'),
                    ),
                  const SizedBox(height: Space.xs),
                  if (recipe != null)
                    _Attached(
                      emoji: recipe.emoji,
                      title: recipe.title,
                      subtitle: 'Recipe · friends can save it',
                      onRemove: () => setState(() => _recipe = null),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _attachRecipe,
                      icon: const Icon(Icons.menu_book_rounded),
                      label: const Text('A saved recipe'),
                    ),
                ],
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 16, color: context.colors.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Only your friends can see this.',
                        style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: Space.sm),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.xs),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                  onPressed: _posting ? null : _post,
                  icon: _posting
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  label: Text(_posting ? 'Sharing…' : 'Share'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickOption extends StatelessWidget {
  const _PickOption({required this.icon, required this.label});
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
            Icon(icon, size: 34, color: context.colors.primary),
            const SizedBox(height: Space.xxs),
            Text(label, style: context.text.labelLarge?.copyWith(color: context.colors.primary)),
          ],
        ),
      ),
    );
  }
}

class _Attached extends StatelessWidget {
  const _Attached({required this.emoji, required this.title, required this.subtitle, required this.onRemove});
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.xs, Space.xxs, Space.xs),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
              ],
            ),
          ),
          IconButton(tooltip: 'Remove', onPressed: onRemove, icon: const Icon(Icons.close_rounded)),
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.controller, required this.label, this.decimal = false});
  final TextEditingController controller;
  final String label;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }
}
