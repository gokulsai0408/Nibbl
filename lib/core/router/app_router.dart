import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/food.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/entities/kitchen.dart';
import '../../domain/entities/social.dart';
import '../theme/tokens.dart';
import '../../presentation/providers/profile_settings_providers.dart';
import '../../presentation/screens/coach/coach_screen.dart';
import '../../presentation/screens/foods/barcode_screen.dart';
import '../../presentation/screens/foods/custom_food_screen.dart';
import '../../presentation/screens/foods/food_detail_screen.dart';
import '../../presentation/screens/foods/foods_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/kitchen/kitchen_screen.dart';
import '../../presentation/screens/mochi/mochi_screen.dart';
import '../../presentation/screens/log/log_composer_screen.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/progress/progress_screen.dart';
import '../../presentation/screens/settings/edit_goals_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/shell/main_shell.dart';
import '../../presentation/screens/social/compose_post_screen.dart';
import '../../presentation/screens/social/compose_story_screen.dart';
import '../../presentation/screens/social/friends_screen.dart';
import '../../presentation/screens/social/profile_screen.dart';
import '../../presentation/screens/social/social_screen.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Slide-up + fade, used for full-screen logging flows.
CustomTransitionPage<void> _modalPage(GoRouterState state, Widget child) => CustomTransitionPage<void>(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 340),
  reverseTransitionDuration: const Duration(milliseconds: 240),
  transitionsBuilder: (context, animation, secondary, child) {
    if (MediaQuery.disableAnimationsOf(context)) return FadeTransition(opacity: animation, child: child);
    final curved = CurvedAnimation(parent: animation, curve: AppCurves.drawer, reverseCurve: Curves.easeInCubic);
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
      reverseCurve: const Interval(0.3, 1, curve: Curves.easeIn),
    );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(curved),
        child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child),
      ),
    );
  },
);

MealType? _meal(GoRouterState s) => MealType.tryParse(s.uri.queryParameters['meal']);

final routerProvider = Provider<GoRouter>((ref) {
  final onboardedListenable = ValueNotifier<bool>(ref.read(profileProvider) != null);
  ref.listen(profileProvider.select((p) => p != null), (prev, next) => onboardedListenable.value = next);
  ref.onDispose(onboardedListenable.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    refreshListenable: onboardedListenable,
    redirect: (context, state) {
      final onboarded = onboardedListenable.value;
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!onboarded && !atOnboarding) return '/onboarding';
      if (onboarded && atOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      StatefulShellRoute(
        builder: (context, state, shell) => MainShell(shell: shell),
        navigatorContainerBuilder: (context, shell, children) =>
            AnimatedBranchContainer(currentIndex: shell.currentIndex, children: children),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (c, s) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/progress', builder: (c, s) => const ProgressScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/coach', builder: (c, s) => const CoachScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/log/:mode',
        pageBuilder: (context, state) => _modalPage(
          state,
          LogComposerScreen(
            mode: LogMode.values.asNameMap()[state.pathParameters['mode']] ?? LogMode.text,
            initialMeal: _meal(state),
          ),
        ),
      ),
      GoRoute(
        path: '/barcode',
        pageBuilder: (context, state) => _modalPage(state, BarcodeScreen(initialMeal: _meal(state))),
      ),
      GoRoute(
        path: '/foods',
        pageBuilder: (context, state) => _modalPage(
          state,
          FoodsScreen(initialMeal: _meal(state), initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0),
        ),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) {
              final extra = state.extra;
              final (initial, fromLabel) = extra is (Food, bool) ? extra : (null, false);
              return CustomFoodScreen(
                barcode: state.uri.queryParameters['barcode'],
                initial: initial,
                fromLabel: fromLabel,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/food/:id',
        builder: (context, state) => FoodDetailScreen(foodId: state.pathParameters['id']!, initialMeal: _meal(state)),
      ),
      GoRoute(path: '/goals', builder: (context, state) => const EditGoalsScreen()),
      GoRoute(path: '/kitchen', pageBuilder: (context, state) => _modalPage(state, const KitchenScreen())),
      GoRoute(path: '/mochi', builder: (context, state) => const MochiScreen()),
      GoRoute(
        path: '/social',
        builder: (context, state) => const SocialScreen(),
        routes: [
          GoRoute(path: 'friends', builder: (context, state) => const FriendsScreen()),
          GoRoute(path: 'story', pageBuilder: (context, state) => _modalPage(state, const ComposeStoryScreen())),
          GoRoute(
            path: 'new',
            pageBuilder: (context, state) =>
                _modalPage(state, ComposePostScreen(recipe: state.extra is Recipe ? state.extra! as Recipe : null)),
          ),
          GoRoute(
            path: 'u/:id',
            builder: (context, state) => SocialProfileScreen(
              userId: state.pathParameters['id']!,
              initial: state.extra is SocialProfile ? state.extra! as SocialProfile : null,
            ),
          ),
        ],
      ),
    ],
  );
});
