import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/date_x.dart';
import '../../domain/entities/food.dart';
import '../providers/food_providers.dart';
import 'common.dart';

/// Draggable sheet to pick a food from the database (used for add & swap).
Future<Food?> showFoodPickerSheet(BuildContext context, {String title = 'Choose a food', String initialQuery = ''}) {
  return showModalBottomSheet<Food>(
    context: context,
    sheetAnimationStyle: kSheetAnimation,
    useRootNavigator: true, // open above the floating nav bar
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, controller) => _FoodPicker(title: title, initialQuery: initialQuery, controller: controller),
    ),
  );
}

class _FoodPicker extends ConsumerStatefulWidget {
  const _FoodPicker({required this.title, required this.initialQuery, required this.controller});
  final String title;
  final String initialQuery;
  final ScrollController controller;

  @override
  ConsumerState<_FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends ConsumerState<_FoodPicker> {
  late final _ctrl = TextEditingController(text: widget.initialQuery);
  late String _query = widget.initialQuery;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(foodSearchProvider(_query));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: context.text.titleLarge),
              const SizedBox(height: Space.sm),
              TextField(
                controller: _ctrl,
                autofocus: widget.initialQuery.isEmpty,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search foods',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() {
                            _ctrl.clear();
                            _query = '';
                          }),
                        ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? ListView(
                  controller: widget.controller,
                  children: const [
                    EmptyState(
                      compact: true,
                      emoji: '🔍',
                      title: 'No matches',
                      message: 'Try a simpler word, or add it as a custom food.',
                    ),
                  ],
                )
              : ListView.builder(
                  controller: widget.controller,
                  padding: const EdgeInsets.fromLTRB(Space.sm, 0, Space.sm, Space.xl),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final f = results[i];
                    return ListTile(
                      leading: EmojiAvatar(emoji: f.emoji, size: 40),
                      title: Text(f.name),
                      subtitle: Text([if (f.brand != null) f.brand!, f.servingLabel].join(' · ')),
                      trailing: Text('${formatKcal(f.macros.kcal)} kcal', style: context.text.labelLarge),
                      onTap: () => Navigator.pop(context, f),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
