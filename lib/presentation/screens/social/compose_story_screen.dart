import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/entities/kitchen.dart';
import '../../../domain/entities/social.dart';
import '../../providers/kitchen_providers.dart';
import '../../providers/social_providers.dart';
import '../../widgets/common.dart';
import 'story_progress_card.dart';

/// Add to your story: a progress card made from today, or a photo.
class ComposeStoryScreen extends ConsumerStatefulWidget {
  const ComposeStoryScreen({super.key});

  @override
  ConsumerState<ComposeStoryScreen> createState() => _ComposeStoryScreenState();
}

class _ComposeStoryScreenState extends ConsumerState<ComposeStoryScreen> {
  StoryKind _kind = StoryKind.progress;
  final _caption = TextEditingController();
  Uint8List? _photo;
  bool _statsSticker = true;
  Recipe? _recipe;
  bool _posting = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1440, maxHeight: 1920, imageQuality: 82);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    Haptics.light();
    setState(() => _photo = bytes);
  }

  Future<void> _pickRecipe() async {
    final saved = ref.read(savedRecipesProvider);
    if (saved.isEmpty) {
      showAppSnack(context, 'Save a recipe in My kitchen first.');
      return;
    }
    final r = await showModalBottomSheet<Recipe>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      sheetAnimationStyle: kSheetAnimation,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: Space.lg),
        children: [
          for (final r in saved)
            ListTile(
              leading: Text(r.emoji, style: const TextStyle(fontSize: 24)),
              title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${r.minutes} min · ${r.perServing.kcal.round()} kcal'),
              onTap: () => Navigator.pop(ctx, r),
            ),
        ],
      ),
    );
    if (r != null) setState(() => _recipe = r);
  }

  Future<void> _share() async {
    if (_kind == StoryKind.photo && _photo == null && _caption.text.trim().isEmpty) {
      showAppSnack(context, 'Add a photo or some text.');
      return;
    }
    setState(() => _posting = true);
    final progress = ref.read(todayProgressProvider);
    try {
      await ref
          .read(storiesProvider.notifier)
          .create(
            NewStory(
              kind: _kind,
              caption: _caption.text,
              photo: _kind == StoryKind.photo ? _photo : null,
              progress: _kind == StoryKind.progress || _statsSticker ? progress : null,
              recipe: _recipe,
            ),
          );
      Haptics.success();
      if (!mounted) return;
      showAppSnack(context, 'Added to your story · visible for 24 hours');
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
    final progress = ref.watch(todayProgressProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Add to story')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.lg),
              children: [
                SegmentedButton<StoryKind>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: StoryKind.progress,
                      icon: Icon(Icons.auto_graph_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Progress card', maxLines: 1, softWrap: false),
                      ),
                    ),
                    ButtonSegment(
                      value: StoryKind.photo,
                      icon: Icon(Icons.photo_camera_outlined, size: 18),
                      label: FittedBox(fit: BoxFit.scaleDown, child: Text('Photo', maxLines: 1, softWrap: false)),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) {
                    Haptics.tap();
                    setState(() => _kind = s.first);
                  },
                ),
                const SizedBox(height: Space.md),

                // ---- Preview (story aspect ratio)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: ClipRRect(
                        borderRadius: Radii.lgAll,
                        child: _kind == StoryKind.progress
                            ? ListenableBuilder(
                                listenable: _caption,
                                builder: (context, _) =>
                                    StoryProgressCard(progress: progress, caption: _caption.text, compact: true),
                              )
                            : _PhotoPreview(
                                photo: _photo,
                                progress: _statsSticker ? progress : null,
                                onCamera: () => _pick(ImageSource.camera),
                                onGallery: () => _pick(ImageSource.gallery),
                                onClear: () => setState(() => _photo = null),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
                TextField(
                  controller: _caption,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _kind == StoryKind.progress ? 'Say something about today' : 'Add a caption',
                    counterText: '',
                  ),
                ),
                if (_kind == StoryKind.photo)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Add today\'s stats sticker'),
                    subtitle: const Text('Streak and calories on your photo'),
                    value: _statsSticker,
                    onChanged: (v) => setState(() => _statsSticker = v),
                  ),
                const SizedBox(height: Space.xs),
                if (_recipe != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(_recipe!.emoji, style: const TextStyle(fontSize: 26)),
                    title: Text(_recipe!.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: const Text('Friends can save this recipe'),
                    trailing: IconButton(
                      tooltip: 'Remove recipe',
                      onPressed: () => setState(() => _recipe = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _pickRecipe,
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('Attach a recipe'),
                  ),
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    Icon(Icons.lock_clock_outlined, size: 16, color: context.colors.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Friends only · disappears after 24 hours',
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
                  onPressed: _posting ? null : _share,
                  icon: _posting
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_circle_outline_rounded),
                  label: Text(_posting ? 'Sharing…' : 'Share to story'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.photo,
    required this.progress,
    required this.onCamera,
    required this.onGallery,
    required this.onClear,
  });

  final Uint8List? photo;
  final StoryProgress? progress;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return Material(
        color: context.colors.surfaceContainerHigh,
        child: Column(
          children: [
            Expanded(
              child: InkWell(
                onTap: onCamera,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_camera_rounded, size: 36, color: context.colors.primary),
                      Text('Camera', style: TextStyle(color: context.colors.primary)),
                    ],
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: context.colors.outlineVariant),
            Expanded(
              child: InkWell(
                onTap: onGallery,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_library_rounded, size: 36, color: context.colors.primary),
                      Text('Gallery', style: TextStyle(color: context.colors.primary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(photo!, fit: BoxFit.cover),
        if (progress != null) Positioned(left: 12, bottom: 12, child: StatsSticker(progress: progress!)),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton.filledTonal(
            tooltip: 'Remove photo',
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ],
    );
  }
}

/// Small frosted sticker with streak and calories, shown on photo stories.
class StatsSticker extends StatelessWidget {
  const StatsSticker({super.key, required this.progress});
  final StoryProgress progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            p.streak > 0 ? 'Day ${p.streak} 🔥' : 'Today',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
          ),
          Text(
            '${p.kcal}/${p.kcalGoal} kcal · ${p.protein}g protein',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
