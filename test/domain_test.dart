import 'package:flutter_test/flutter_test.dart';
import 'package:forkcast/data/ai/ai_json_parser.dart';
import 'package:forkcast/data/ai/mock_ai_service.dart';
import 'package:forkcast/data/ai/label_prompt.dart';
import 'package:forkcast/data/ai/recipe_prompt.dart';
import 'package:forkcast/data/remote/open_food_facts_api.dart';
import 'package:forkcast/data/social/demo_social_backend.dart';
import 'package:forkcast/domain/entities/social.dart';
import 'package:forkcast/domain/entities/kitchen.dart';
import 'package:forkcast/domain/entities/drink.dart';
import 'package:forkcast/domain/entities/mochi.dart';
import 'package:forkcast/domain/entities/tracking.dart';
import 'package:forkcast/domain/services/ingredient_matcher.dart';
import 'package:forkcast/domain/entities/user_profile.dart';
import 'package:forkcast/domain/services/nutrition_calculator.dart';

void main() {
  group('Kitchen', () {
    test('parses a recipe and derives missing calories from macros', () {
      final r = RecipePrompts.parseRecipe(
        '{"title":"Egg bhurji","emoji":"🍳","summary":"Quick","minutes":10,"servings":2,"difficulty":"Easy",'
        '"ingredients":[{"name":"Eggs","amount":"4","fromPantry":true}],'
        '"steps":[{"title":"Cook","detail":"Scramble","minutes":5}],"tips":["Add chilli"],'
        '"calories":0,"protein":12,"carbs":4,"fat":10,"gramsPerServing":150}',
      );
      expect(r.title, 'Egg bhurji');
      expect(r.steps, hasLength(1));
      expect(r.perServing.kcal, 12 * 4 + 4 * 4 + 10 * 9);
      expect(r.toLoggedFood(servings: 2).macros.protein, 24);
    });

    test('demo AI suggests a recipe using the pantry and avoids repeats', () async {
      final ai = MockAiService();
      const req = RecipeRequest(pantry: ['Eggs', 'Onion', 'Tomato']);
      final first = await ai.suggestRecipe(req);
      expect(first.steps, isNotEmpty);
      final second = await ai.suggestRecipe(req.copyWith(avoid: [first.title]));
      expect(second.title, isNot(first.title));
    });
  });

  group('Social', () {
    test('username rules', () {
      expect(validateUsername('ab'), isNotNull);
      expect(validateUsername('Gokul Sai'), isNotNull);
      expect(validateUsername('gokul.sai_8'), isNull);
    });

    test('friends, feed visibility, reactions and comments', () async {
      final b = DemoSocialBackend();
      expect(await b.myProfile(), isNull);
      expect(await b.isUsernameAvailable('ananya.eats'), isFalse);
      final me = await b.saveProfile(username: 'gokul', displayName: 'Gokul', emoji: '😎');
      expect(me.handle, '@gokul');

      // Rahul asked me; sending back accepts it.
      final rahul = (await b.search('rahul')).single;
      expect(await b.sendRequest(rahul.id), RequestResult.accepted);
      final kiran = (await b.search('kir')).single;
      expect(await b.sendRequest(kiran.id), RequestResult.sent);
      expect(await b.sendRequest(kiran.id), RequestResult.alreadySent);

      // Only friends' posts (Priya, Ananya) are in the feed.
      final feed = await b.feed();
      expect(feed.map((p) => p.author.username), everyElement(isIn(['priya.cooks', 'ananya.eats', 'gokul'])));

      final post = await b.createPost(const NewPost(caption: 'Dal tadka tonight', dishName: 'Dal tadka', kcal: 320));
      expect((await b.feed()).first.id, post.id);

      // Reacting twice with the same emoji removes it.
      final p1 = feed.firstWhere((p) => p.id == 'p1');
      final after = p1.withMyReaction('🔥');
      expect(after.reactions['🔥'], (p1.reactions['🔥'] ?? 0) + 1);
      expect(after.withMyReaction(null).reactions['🔥'], p1.reactions['🔥']);

      final c = await b.addComment('p1', 'Making this tomorrow!');
      expect((await b.comments('p1')).last.body, c.body);
    });
  });

  group('Challenges', () {
    test('day maths, streak and completion', () {
      final today = DateTime(2026, 11, 10);
      final c = Challenge(
        id: 'c',
        creator: const SocialProfile(id: 'u', username: 'u', displayName: 'U'),
        title: 'Steps',
        emoji: '🚶',
        days: 7,
        startsOn: DateTime(2026, 11, 6),
        today: today,
        joined: true,
        myDays: {DateTime(2026, 11, 6), DateTime(2026, 11, 8), DateTime(2026, 11, 9), DateTime(2026, 11, 10)},
      );
      expect(c.dayNumber, 5);
      expect(c.daysLeft, 3);
      expect(c.isActive, isTrue);
      expect(c.checkedToday, isTrue);
      expect(c.myStreak, 3);
      expect(c.completed, isFalse);
    });

    test('create, join, check in and leave (demo)', () async {
      final b = DemoSocialBackend();
      await b.saveProfile(username: 'gokul', displayName: 'Gokul', emoji: '😎');
      final open = (await b.challenges()).single;
      expect(open.joined, isFalse);
      await b.joinChallenge(open.id);
      await b.checkIn(open.id, done: true);
      var c = (await b.challenges()).single;
      expect(c.checkedToday, isTrue);
      expect(c.members.any((m) => m.profile.id == 'me' && m.checkedToday), isTrue);
      await b.leaveChallenge(open.id);
      c = (await b.challenges()).single;
      expect(c.joined, isFalse);

      await b.createChallenge(title: 'Read 20 pages', emoji: '📚', days: 14);
      expect((await b.challenges()).first.title, 'Read 20 pages');
    });

    test('proof check-in statuses', () {
      final d1 = DateTime(2026, 11, 8), d2 = DateTime(2026, 11, 9), d3 = DateTime(2026, 11, 10);
      final c = Challenge(
        id: 'c',
        creator: const SocialProfile(id: 'u', username: 'u', displayName: 'U'),
        title: 'Steps',
        emoji: '🚶',
        days: 7,
        startsOn: DateTime(2026, 11, 6),
        today: d3,
        joined: true,
        myDays: {d1, d2, d3},
        myVotes: {d1: (2, 0), d2: (0, 1)},
      );
      expect(c.statusOf(d1), CheckinStatus.verified);
      expect(c.statusOf(d2), CheckinStatus.rejected);
      expect(c.statusOf(d3), CheckinStatus.pending);
      expect(c.statusOf(DateTime(2026, 11, 7)), CheckinStatus.none);
    });

    test('friends review proofs once (demo)', () async {
      final b = DemoSocialBackend();
      await b.saveProfile(username: 'gokul', displayName: 'Gokul', emoji: '😎');
      final c = (await b.challenges()).single;
      await b.joinChallenge(c.id);
      final queue = await b.checkinsToReview(c.id);
      expect(queue, isNotEmpty);
      await b.voteCheckin(queue.first, approve: true);
      expect((await b.checkinsToReview(c.id)).length, queue.length - 1);
    });

    test('workout summary and categories', () {
      const a = PostActivity(type: 'Run', minutes: 31, distanceKm: 5.2, kcal: 340);
      expect(a.summary, 'Run · 31 min · 5.2 km · 340 kcal burned');
      expect(PostActivity.fromJson(a.toJson()).distanceKm, 5.2);
      expect(PostCategory.cardio.hasActivity, isTrue);
      expect(PostCategory.sleep.hasActivity, isFalse);
    });
  });

  test('saved bottles survive settings save/load', () {
    const s = AppSettings(savedBottles: [SavedBottle(id: 'b1', name: 'Steel bottle', emoji: '🧴', ml: 1000)]);
    final back = AppSettings.fromJson(s.toJson());
    expect(back.savedBottles.single.name, 'Steel bottle');
    expect(back.savedBottles.single.ml, 1000);
  });

  group('Stories', () {
    test('groups by person: me first, then unseen, then seen', () async {
      final b = DemoSocialBackend();
      await b.saveProfile(username: 'gokul', displayName: 'Gokul', emoji: '😎');
      await b.createStory(const NewStory(kind: StoryKind.progress, caption: 'Day 1'));
      var groups = groupStories(await b.stories(), 'me');
      expect(groups.first.author.id, 'me');
      expect(groups.map((g) => g.author.username), containsAll(['priya.cooks', 'ananya.eats']));

      // Watching all of Priya's stories moves her after unseen ones.
      final priya = groups.firstWhere((g) => g.author.username == 'priya.cooks');
      for (final s in priya.stories) {
        await b.viewStory(s.id);
      }
      groups = groupStories(await b.stories(), 'me');
      expect(groups.last.author.username, 'priya.cooks');
      expect(groups.last.allViewed, isTrue);
    });

    test('progress goals', () {
      const p = StoryProgress(
        kcal: 1950, kcalGoal: 2000, protein: 130, proteinGoal: 120, waterMl: 1000, waterGoalMl: 2500,
        streak: 3, mochiLevel: 2,
      );
      expect(p.calorieGoalHit, isTrue);
      expect(p.proteinGoalHit, isTrue);
      expect(p.waterGoalHit, isFalse);
      expect(StoryProgress.fromJson(p.toJson()).protein, 130);
    });
  });

  group('Barcodes', () {
    test('tries every spelling of a code', () {
      expect(barcodeVariants('012345678905'), containsAll(['012345678905', '0012345678905', '12345678905']));

      expect(barcodeVariants('01234505'), contains('012000003455')); // UPC-E -> UPC-A
      expect(barcodeVariants('8901063019097'), contains('08901063019097'));
    });

    test('reads a label result into a food', () {
      final (food, fromLabel) = LabelPrompts.parse(
        '{"name":"Aloo Bhujia","brand":"Haldiram","emoji":"🥔","serving":"1 pack (30 g)","servingGrams":30,'
        '"calories":0,"protein":3,"carbs":12,"fat":11,"fromLabel":true}',
        barcode: '8904063',
      );
      expect(food.id, 'off_8904063');
      expect(food.macros.kcal, 3 * 4 + 12 * 4 + 11 * 9);
      expect(fromLabel, isTrue);
    });
  });

  group('Ingredients', () {
    test('parses amounts in either position', () {
      expect(parseIngredient('4 eggs'), ('Eggs', '4'));
      expect(parseIngredient('500g rice'), ('Rice', '500 g'));
      expect(parseIngredient('paneer 200 g'), ('Paneer', '200 g'));
      expect(parseIngredient('Eggs x6'), ('Eggs', '6'));
      expect(parseIngredient('onion'), ('Onion', ''));
    });

    test('flags recipe ingredients the user does not have', () {
      const pantry = ['Eggs (4)', 'Onions', 'Tomatoes', 'Aloo'];
      final missing = missingIngredients(
        ['Eggs, beaten', 'Onion, finely chopped', 'Potato, cubed', 'Salt to taste', 'Oil', 'Red chilli powder', 'Paneer'],
        pantry,
      );
      expect(missing, ['Paneer']);
      expect(missingIngredients(['Oil'], pantry, allowBasics: false), ['Oil']);
    });
  });

  group('Mochi', () {
    test('levels follow XP thresholds', () {
      expect(MochiProgress.fromXp(0).level, 1);
      expect(MochiProgress.fromXp(99).level, 1);
      expect(MochiProgress.fromXp(100).level, 2);
      expect(MochiProgress.fromXp(460).level, 4);
      expect(MochiProgress.fromXp(999999).nextLevelXp, isNull);
      expect(MochiProgress.fromXp(175).levelProgress, closeTo(0.5, 0.001));
    });

    test('growth stages and unlocks', () {
      expect(MochiStage.forLevel(1), MochiStage.sprout);
      expect(MochiStage.forLevel(5), MochiStage.bud);
      expect(MochiProgress.fromXp(450).isUnlocked(MochiItem.chefHat), isTrue);
      expect(MochiProgress.fromXp(450).isUnlocked(MochiItem.crown), isFalse);
    });
  });

  group('NutritionCalculator', () {
    test('Mifflin-St Jeor BMR matches the published formula', () {
      // 10*80 + 6.25*180 - 5*30 + 5 = 1780
      expect(NutritionCalculator.bmr(sex: Sex.male, weightKg: 80, heightCm: 180, age: 30), 1780);
      // 10*60 + 6.25*165 - 5*28 - 161 = 1330.25
      expect(NutritionCalculator.bmr(sex: Sex.female, weightKg: 60, heightCm: 165, age: 28), closeTo(1330.25, 0.01));
    });

    test('weight loss creates a deficit and respects the safety floor', () {
      final maintain = NutritionCalculator.compute(
        goal: Goal.maintain, sex: Sex.male, age: 30, heightCm: 180, weightKg: 80,
        activity: ActivityLevel.moderate, paceKgPerWeek: 0,
      );
      final lose = NutritionCalculator.compute(
        goal: Goal.lose, sex: Sex.male, age: 30, heightCm: 180, weightKg: 80,
        activity: ActivityLevel.moderate, paceKgPerWeek: 0.5,
      );
      expect(maintain.calories, closeTo(1780 * 1.55, 10));
      expect(maintain.calories - lose.calories, closeTo(550, 10));

      final tiny = NutritionCalculator.compute(
        goal: Goal.lose, sex: Sex.female, age: 70, heightCm: 145, weightKg: 40,
        activity: ActivityLevel.sedentary, paceKgPerWeek: 1,
      );
      expect(tiny.calories, greaterThanOrEqualTo(1200));
    });

    test('macros roughly add up to calories', () {
      final t = NutritionCalculator.compute(
        goal: Goal.gain, sex: Sex.female, age: 25, heightCm: 170, weightKg: 62,
        activity: ActivityLevel.active, paceKgPerWeek: 0.25,
      );
      final fromMacros = NutritionCalculator.kcalFromMacros(t.protein, t.carbs, t.fat);
      expect((fromMacros - t.calories).abs(), lessThan(t.calories * 0.03));
    });
  });

  group('AI parsing', () {
    test('mock parser itemizes a natural sentence', () async {
      final items = await MockAiService().parseText('2 eggs, toast with butter and a coffee with milk');
      final names = items.map((i) => i.name.toLowerCase()).toList();
      expect(items.length, 5);
      expect(names.first, contains('egg'));
      expect(items.first.multiplier, 2);
      expect(names.any((n) => n.contains('toast')), isTrue);
      expect(names.any((n) => n.contains('butter')), isTrue);
      expect(names.any((n) => n.contains('coffee')), isTrue);
    });

    test('json parser tolerates code fences and alternate keys', () {
      const raw = '```json\n{"foods":[{"food":"apple","kcal":"95","protein_g":0.5,"carbs":25,"fat":0.3,"grams":182}]}\n```';
      final items = AiJsonParser.parseItems(raw);
      expect(items.single.name, 'Apple');
      expect(items.single.macros.kcal, 95);
      expect(items.single.servingGrams, 182);
    });
  });
}
