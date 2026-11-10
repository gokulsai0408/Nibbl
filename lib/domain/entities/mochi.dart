/// Mochi's wardrobe and growth, earned by using the app consistently.
library;

enum MochiSlot { head, face, neck }

/// Accessories, unlocked by level. Order = unlock order.
enum MochiItem {
  scarf('Cozy scarf', '🧣', MochiSlot.neck, 2, 'A warm red scarf for chilly mornings.'),
  glasses('Smart glasses', '👓', MochiSlot.face, 3, 'For reading nutrition labels.'),
  chefHat('Chef hat', '👨‍🍳', MochiSlot.head, 4, 'Mochi is ready to cook with you.'),
  bow('Ribbon bow', '🎀', MochiSlot.head, 5, 'Cute and a little bit fancy.'),
  headphones('Headphones', '🎧', MochiSlot.head, 6, 'Cooking playlist on.'),
  sunglasses('Sunglasses', '🕶️', MochiSlot.face, 7, 'Too cool for junk food.'),
  bowtie('Bow tie', '🎩', MochiSlot.neck, 8, 'Dressed up for date night.'),
  partyHat('Party hat', '🥳', MochiSlot.head, 9, 'Every streak deserves a party.'),
  crown('Golden crown', '👑', MochiSlot.head, 10, 'Royalty of healthy habits.');

  const MochiItem(this.label, this.emoji, this.slot, this.unlockLevel, this.blurb);
  final String label;
  final String emoji;
  final MochiSlot slot;
  final int unlockLevel;
  final String blurb;

  /// Head items that hide Mochi's sprout.
  bool get coversSprout => this == chefHat || this == partyHat || this == crown;

  static MochiItem? byName(String name) => values.asNameMap()[name];
}

/// How Mochi's sprout looks as it grows.
enum MochiStage {
  sprout('Sprout', 1),
  sapling('Sapling', 3),
  bud('Bud', 5),
  bloom('Blossom', 8);

  const MochiStage(this.label, this.fromLevel);
  final String label;
  final int fromLevel;

  static MochiStage forLevel(int level) =>
      values.lastWhere((s) => level >= s.fromLevel, orElse: () => MochiStage.sprout);
}

class MochiProgress {
  const MochiProgress({
    required this.xp,
    required this.level,
    required this.levelStartXp,
    required this.nextLevelXp,
    required this.daysLogged,
    required this.goalDays,
    required this.waterDays,
  });

  /// XP needed to *reach* each level (index 0 = level 1).
  static const thresholds = [0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200, 4000, 5000];
  static int get maxLevel => thresholds.length;

  final int xp;
  final int level;
  final int levelStartXp;

  /// Null at max level.
  final int? nextLevelXp;
  final int daysLogged;
  final int goalDays;
  final int waterDays;

  MochiStage get stage => MochiStage.forLevel(level);

  double get levelProgress {
    final next = nextLevelXp;
    if (next == null) return 1;
    return ((xp - levelStartXp) / (next - levelStartXp)).clamp(0.0, 1.0);
  }

  bool isUnlocked(MochiItem item) => level >= item.unlockLevel;

  static MochiProgress fromXp(int xp, {int daysLogged = 0, int goalDays = 0, int waterDays = 0}) {
    var level = 1;
    for (var i = 0; i < thresholds.length; i++) {
      if (xp >= thresholds[i]) level = i + 1;
    }
    return MochiProgress(
      xp: xp,
      level: level,
      levelStartXp: thresholds[level - 1],
      nextLevelXp: level < thresholds.length ? thresholds[level] : null,
      daysLogged: daysLogged,
      goalDays: goalDays,
      waterDays: waterDays,
    );
  }
}

/// How XP is earned, shown in the wardrobe.
const mochiXpRules = <(String, String, int)>[
  ('📒', 'Log food on a day', 10),
  ('🍽️', 'Each food logged (up to 5 a day)', 2),
  ('🎯', 'Finish a day within 10% of your calorie goal', 15),
  ('💧', 'Hit your water goal', 5),
  ('🔥', 'Every 7-day logging streak', 30),
];
