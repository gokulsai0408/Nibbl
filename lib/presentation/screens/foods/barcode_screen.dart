import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/remote/open_food_facts_api.dart';
import '../../../domain/entities/food_log.dart';
import '../../providers/core_providers.dart';
import '../../providers/food_providers.dart';
import '../../widgets/common.dart';

enum _ScanState { scanning, looking, notFound, error }

class BarcodeScreen extends ConsumerStatefulWidget {
  const BarcodeScreen({super.key, this.initialMeal});
  final MealType? initialMeal;

  @override
  ConsumerState<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends ConsumerState<BarcodeScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    // Retail codes plus ITF-14 / Code 128, which some Indian and bulk packs use.
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.itf14,
      BarcodeFormat.code128,
    ],
  );
  _ScanState _state = _ScanState.scanning;
  String? _code;
  String? _message;
  String? _productName;
  String? _brand;
  bool _identifying = false;
  bool _torch = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_state != _ScanState.scanning) return;
    final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (code == null) return;
    await _lookup(code);
  }

  Future<void> _lookup(String code) async {
    Haptics.medium();
    await _controller.stop();
    setState(() {
      _state = _ScanState.looking;
      _code = code;
    });

    // Cached from a previous scan (under any spelling of the barcode)?
    final variants = barcodeVariants(code).toSet();
    final cached =
        ref.read(foodsProvider.notifier).byId('off_$code') ??
        ref.read(foodsProvider).where((f) => f.barcode != null && variants.contains(f.barcode)).firstOrNull;
    if (cached != null) return _open(cached.id);

    try {
      final food = await ref.read(openFoodFactsProvider).lookup(code);
      await ref.read(foodsProvider.notifier).upsert(food);
      await _open(food.id);
    } on BarcodeLookupException catch (e) {
      if (!mounted) return;
      Haptics.warning();
      setState(() {
        _state = e.notFound ? _ScanState.notFound : _ScanState.error;
        _message = e.message;
        _productName = e.productName;
        _brand = e.brand;
      });
    }
  }

  Future<void> _open(String id) async {
    if (!mounted) return;
    Haptics.success();
    final meal = widget.initialMeal == null ? '' : '?meal=${widget.initialMeal!.name}';
    context.pushReplacement('/food/${Uri.encodeComponent(id)}$meal');
  }

  /// AI fallback: read the label from photos, or estimate from the name.
  Future<void> _identify({required bool withPhotos}) async {
    final code = _code;
    if (code == null) return;
    var photos = <Uint8List>[];
    if (withPhotos) {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        useRootNavigator: true,
        sheetAnimationStyle: kSheetAnimation,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Photo of the nutrition label'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose photos (label + front)'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;
      final picker = ImagePicker();
      final files = source == ImageSource.camera
          ? [?await picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85)]
          : await picker.pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 85, limit: 3);
      if (files.isEmpty || !mounted) return;
      photos = [for (final f in files.take(3)) await f.readAsBytes()];
    }
    if (!mounted) return;
    setState(() => _identifying = true);
    try {
      final result = await ref
          .read(aiServiceProvider)
          .identifyProduct(barcode: code, photos: photos, name: _productName, brand: _brand);
      if (!mounted) return;
      Haptics.success();
      // Let the user check the numbers before saving.
      context.pushReplacement('/foods/new?barcode=$code', extra: result);
    } catch (e) {
      if (!mounted) return;
      Haptics.warning();
      showAppSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _identifying = false);
    }
  }

  Future<void> _rescan() async {
    setState(() {
      _state = _ScanState.scanning;
      _message = null;
      _productName = null;
      _brand = null;
    });
    await _controller.start();
  }

  Future<void> _enterManually() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter barcode'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g. 3017620422003'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Look up')),
        ],
      ),
    );
    disposeAfterClose([ctrl]);
    if (code != null && code.isNotEmpty) await _lookup(code);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text('Scan barcode', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: _torch ? 'Turn off flashlight' : 'Turn on flashlight',
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() => _torch = !_torch);
            },
            icon: Icon(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded),
          ),
          IconButton(tooltip: 'Type barcode', onPressed: _enterManually, icon: const Icon(Icons.keyboard_rounded)),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => ColoredBox(
              color: context.colors.surface,
              child: Center(
                child: ErrorState(
                  title: 'Camera unavailable',
                  message: error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Allow camera access in Settings to scan barcodes, or type the code instead.'
                      : 'The camera couldn\'t start. You can type the barcode instead.',
                  onRetry: _enterManually,
                ),
              ),
            ),
          ),
          // Viewfinder
          IgnorePointer(
            child: Center(
              child: SizedBox(
                width: 280,
                height: 180,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: Radii.mdAll,
                      ),
                    ),
                    if (!reduce && _state == _ScanState.scanning)
                      Container(
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: Space.md),
                            decoration: BoxDecoration(
                              color: BrandColors.emeraldLight,
                              boxShadow: [
                                BoxShadow(color: BrandColors.emeraldLight.withValues(alpha: 0.8), blurRadius: 12),
                              ],
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveY(begin: 12, end: 166, duration: 1400.ms, curve: Curves.easeInOut),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: AnimatedSwitcher(
                  duration: AppDurations.medium,
                  child: KeyedSubtree(key: ValueKey(_state), child: _panel()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel() {
    return switch (_state) {
      _ScanState.scanning => Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(Radii.pill)),
        child: const Text('Line up the barcode inside the frame', style: TextStyle(color: Colors.white)),
      ),
      _ScanState.looking => AppCard(
        child: Row(
          children: [
            const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: Space.md),
            Expanded(child: Text('Looking up $_code…', style: context.text.titleSmall)),
          ],
        ),
      ),
      _ScanState.notFound || _ScanState.error => AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _state == _ScanState.notFound ? 'Product not found' : 'Lookup failed',
              style: context.text.titleMedium,
            ),
            const SizedBox(height: Space.xxs),
            Text(_message ?? '', style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            const SizedBox(height: Space.md),
            // Stacked full-width buttons survive large system font sizes.
            if (_identifying)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Space.sm),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              FilledButton.icon(
                onPressed: () => _identify(withPhotos: true),
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Snap the nutrition label'),
              ),
              if (_productName != null) ...[
                const SizedBox(height: Space.xs),
                OutlinedButton.icon(
                  onPressed: () => _identify(withPhotos: false),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Estimate it for me'),
                ),
              ],
              const SizedBox(height: Space.xs),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => context.pushReplacement('/foods/new?barcode=$_code'),
                      child: const Text('Type it in'),
                    ),
                  ),
                  Expanded(
                    child: TextButton(onPressed: _rescan, child: const Text('Scan again')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    };
  }
}
