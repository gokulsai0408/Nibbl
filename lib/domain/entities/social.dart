import 'kitchen.dart';

/// A person on Nibbl.
class SocialProfile {
  const SocialProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarEmoji = '🙂',
    this.mochiLevel = 1,
    this.streak = 0,
    this.avatarUrl,
    this.bio = '',
  });

  final String id;
  final String username;
  final String displayName;
  final String avatarEmoji;
  final int mochiLevel;
  final int streak;

  /// Uploaded profile photo (falls back to [avatarEmoji]).
  final String? avatarUrl;
  final String bio;

  String get handle => '@$username';

  factory SocialProfile.fromJson(Map<String, dynamic> j) => SocialProfile(
    id: j['id'] as String,
    username: j['username'] as String? ?? '',
    displayName: j['display_name'] as String? ?? j['username'] as String? ?? '',
    avatarEmoji: j['avatar_emoji'] as String? ?? '🙂',
    mochiLevel: (j['mochi_level'] as num? ?? 1).round(),
    streak: (j['streak'] as num? ?? 0).round(),
    avatarUrl: (j['avatar_url'] as String?)?.isNotEmpty == true ? j['avatar_url'] as String : null,
    bio: j['bio'] as String? ?? '',
  );

  SocialProfile copyWith({
    String? username,
    String? displayName,
    String? avatarEmoji,
    int? mochiLevel,
    int? streak,
    String? bio,
    String? avatarUrl,
    bool clearAvatar = false,
  }) => SocialProfile(
    id: id,
    username: username ?? this.username,
    displayName: displayName ?? this.displayName,
    avatarEmoji: avatarEmoji ?? this.avatarEmoji,
    mochiLevel: mochiLevel ?? this.mochiLevel,
    streak: streak ?? this.streak,
    bio: bio ?? this.bio,
    avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
  );
}

enum FriendStatus { pending, accepted }

/// A friendship or friend request, seen from my side.
class FriendLink {
  const FriendLink({required this.id, required this.other, required this.status, required this.incoming});

  final int id;
  final SocialProfile other;
  final FriendStatus status;

  /// True when they sent the request to me.
  final bool incoming;

  bool get isFriend => status == FriendStatus.accepted;

  factory FriendLink.fromJson(Map<String, dynamic> j) => FriendLink(
    id: (j['id'] as num).toInt(),
    other: SocialProfile.fromJson(Map<String, dynamic>.from(j['other'] as Map)),
    status: j['status'] == 'accepted' ? FriendStatus.accepted : FriendStatus.pending,
    incoming: j['incoming'] == true,
  );
}

/// Reactions friends can leave on a post.
const postReactions = ['😋', '🔥', '👏', '❤️'];

class Post {
  const Post({
    required this.id,
    required this.author,
    required this.caption,
    required this.createdAt,
    this.photoUrl,
    this.photoPath,
    this.photoBytes,
    this.dishName,
    this.emoji,
    this.kcal,
    this.protein,
    this.recipe,
    this.reactions = const {},
    this.myReaction,
    this.commentCount = 0,
    this.category = PostCategory.food,
    this.activity,
  });

  final String id;
  final SocialProfile author;
  final PostCategory category;

  /// Workout / cardio details.
  final PostActivity? activity;
  final String caption;
  final DateTime createdAt;

  /// Displayable (signed) URL, resolved by the backend.
  final String? photoUrl;
  final String? photoPath;

  /// Local photo (demo mode, or right after posting).
  final List<int>? photoBytes;
  final String? dishName;
  final String? emoji;
  final int? kcal;
  final int? protein;

  /// Attached Mochi recipe, so friends can save and cook it too.
  final Recipe? recipe;
  final Map<String, int> reactions;
  final String? myReaction;
  final int commentCount;

  int get reactionTotal => reactions.values.fold(0, (a, b) => a + b);

  Post copyWith({Map<String, int>? reactions, String? myReaction, bool clearReaction = false, int? commentCount}) =>
      Post(
        id: id,
        author: author,
        caption: caption,
        createdAt: createdAt,
        photoUrl: photoUrl,
        photoPath: photoPath,
        photoBytes: photoBytes,
        dishName: dishName,
        emoji: emoji,
        kcal: kcal,
        protein: protein,
        recipe: recipe,
        reactions: reactions ?? this.reactions,
        myReaction: clearReaction ? null : (myReaction ?? this.myReaction),
        commentCount: commentCount ?? this.commentCount,
        category: category,
        activity: activity,
      );

  /// Applies my reaction locally (optimistic update).
  Post withMyReaction(String? emoji) {
    final counts = Map<String, int>.from(reactions);
    if (myReaction != null) {
      counts[myReaction!] = (counts[myReaction!] ?? 1) - 1;
      if (counts[myReaction!]! <= 0) counts.remove(myReaction);
    }
    if (emoji != null) counts[emoji] = (counts[emoji] ?? 0) + 1;
    return emoji == null
        ? copyWith(reactions: counts, clearReaction: true)
        : copyWith(reactions: counts, myReaction: emoji);
  }

  factory Post.fromJson(Map<String, dynamic> j, {String? photoUrl}) {
    final r = j['recipe'];
    Recipe? recipe;
    if (r is Map) {
      try {
        recipe = Recipe.fromJson(Map<String, dynamic>.from(r));
      } catch (_) {}
    }
    return Post(
      id: j['id'] as String,
      author: SocialProfile.fromJson(Map<String, dynamic>.from(j['author'] as Map)),
      caption: j['caption'] as String? ?? '',
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      photoPath: j['photo_path'] as String?,
      photoUrl: photoUrl,
      dishName: j['dish_name'] as String?,
      emoji: j['emoji'] as String?,
      kcal: (j['kcal'] as num?)?.round(),
      protein: (j['protein'] as num?)?.round(),
      recipe: recipe,
      reactions: {
        for (final e in ((j['reactions'] as Map?) ?? const {}).entries) e.key.toString(): (e.value as num).toInt(),
      },
      myReaction: j['my_reaction'] as String?,
      commentCount: (j['comment_count'] as num? ?? 0).toInt(),
      category: PostCategory.values.asNameMap()[j['category']] ?? PostCategory.food,
      activity: j['activity'] is Map ? PostActivity.fromJson(Map<String, dynamic>.from(j['activity'] as Map)) : null,
    );
  }
}

/// What a post is about: life, not just food.
enum PostCategory {
  food('Food', '🍽️'),
  workout('Workout', '🏋️'),
  cardio('Steps & cardio', '🏃'),
  sleep('Sleep', '😴'),
  mind('Mind', '🧘'),
  milestone('Milestone', '🏆'),
  life('Life', '✨');

  const PostCategory(this.label, this.emoji);
  final String label;
  final String emoji;

  /// Categories that can carry minutes / calories burned.
  bool get hasActivity => this == workout || this == cardio;
}

class PostActivity {
  const PostActivity({required this.type, this.minutes, this.kcal, this.distanceKm, this.steps});
  final String type;
  final int? minutes;
  final int? kcal;
  final double? distanceKm;
  final int? steps;

  String get summary => [
    type,
    if (minutes != null) '$minutes min',
    if (distanceKm != null) '${distanceKm!.toStringAsFixed(distanceKm! < 10 ? 1 : 0)} km',
    if (steps != null) '$steps steps',
    if (kcal != null) '$kcal kcal burned',
  ].join(' · ');

  Map<String, dynamic> toJson() => {
    'type': type,
    if (minutes != null) 'minutes': minutes,
    if (kcal != null) 'kcal': kcal,
    if (distanceKm != null) 'distance_km': distanceKm,
    if (steps != null) 'steps': steps,
  };

  factory PostActivity.fromJson(Map<String, dynamic> j) => PostActivity(
    type: j['type'] as String? ?? 'Workout',
    minutes: (j['minutes'] as num?)?.round(),
    kcal: (j['kcal'] as num?)?.round(),
    distanceKm: (j['distance_km'] as num?)?.toDouble(),
    steps: (j['steps'] as num?)?.round(),
  );
}

class PostComment {
  const PostComment({required this.id, required this.author, required this.body, required this.createdAt});

  final int id;
  final SocialProfile author;
  final String body;
  final DateTime createdAt;

  factory PostComment.fromJson(Map<String, dynamic> j) => PostComment(
    id: (j['id'] as num).toInt(),
    author: SocialProfile.fromJson(Map<String, dynamic>.from(j['author'] as Map)),
    body: j['body'] as String? ?? '',
    createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
  );
}

/// What a new post contains.
class NewPost {
  const NewPost({
    required this.caption,
    this.photo,
    this.dishName,
    this.emoji,
    this.kcal,
    this.protein,
    this.recipe,
    this.category = PostCategory.food,
    this.activity,
  });

  final PostCategory category;
  final PostActivity? activity;
  final String caption;
  final List<int>? photo;
  final String? dishName;
  final String? emoji;
  final int? kcal;
  final int? protein;
  final Recipe? recipe;
}

/// Username rules (must match the database check).
final usernamePattern = RegExp(r'^[a-z0-9_.]{3,20}$');

String? validateUsername(String raw) {
  final u = raw.trim().toLowerCase();
  if (u.length < 3) return 'At least 3 characters';
  if (u.length > 20) return 'At most 20 characters';
  if (!usernamePattern.hasMatch(u)) return 'Use a-z, 0-9, _ or .';
  return null;
}

class SocialException implements Exception {
  const SocialException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Outcome of sending a friend request.
enum RequestResult { sent, accepted, alreadySent, alreadyFriends }

/// The social backend (Supabase in production, an in-memory demo otherwise).
abstract interface class SocialBackend {
  /// False for the offline demo.
  bool get isLive;

  Future<SocialProfile?> myProfile();
  Future<bool> isUsernameAvailable(String username);
  Future<SocialProfile> saveProfile({
    required String username,
    required String displayName,
    required String emoji,
    String bio = '',
    String? avatarUrl,
  });

  /// Uploads a profile photo and returns its URL.
  Future<String> uploadAvatar(List<int> jpeg);
  Future<void> syncStats({required int streak, required int mochiLevel});

  Future<List<SocialProfile>> search(String query);
  Future<List<FriendLink>> friendships();
  Future<RequestResult> sendRequest(String userId);
  Future<void> respond(int linkId, {required bool accept});
  Future<void> removeLink(int linkId);

  Future<List<Post>> feed({DateTime? before});
  Future<List<Post>> postsBy(String userId);
  Future<Post> createPost(NewPost post);
  Future<void> deletePost(Post post);
  Future<void> react(String postId, String? emoji);
  Future<List<PostComment>> comments(String postId);
  Future<PostComment> addComment(String postId, String body);
  Future<void> deleteComment(int commentId);

  Future<List<Story>> stories();
  Future<Story> createStory(NewStory story);
  Future<void> deleteStory(Story story);
  Future<void> viewStory(String storyId, {String? reaction});
  Future<List<StoryViewer>> storyViewers(String storyId);

  Future<List<Challenge>> challenges();
  Future<void> createChallenge({required String title, required String emoji, String description, required int days});
  Future<void> joinChallenge(String id);
  Future<void> leaveChallenge(String id);

  /// Check in with a proof photo (or undo today's check-in).
  Future<void> checkIn(String id, {required bool done, List<int>? photo, String note = ''});

  /// Friends' recent proofs I haven't verified yet.
  Future<List<CheckinReview>> checkinsToReview(String challengeId);
  Future<void> voteCheckin(CheckinReview review, {required bool approve});

  Future<void> signOut();
}

// ---------------------------------------------------------------- stories

/// Quick reactions on a story.
const storyReactions = ['🔥', '😍', '💪', '👏', '😋', '❤️'];

enum StoryKind { photo, progress }

/// Snapshot of a day, turned into a progress-card story.
class StoryProgress {
  const StoryProgress({
    required this.kcal,
    required this.kcalGoal,
    required this.protein,
    required this.proteinGoal,
    required this.waterMl,
    required this.waterGoalMl,
    required this.streak,
    required this.mochiLevel,
    this.outfit = const [],
    this.meals = 0,
  });

  final int kcal;
  final int kcalGoal;
  final int protein;
  final int proteinGoal;
  final int waterMl;
  final int waterGoalMl;
  final int streak;
  final int mochiLevel;

  /// Mochi's accessories when the story was made.
  final List<String> outfit;
  final int meals;

  bool get calorieGoalHit => kcalGoal > 0 && (kcal - kcalGoal).abs() <= kcalGoal * 0.1;
  bool get proteinGoalHit => proteinGoal > 0 && protein >= proteinGoal;
  bool get waterGoalHit => waterGoalMl > 0 && waterMl >= waterGoalMl;

  Map<String, dynamic> toJson() => {
    'kcal': kcal,
    'kcalGoal': kcalGoal,
    'protein': protein,
    'proteinGoal': proteinGoal,
    'waterMl': waterMl,
    'waterGoalMl': waterGoalMl,
    'streak': streak,
    'mochiLevel': mochiLevel,
    'outfit': outfit,
    'meals': meals,
  };

  factory StoryProgress.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num? ?? 0).round();
    return StoryProgress(
      kcal: n('kcal'),
      kcalGoal: n('kcalGoal'),
      protein: n('protein'),
      proteinGoal: n('proteinGoal'),
      waterMl: n('waterMl'),
      waterGoalMl: n('waterGoalMl'),
      streak: n('streak'),
      mochiLevel: n('mochiLevel'),
      outfit: [for (final o in (j['outfit'] as List? ?? const [])) o.toString()],
      meals: n('meals'),
    );
  }
}

class Story {
  const Story({
    required this.id,
    required this.author,
    required this.kind,
    required this.createdAt,
    required this.expiresAt,
    this.caption = '',
    this.photoUrl,
    this.photoPath,
    this.photoBytes,
    this.progress,
    this.recipe,
    this.viewed = false,
    this.viewCount,
  });

  final String id;
  final SocialProfile author;
  final StoryKind kind;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String caption;
  final String? photoUrl;
  final String? photoPath;
  final List<int>? photoBytes;
  final StoryProgress? progress;
  final Recipe? recipe;
  final bool viewed;

  /// Only known for my own stories.
  final int? viewCount;

  Story markViewed() => Story(
    id: id,
    author: author,
    kind: kind,
    createdAt: createdAt,
    expiresAt: expiresAt,
    caption: caption,
    photoUrl: photoUrl,
    photoPath: photoPath,
    photoBytes: photoBytes,
    progress: progress,
    recipe: recipe,
    viewed: true,
    viewCount: viewCount,
  );

  factory Story.fromJson(Map<String, dynamic> j, {String? photoUrl}) {
    Recipe? recipe;
    if (j['recipe'] is Map) {
      try {
        recipe = Recipe.fromJson(Map<String, dynamic>.from(j['recipe'] as Map));
      } catch (_) {}
    }
    final data = j['data'];
    return Story(
      id: j['id'] as String,
      author: SocialProfile.fromJson(Map<String, dynamic>.from(j['author'] as Map)),
      kind: j['kind'] == 'progress' ? StoryKind.progress : StoryKind.photo,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      expiresAt:
          DateTime.tryParse(j['expires_at'] as String? ?? '')?.toLocal() ??
          DateTime.now().add(const Duration(hours: 24)),
      caption: j['caption'] as String? ?? '',
      photoPath: j['photo_path'] as String?,
      photoUrl: photoUrl,
      progress: data is Map ? StoryProgress.fromJson(Map<String, dynamic>.from(data)) : null,
      recipe: recipe,
      viewed: j['viewed'] == true,
      viewCount: (j['view_count'] as num?)?.toInt(),
    );
  }
}

/// All active stories of one person, oldest first.
class StoryGroup {
  const StoryGroup(this.author, this.stories);
  final SocialProfile author;
  final List<Story> stories;

  bool get allViewed => stories.every((s) => s.viewed);

  /// Where to start watching: the first story not yet seen.
  int get firstUnseen {
    final i = stories.indexWhere((s) => !s.viewed);
    return i < 0 ? 0 : i;
  }
}

class NewStory {
  const NewStory({required this.kind, this.caption = '', this.photo, this.progress, this.recipe});
  final StoryKind kind;
  final String caption;
  final List<int>? photo;
  final StoryProgress? progress;
  final Recipe? recipe;
}

class StoryViewer {
  const StoryViewer({required this.viewer, required this.viewedAt, this.reaction});
  final SocialProfile viewer;
  final DateTime viewedAt;
  final String? reaction;

  factory StoryViewer.fromJson(Map<String, dynamic> j) => StoryViewer(
    viewer: SocialProfile.fromJson(Map<String, dynamic>.from(j['viewer'] as Map)),
    viewedAt: DateTime.tryParse(j['viewed_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    reaction: j['reaction'] as String?,
  );
}

/// Groups stories by author: me first, then unseen, then seen.
List<StoryGroup> groupStories(List<Story> stories, String myId) {
  final byAuthor = <String, List<Story>>{};
  final authors = <String, SocialProfile>{};
  for (final s in stories) {
    (byAuthor[s.author.id] ??= []).add(s);
    authors[s.author.id] = s.author;
  }
  final groups = [
    for (final e in byAuthor.entries)
      StoryGroup(authors[e.key]!, e.value..sort((a, b) => a.createdAt.compareTo(b.createdAt))),
  ];
  int rank(StoryGroup g) => g.author.id == myId ? 0 : (g.allViewed ? 2 : 1);
  groups.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : b.stories.last.createdAt.compareTo(a.stories.last.createdAt);
  });
  return groups;
}

// ------------------------------------------------------------- challenges

class ChallengeMember {
  const ChallengeMember({required this.profile, required this.checkins, required this.checkedToday});
  final SocialProfile profile;
  final int checkins;
  final bool checkedToday;

  factory ChallengeMember.fromJson(Map<String, dynamic> j) => ChallengeMember(
    profile: SocialProfile.fromJson(Map<String, dynamic>.from(j['profile'] as Map)),
    checkins: (j['checkins'] as num? ?? 0).toInt(),
    checkedToday: j['today'] == true,
  );
}

DateTime _date(Object? v) {
  final d = DateTime.tryParse(v as String? ?? '') ?? DateTime.now();
  return DateTime(d.year, d.month, d.day);
}

/// A daily check-in challenge between friends.
class Challenge {
  const Challenge({
    required this.id,
    required this.creator,
    required this.title,
    required this.emoji,
    required this.days,
    required this.startsOn,
    required this.today,
    this.description = '',
    this.joined = false,
    this.myDays = const {},
    this.members = const [],
    this.myVotes = const {},
    this.toReview = 0,
  });

  final String id;
  final SocialProfile creator;
  final String title;

  /// Friends' verdicts on my check-ins: day -> (legit, not legit).
  final Map<DateTime, (int, int)> myVotes;

  /// Friends' proofs waiting for my vote.
  final int toReview;

  CheckinStatus statusOf(DateTime day) {
    if (!myDays.contains(day)) return CheckinStatus.none;
    final (yes, no) = myVotes[day] ?? (0, 0);
    if (no > yes) return CheckinStatus.rejected;
    if (yes > 0) return CheckinStatus.verified;
    return CheckinStatus.pending;
  }

  final String emoji;
  final String description;
  final int days;
  final DateTime startsOn;

  /// "Today" as the server sees it (keeps everyone on the same calendar).
  final DateTime today;
  final bool joined;
  final Set<DateTime> myDays;
  final List<ChallengeMember> members;

  DateTime get endsOn => startsOn.add(Duration(days: days - 1));

  /// 1-based day number today (can be past [days] once finished).
  int get dayNumber => today.difference(startsOn).inDays + 1;
  bool get isActive => dayNumber >= 1 && dayNumber <= days;
  bool get isOver => dayNumber > days;
  int get daysLeft => (days - dayNumber + 1).clamp(0, days);
  bool get checkedToday => myDays.contains(today);
  bool get completed => myDays.length >= days;

  /// My current run of consecutive check-ins ending today or yesterday.
  int get myStreak {
    var d = checkedToday ? today : today.subtract(const Duration(days: 1));
    var n = 0;
    while (myDays.contains(d)) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  List<ChallengeMember> get leaderboard => [...members]..sort((a, b) => b.checkins.compareTo(a.checkins));

  Challenge copyWith({bool? joined, Set<DateTime>? myDays, List<ChallengeMember>? members, int? toReview}) => Challenge(
    id: id,
    creator: creator,
    title: title,
    emoji: emoji,
    description: description,
    days: days,
    startsOn: startsOn,
    today: today,
    joined: joined ?? this.joined,
    myDays: myDays ?? this.myDays,
    members: members ?? this.members,
    myVotes: myVotes,
    toReview: toReview ?? this.toReview,
  );

  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
    id: j['id'] as String,
    creator: SocialProfile.fromJson(Map<String, dynamic>.from(j['creator'] as Map)),
    title: j['title'] as String? ?? 'Challenge',
    emoji: j['emoji'] as String? ?? '🏁',
    description: j['description'] as String? ?? '',
    days: (j['days'] as num? ?? 7).toInt(),
    startsOn: _date(j['starts_on']),
    today: _date(j['today'] ?? DateTime.now().toIso8601String()),
    joined: j['joined'] == true,
    myDays: {for (final d in (j['my_days'] as List? ?? const [])) _date(d)},
    members: [
      for (final m in (j['members'] as List? ?? const []))
        ChallengeMember.fromJson(Map<String, dynamic>.from(m as Map)),
    ],
    myVotes: {
      for (final v in (j['my_checkins'] as List? ?? const []))
        if (v is Map) _date(v['day']): ((v['yes'] as num? ?? 0).toInt(), (v['no'] as num? ?? 0).toInt()),
    },
    toReview: (j['to_review'] as num? ?? 0).toInt(),
  );
}

/// Ready-made challenges for fitness, food and life.
const challengeTemplates = <(String, String, String)>[
  ('🚶', '10k steps a day', 'Walk at least 10,000 steps every day.'),
  ('🏋️', 'Move every day', 'Any workout, run, yoga or sport, at least 20 minutes.'),
  ('💧', 'Drink 3 L of water', 'Hit 3 litres of water daily.'),
  ('🍬', 'No added sugar', 'No sweets, sugary drinks or desserts.'),
  ('🥗', 'Veggies with every meal', 'Something green on every plate.'),
  ('🧘', '10 min of calm', 'Meditate, breathe or journal for 10 minutes.'),
  ('📚', 'Read 20 pages', 'Read at least 20 pages a day.'),
  ('😴', 'In bed by 11', 'Lights out by 11 pm, no scrolling in bed.'),
  ('📵', 'No phone first hour', 'No social media for the first hour after waking.'),
];

enum CheckinStatus { none, pending, verified, rejected }

/// A friend's check-in proof waiting for my vote.
class CheckinReview {
  const CheckinReview({
    required this.challengeId,
    required this.profile,
    required this.day,
    this.note = '',
    this.photoPath,
    this.photoUrl,
    this.photoBytes,
  });

  final String challengeId;
  final SocialProfile profile;
  final DateTime day;
  final String note;
  final String? photoPath;
  final String? photoUrl;
  final List<int>? photoBytes;

  factory CheckinReview.fromJson(Map<String, dynamic> j, {String? photoUrl}) => CheckinReview(
    challengeId: j['challenge_id'] as String,
    profile: SocialProfile.fromJson(Map<String, dynamic>.from(j['profile'] as Map)),
    day: _date(j['day']),
    note: j['note'] as String? ?? '',
    photoPath: j['photo_path'] as String?,
    photoUrl: photoUrl,
  );
}
