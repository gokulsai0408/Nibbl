// Renders every main screen at phone size, in light and dark mode, at normal
// and large system text sizes, and fails on any layout overflow.
//
// The test font draws every glyph as a full-width square, so text here is
// wider than on a real device: passing this is a stricter bar than the phone.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkcast/core/config/app_config.dart';
import 'package:forkcast/core/theme/app_theme.dart';
import 'package:forkcast/core/utils/date_x.dart';
import 'package:forkcast/data/local/hive_store.dart';
import 'package:forkcast/data/repositories/hive_repositories.dart';
import 'package:forkcast/data/seed/food_seed.dart';
import 'package:forkcast/domain/entities/food_log.dart';
import 'package:forkcast/domain/entities/kitchen.dart';
import 'package:forkcast/domain/entities/macros.dart';
import 'package:forkcast/domain/entities/user_profile.dart';
import 'package:forkcast/domain/services/nutrition_calculator.dart';
import 'package:forkcast/presentation/providers/core_providers.dart';
import 'package:forkcast/presentation/screens/coach/coach_screen.dart';
import 'package:forkcast/presentation/screens/foods/foods_screen.dart';
import 'package:forkcast/presentation/screens/home/home_screen.dart';
import 'package:forkcast/presentation/screens/kitchen/kitchen_screen.dart';
import 'package:forkcast/presentation/screens/kitchen/recipe_screen.dart';
import 'package:forkcast/presentation/screens/mochi/mochi_screen.dart';
import 'package:forkcast/presentation/screens/social/compose_post_screen.dart';
import 'package:forkcast/presentation/screens/social/compose_story_screen.dart';
import 'package:forkcast/presentation/screens/social/friends_screen.dart';
import 'package:forkcast/presentation/screens/social/social_screen.dart';
import 'package:forkcast/presentation/screens/log/log_composer_screen.dart';
import 'package:forkcast/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:forkcast/presentation/screens/progress/progress_screen.dart';
import 'package:forkcast/presentation/screens/settings/edit_goals_screen.dart';
import 'package:forkcast/presentation/screens/settings/settings_screen.dart';
import 'package:forkcast/presentation/screens/shell/main_shell.dart';
import 'package:forkcast/presentation/widgets/brand_backdrop.dart';
import 'package:hive/hive.dart';

const _config = AppConfig(
  aiBaseUrl: '',
  aiApiKey: '',
  aiModel: 'demo',
  aiVisionModel: 'demo',
  useMockAi: true,
  provider: AiProvider.openai,
);

final _sampleRecipe = Recipe(
  id: 'sample',
  title: 'Paneer bhurji with a very long descriptive name for wrapping',
  emoji: '🧀',
  summary: 'Scrambled paneer with onion and tomato: high protein, very quick.',
  minutes: 15,
  servings: 2,
  difficulty: 'Easy',
  ingredients: const [
    RecipeIngredient(name: 'Paneer, crumbled', amount: '200 g'),
    RecipeIngredient(name: 'Salt, turmeric and red chilli powder', amount: 'a pinch each, to taste', fromPantry: false),
  ],
  steps: const [
    RecipeStep(title: 'Sauté onions until soft and golden', detail: 'Heat oil on medium. Add onions and cook 3 minutes.', minutes: 3),
    RecipeStep(title: 'Add paneer', detail: 'Stir in the paneer and cook 2 minutes on low heat.', minutes: 2),
  ],
  tips: const ['Use low-fat paneer to save about 80 kcal.'],
  perServing: const Macros(kcal: 330, protein: 19, carbs: 9, fat: 24),
  gramsPerServing: 200,
  createdAt: DateTime(2026),
);

Future<void> _seed() async {
  var profile = UserProfile(
    name: 'Gokulsai Venkataramanan',
    goal: Goal.lose,
    sex: Sex.male,
    age: 27,
    heightCm: 176,
    weightKg: 78.5,
    activity: ActivityLevel.moderate,
    targetWeightKg: 72,
    paceKgPerWeek: 0.5,
    targets: const NutritionTargets(calories: 2000, protein: 150, carbs: 200, fat: 60),
    customTargets: false,
    createdAt: DateTime(2026, 10, 1),
  );
  profile = profile.copyWith(targets: NutritionCalculator.forProfile(profile));
  await HiveProfileRepository(HiveStore.box(HiveStore.profile)).save(profile);

  final today = DateTime.now().dayKey;
  final egg = builtInFoods.firstWhere((f) => f.id == 'egg');
  final bowl = builtInFoods.firstWhere((f) => f.id == 'poke_bowl');
  final logs = [
    FoodLog(
      id: 'a',
      dayKey: today,
      meal: MealType.breakfast,
      food: LoggedFood.fromFood(egg, multiplier: 2),
      source: LogSource.text,
      createdAt: DateTime.now(),
    ),
    FoodLog(
      id: 'b',
      dayKey: today,
      meal: MealType.lunch,
      food: LoggedFood.fromFood(bowl).copyWith(name: 'Extra large salmon poke bowl with avocado, edamame and spicy mayo'),
      source: LogSource.photo,
      createdAt: DateTime.now(),
    ),
  ];
  await HiveLogRepository(HiveStore.box(HiveStore.logs)).upsertAll(logs);
  final pantry = HiveStore.box(HiveStore.pantry);
  for (final (i, name) in ['Eggs', 'Onions', 'Tomatoes', 'Paneer', 'Green chillies', 'Basmati rice'].indexed) {
    final item = PantryItem(id: 'p$i', name: name, emoji: '🥚', addedAt: DateTime(2026, 1, 1, 0, i));
    await pantry.put(item.id, jsonEncode(item.toJson()));
  }
}

void main() {
  setUpAll(() async {
    AppTheme.useGoogleFonts = false;
    final dir = await Directory.systemTemp.createTemp('forkcast_layout');
    Hive.init(dir.path);
    for (final name in HiveStore.allBoxes) {
      await Hive.openBox<String>(name);
    }
    await _seed();
  });

  final tabScreens = <String, (Widget, int)>{
    'Home': (const HomeScreen(), 0),
    'Progress': (const ProgressScreen(), 1),
    'Coach': (const CoachScreen(), 2),
    'Settings': (const SettingsScreen(), 3),
  };
  final fullScreens = <String, Widget>{
    'Onboarding': const OnboardingScreen(),
    'Foods': const FoodsScreen(),
    'Log text': const LogComposerScreen(mode: LogMode.text),
    'Log photo': const LogComposerScreen(mode: LogMode.photo),
    'Edit goals': const EditGoalsScreen(),
    'Kitchen': const KitchenScreen(),
    'Mochi': const MochiScreen(),
    'Recipe': RecipeScreen.saved(recipe: _sampleRecipe),
    'Social setup': const SocialScreen(),
    'Friends': const FriendsScreen(),
    'Compose post': const ComposePostScreen(),
    'Compose story': const ComposeStoryScreen(),
  };

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final scale in [1.0, 1.35, 1.6]) {
      final all = <String, Widget Function()>{
        for (final e in tabScreens.entries)
          e.key: () => Scaffold(
                extendBody: true,
                backgroundColor: Colors.transparent,
                body: BrandBackdrop(child: e.value.$1),
                bottomNavigationBar: AppBottomNav(currentIndex: e.value.$2, onSelect: (_) {}),
              ),
        for (final e in fullScreens.entries) e.key: () => e.value,
      };

      for (final entry in all.entries) {
        testWidgets('${entry.key} · ${mode.name} · text ${scale}x', (tester) async {
          tester.view.physicalSize = const Size(1080, 2340); // 360 x 780 logical
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);

          final problems = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) {
            if (Platform.environment["LAYOUT_DEBUG"] != null) previous?.call(details);
            final where = details
                .toString()
                .split('\n')
                .where((l) => l.contains('lib/') || l.contains('lib\\'))
                .take(2)
                .map((l) => l.trim())
                .join(' | ');
            problems.add('${details.exceptionAsString().split('\n').first}  ->  $where');
          };

          await tester.pumpWidget(
            ProviderScope(
              overrides: [appConfigProvider.overrideWithValue(_config)],
              child: MaterialApp(
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: mode,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: entry.value(),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pump(const Duration(seconds: 1));

          // Tear down so timers (blinks, animations) are cancelled.
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 6));
          FlutterError.onError = previous;

          expect(problems, isEmpty, reason: problems.toSet().join('\n'));
        });
      }
    }
  }
}
