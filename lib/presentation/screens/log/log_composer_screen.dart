import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_x.dart';
import '../../../domain/entities/food_log.dart';
import '../../../domain/entities/macros.dart';
import '../../providers/core_providers.dart';
import '../../providers/food_providers.dart';
import '../../providers/log_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/count_up_text.dart';
import '../../widgets/food_picker_sheet.dart';
import '../../widgets/macro_bar.dart';
import '../../widgets/motion.dart';
import 'review_widgets.dart';

enum LogMode { photo, text, voice }

enum _Phase { input, analyzing, review, error }

class LogComposerScreen extends ConsumerStatefulWidget {
  const LogComposerScreen({super.key, required this.mode, this.initialMeal});
  final LogMode mode;
  final MealType? initialMeal;

  @override
  ConsumerState<LogComposerScreen> createState() => _LogComposerScreenState();
}

class _LogComposerScreenState extends ConsumerState<LogComposerScreen> {
  _Phase _phase = _Phase.input;
  List<LoggedFood> _items = [];
  String? _error;
  late MealType _meal = widget.initialMeal ?? MealType.forTime(DateTime.now());

  // Photo: several angles/dishes of the same meal, analysed together.
  static const _maxPhotos = 5;
  final List<Uint8List> _photos = [];
  final Set<String> _tags = {};
  final _hintCtrl = TextEditingController();
  static const _tagOptions = ['Home-cooked', 'Restaurant', 'Less oil', 'Extra oil / ghee', 'Shared plate'];

  // Text & voice
  final _textCtrl = TextEditingController();
  final _speech = SpeechToText();
  bool _speechReady = false;
  bool _listening = false;
  String? _speechError;
  double _level = 0;

  @override
  void initState() {
    super.initState();
    if (widget.mode == LogMode.voice) _initSpeech();
  }

  @override
  void dispose() {
    _hintCtrl.dispose();
    _textCtrl.dispose();
    if (_listening) _speech.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ Input flows

  Future<void> _pickImage(ImageSource source) async {
    final room = _maxPhotos - _photos.length;
    if (room <= 0) {
      showAppSnack(context, 'Up to $_maxPhotos photos per meal');
      return;
    }
    try {
      final picker = ImagePicker();
      final files = source == ImageSource.camera || room == 1
          ? [?await picker.pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 80)]
          : await picker.pickMultiImage(maxWidth: 1280, maxHeight: 1280, imageQuality: 80, limit: room);
      if (files.isEmpty) return;
      final bytes = [for (final f in files.take(room)) await f.readAsBytes()];
      if (!mounted) return;
      Haptics.light();
      setState(() {
        _photos.addAll(bytes);
        _phase = _Phase.input;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = source == ImageSource.camera
            ? "Couldn't open the camera. Check camera permission in Settings."
            : "Couldn't open your photos. Check photo permission in Settings.";
      });
    }
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize(
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            if (e.permanent) _speechError = 'Didn\'t catch that. Tap the mic to try again.';
          });
        },
        onStatus: (status) {
          if (!mounted) return;
          if (status == SpeechToText.notListeningStatus || status == SpeechToText.doneStatus) {
            setState(() => _listening = false);
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _speechReady = ok;
        if (!ok) _speechError = 'Speech recognition isn\'t available. Check microphone permission, or type instead.';
      });
      if (ok) _toggleListening();
    } catch (_) {
      if (mounted) setState(() => _speechError = 'Speech recognition isn\'t available on this device.');
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechReady) return _initSpeech();
    if (_listening) {
      Haptics.light();
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    Haptics.medium();
    setState(() {
      _listening = true;
      _speechError = null;
    });
    await _speech.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() => _textCtrl.text = r.recognizedWords);
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
          setState(() => _listening = false);
          _analyze();
        }
      },
      onSoundLevelChange: (level) {
        if (mounted) setState(() => _level = level.clamp(0, 12) / 12);
      },
      listenOptions: SpeechListenOptions(partialResults: true, cancelOnError: true, listenMode: ListenMode.dictation),
    );
  }

  Future<void> _analyze() async {
    final ai = ref.read(aiServiceProvider);
    final text = _textCtrl.text.trim();
    if (widget.mode != LogMode.photo && text.isEmpty) return;
    if (widget.mode == LogMode.photo && _photos.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _phase = _Phase.analyzing;
      _error = null;
    });
    try {
      final items = widget.mode == LogMode.photo
          ? await ai.analyzePhotos(List.of(_photos), hint: _hintCtrl.text, tags: _tags.toList())
          : await ai.parseText(text);
      if (!mounted) return;
      Haptics.success();
      setState(() {
        _items = items;
        _phase = _Phase.review;
      });
    } catch (e) {
      if (!mounted) return;
      Haptics.warning();
      setState(() {
        _error = e.toString();
        _phase = _Phase.error;
      });
    }
  }

  // ----------------------------------------------------------- Review flows

  Future<void> _editItem(int index) async {
    final result = await showItemEditSheet(context, _items[index]);
    if (result == null || !mounted) return;
    if (result.action == ItemEditAction.delete) {
      _removeItem(index);
    } else if (result.item != null) {
      setState(() => _items[index] = result.item!);
    }
  }

  void _removeItem(int index) {
    final removed = _items[index];
    Haptics.medium();
    setState(() => _items.removeAt(index));
    showAppSnack(
      context,
      'Removed ${removed.name}',
      onUndo: () {
        if (mounted) setState(() => _items.insert(index.clamp(0, _items.length), removed));
      },
    );
  }

  Future<void> _addItem() async {
    final food = await showFoodPickerSheet(context, title: 'Add an item');
    if (food == null || !mounted) return;
    Haptics.light();
    setState(() => _items.add(LoggedFood.fromFood(food)));
  }

  Future<void> _save() async {
    if (_items.isEmpty) return;
    final day = ref.read(selectedDateProvider);
    final source = switch (widget.mode) {
      LogMode.photo => LogSource.photo,
      LogMode.text => LogSource.text,
      LogMode.voice => LogSource.voice,
    };
    await ref.read(logsProvider.notifier).addFoods(_items, meal: _meal, day: day, source: source);
    await Haptics.success();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final count = _items.length;
    context.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Logged $count item${count == 1 ? '' : 's'} to ${_meal.label} ${_meal.emoji}')),
    );
  }

  Future<void> _saveTemplate() async {
    final ctrl = TextEditingController(text: _items.map((i) => i.name).take(2).join(' & '));
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as meal template'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    disposeAfterClose([ctrl]);
    if (name == null || name.trim().isEmpty || !mounted) return;
    await ref.read(templatesProvider.notifier).create(name.trim(), [..._items], emoji: _items.first.emoji);
    Haptics.success();
    if (mounted) showAppSnack(context, 'Template "$name" saved');
  }

  // ------------------------------------------------------------------ UI

  String get _title => switch (widget.mode) {
    LogMode.photo => 'Snap a meal',
    LogMode.text => 'Describe your meal',
    LogMode.voice => 'Say what you ate',
  };

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(selectedDateProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (_phase == _Phase.review && _items.isNotEmpty)
            IconButton(
              tooltip: 'Save as meal template',
              onPressed: _saveTemplate,
              icon: const Icon(Icons.bookmark_add_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!day.isToday)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: Space.md),
                padding: const EdgeInsets.all(Space.sm),
                decoration: BoxDecoration(
                  color: context.colors.tertiary.withValues(alpha: 0.12),
                  borderRadius: Radii.smAll,
                ),
                child: Text(
                  'Logging to ${day.friendlyLabel}',
                  textAlign: TextAlign.center,
                  style: context.text.labelLarge?.copyWith(color: context.colors.tertiary),
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: motionDuration(context, AppDurations.medium),
                switchInCurve: AppCurves.easeOut,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_phase),
                  child: switch (_phase) {
                    _Phase.input => _buildInput(),
                    _Phase.analyzing => _buildAnalyzing(),
                    _Phase.review => _buildReview(),
                    _Phase.error => _buildError(),
                  },
                ),
              ),
            ),
            if (_phase == _Phase.review) _buildSaveBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() => switch (widget.mode) {
    LogMode.photo => _photoInput(),
    LogMode.text => _textInput(),
    LogMode.voice => _voiceInput(),
  };

  Widget _photoInput() {
    if (_photos.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          // Grows with its content, so large text never spills out.
          Container(
            constraints: const BoxConstraints(minHeight: 240),
            padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xxl),
            decoration: BoxDecoration(gradient: context.palette.heroGradient, borderRadius: Radii.lgAll),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_camera_rounded, size: 72, color: context.palette.onHero).popIn(context),
                const SizedBox(height: Space.md),
                Text(
                  'Point, shoot, done.',
                  textAlign: TextAlign.center,
                  style: context.text.headlineSmall?.copyWith(color: context.palette.onHero),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  'Add up to $_maxPhotos photos of one meal. A top view plus a side angle gives the best portions.',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(color: context.palette.onHero.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ).entrance(context),
          const SizedBox(height: Space.lg),
          Pressable(
            child: FilledButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Take photo'),
            ),
          ).entrance(context, index: 1),
          const SizedBox(height: Space.sm),
          OutlinedButton.icon(
            onPressed: () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Choose from library'),
          ).entrance(context, index: 2),
        ],
      );
    }

    final canAdd = _photos.length < _maxPhotos;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.lg),
            children: [
              Text(
                '${_photos.length} photo${_photos.length == 1 ? '' : 's'} of this meal',
                style: context.text.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                canAdd ? 'Add another angle or dish for better portions.' : "That's the maximum for one meal.",
                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: Space.md),
              LayoutBuilder(
                builder: (context, c) {
                  final size = (c.maxWidth - Space.xs * 2) / 3;
                  return Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xs,
                    children: [
                      for (final (i, bytes) in _photos.indexed)
                        _PhotoTile(
                          key: ObjectKey(bytes),
                          bytes: bytes,
                          size: size,
                          onRemove: () {
                            Haptics.tap();
                            setState(() => _photos.removeAt(i));
                          },
                        ),
                      if (canAdd)
                        _AddPhotoTile(
                          size: size,
                          onCamera: () => _pickImage(ImageSource.camera),
                          onGallery: () => _pickImage(ImageSource.gallery),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: Space.lg),
              Wrap(
                spacing: Space.xs,
                runSpacing: Space.xs,
                children: [
                  for (final t in _tagOptions)
                    FilterChip(
                      label: Text(t),
                      selected: _tags.contains(t),
                      onSelected: (v) {
                        Haptics.tap();
                        setState(() => v ? _tags.add(t) : _tags.remove(t));
                      },
                    ),
                ],
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: _hintCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                  hintText: 'e.g. 2 rotis, ate half the rice',
                  prefixIcon: Icon(Icons.tips_and_updates_outlined),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: Space.sm),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.lg, Space.xs),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                onPressed: _analyze,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _photos.length == 1 ? 'Analyze photo' : 'Analyze ${_photos.length} photos',
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static const _examples = [
    '2 eggs, toast with butter and a coffee with milk',
    'Chicken burrito and a cola',
    'Greek yogurt with berries and granola',
    'Salmon, sweet potato and broccoli',
  ];

  Widget _textInput() {
    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        TextField(
          controller: _textCtrl,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'What did you eat? Write it like a text message…'),
          onChanged: (_) => setState(() {}),
        ).entrance(context),
        const SizedBox(height: Space.md),
        Text('Try one', style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant)),
        const SizedBox(height: Space.xs),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            for (final e in _examples)
              ActionChip(
                label: Text(e),
                onPressed: () {
                  Haptics.tap();
                  setState(() => _textCtrl.text = e);
                },
              ),
          ],
        ).entrance(context, index: 1),
        const SizedBox(height: Space.xl),
        Pressable(
          child: FilledButton.icon(
            onPressed: _textCtrl.text.trim().isEmpty ? null : _analyze,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Analyze'),
          ),
        ),
      ],
    );
  }

  Widget _voiceInput() {
    final reduce = context.reduceMotion;
    final color = context.colors.primary;
    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        const SizedBox(height: Space.xl),
        Center(
          child: Semantics(
            button: true,
            label: _listening ? 'Stop listening' : 'Start listening',
            child: GestureDetector(
              onTap: _toggleListening,
              child: SizedBox.square(
                dimension: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_listening && !reduce)
                      for (var i = 0; i < 3; i++)
                        Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.18)),
                            )
                            .animate(onPlay: (c) => c.repeat(), delay: (i * 500).ms)
                            .scaleXY(begin: 1, end: 1.65, duration: 1500.ms, curve: Curves.easeOut)
                            .fadeOut(duration: 1500.ms),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 120 + (_listening ? _level * 24 : 0),
                      height: 120 + (_listening ? _level * 24 : 0),
                      decoration: BoxDecoration(
                        gradient: _listening ? context.palette.duskGradient : context.palette.heroGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded, size: 52, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        Text(
          _listening ? 'Listening…' : (_speechReady ? 'Tap the mic and describe your meal' : 'Preparing microphone…'),
          textAlign: TextAlign.center,
          style: context.text.titleMedium,
        ),
        if (_speechError != null) ...[
          const SizedBox(height: Space.xs),
          Text(
            _speechError!,
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: context.colors.error),
          ),
        ],
        const SizedBox(height: Space.xl),
        TextField(
          controller: _textCtrl,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Transcript',
            hintText: '"A bowl of oatmeal with banana and a latte"',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Space.lg),
        FilledButton.icon(
          onPressed: _textCtrl.text.trim().isEmpty || _listening ? null : _analyze,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Analyze'),
        ),
      ],
    );
  }

  Widget _buildAnalyzing() {
    final reduce = context.reduceMotion;
    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        if (_photos.isNotEmpty) ...[
          ClipRRect(
            borderRadius: Radii.lgAll,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_photos.first, fit: BoxFit.cover, semanticLabel: 'Your meal photo'),
                  if (!reduce)
                    Align(
                      alignment: Alignment.topCenter,
                      child:
                          Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(color: context.colors.primary, blurRadius: 16, spreadRadius: 2),
                                  ],
                                  color: Colors.white,
                                ),
                              )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .slideY(begin: 0, end: 70, duration: 1600.ms, curve: Curves.easeInOut),
                    ),
                ],
              ),
            ),
          ),
          if (_photos.length > 1) ...[
            const SizedBox(height: Space.xs),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length - 1,
                separatorBuilder: (_, _) => const SizedBox(width: Space.xs),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: Radii.smAll,
                  child: Image.memory(_photos[i + 1], width: 52, height: 52, fit: BoxFit.cover, cacheWidth: 160),
                ),
              ),
            ),
          ],
        ] else
          AppCard(
            child: Row(
              children: [
                Icon(Icons.format_quote_rounded, color: context.colors.primary),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(_textCtrl.text, style: context.text.bodyLarge)),
              ],
            ),
          ),
        const SizedBox(height: Space.lg),
        Row(
          children: [
            Icon(
              Icons.auto_awesome,
              color: context.colors.primary,
            ).animate(onPlay: (c) => reduce ? c.stop() : c.repeat()).rotate(duration: 2.seconds),
            const SizedBox(width: Space.sm),
            Text(
              widget.mode == LogMode.photo
                  ? (_photos.length > 1 ? 'Combining ${_photos.length} photos…' : 'Identifying foods & portions…')
                  : 'Breaking it down…',
              style: context.text.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        const SkeletonList(count: 3),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          children: [
            ErrorState(
              title: 'Couldn\'t analyze that',
              message: _error ?? 'Unknown error',
              onRetry: (widget.mode == LogMode.photo && _photos.isEmpty) ? null : _analyze,
            ),
            TextButton(
              onPressed: () => setState(() => _phase = _Phase.input),
              child: Text(widget.mode == LogMode.photo ? 'Choose another photo' : 'Edit description'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReview() {
    if (_items.isEmpty) {
      return Center(
        child: EmptyState(
          emoji: '🍽️',
          title: 'No items left',
          message: 'Add something from the database or start over.',
          actionLabel: 'Add item',
          onAction: _addItem,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.lg),
      children: [
        Row(
          children: [
            if (_photos.isNotEmpty) ...[
              Badge(
                isLabelVisible: _photos.length > 1,
                label: Text('${_photos.length}'),
                child: ClipRRect(
                  borderRadius: Radii.smAll,
                  child: Image.memory(
                    _photos.first,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    cacheWidth: 170,
                    semanticLabel: 'Meal photo',
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Found ${_items.length} item${_items.length == 1 ? '' : 's'}', style: context.text.titleLarge),
                  Text(
                    'Tap to adjust · swipe to remove',
                    style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _phase = _Phase.input),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Redo'),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: SwipeToDelete(
              dismissKey: ObjectKey(_items[i]),
              onDelete: () => _removeItem(i),
              child: ReviewItemCard(item: _items[i], onTap: () => _editItem(i)),
            ).entrance(context, index: i),
          ),
        OutlinedButton.icon(onPressed: _addItem, icon: const Icon(Icons.add_rounded), label: const Text('Add item')),
      ],
    );
  }

  Widget _buildSaveBar() {
    final total = Macros.sum(_items.map((i) => i.macros));
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.lg)),
        border: Border(top: BorderSide(color: context.colors.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: MacroInline(macros: total)),
              CountUpText(
                value: total.kcal,
                duration: AppDurations.medium,
                suffix: ' kcal',
                style: context.text.titleLarge?.copyWith(color: context.colors.primary),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          MealPicker(value: _meal, onChanged: (m) => setState(() => _meal = m)),
          const SizedBox(height: Space.sm),
          SizedBox(
            width: double.infinity,
            child: Pressable(
              child: FilledButton.icon(
                onPressed: _items.isEmpty ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text('Add to ${_meal.label}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({super.key, required this.bytes, required this.size, required this.onRemove});
  final Uint8List bytes;
  final double size;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: Radii.mdAll,
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              semanticLabel: 'Meal photo',
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: Colors.white, semanticLabel: 'Remove photo'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.size, required this.onCamera, required this.onGallery});
  final double size;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final outline = context.isDark ? BrandColors.darkStrongOutline : BrandColors.lightStrongOutline;
    Widget half(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: context.colors.primary),
                Text(label, style: context.text.labelSmall?.copyWith(color: context.colors.primary)),
              ],
            ),
          ),
        ),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: Material(
        color: context.colors.primary.withValues(alpha: context.isDark ? 0.12 : 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(color: outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            half(Icons.camera_alt_rounded, 'Camera', onCamera),
            Divider(height: 1, color: outline),
            half(Icons.photo_library_rounded, 'Gallery', onGallery),
          ],
        ),
      ),
    );
  }
}
