import '../../domain/entities/macros.dart';
import '../../domain/entities/kitchen.dart';
import '../../domain/entities/social.dart';

/// Offline stand-in for the social backend, so the feature can be tried
/// before Supabase is configured. Data lives in memory for this session.
class DemoSocialBackend implements SocialBackend {
  DemoSocialBackend() {
    _seed();
  }

  static const _myId = 'me';
  SocialProfile? _me;
  final _people = <String, SocialProfile>{};
  final _links = <FriendLink>[];
  final _posts = <Post>[];
  final _comments = <String, List<PostComment>>{};
  var _nextLink = 100;
  var _nextComment = 1000;

  @override
  bool get isLive => false;

  Future<void> _delay([int ms = 350]) => Future<void>.delayed(Duration(milliseconds: ms));

  void _seed() {
    const ananya = SocialProfile(
      id: 'u1',
      username: 'ananya.eats',
      displayName: 'Ananya',
      avatarEmoji: '🌸',
      mochiLevel: 6,
      streak: 23,
      bio: 'Morning runner · paneer enthusiast',
    );
    const rahul = SocialProfile(
      id: 'u2',
      username: 'rahul_lifts',
      displayName: 'Rahul',
      avatarEmoji: '💪',
      mochiLevel: 4,
      streak: 9,
    );
    const priya = SocialProfile(
      id: 'u3',
      username: 'priya.cooks',
      displayName: 'Priya',
      avatarEmoji: '🍳',
      mochiLevel: 8,
      streak: 41,
    );
    const kiran = SocialProfile(
      id: 'u4',
      username: 'kiran',
      displayName: 'Kiran',
      avatarEmoji: '🏃',
      mochiLevel: 2,
      streak: 3,
    );
    const meera = SocialProfile(
      id: 'u5',
      username: 'meera_m',
      displayName: 'Meera',
      avatarEmoji: '🥑',
      mochiLevel: 3,
      streak: 5,
    );
    for (final p in [ananya, rahul, priya, kiran, meera]) {
      _people[p.id] = p;
    }
    _links.addAll([
      const FriendLink(id: 1, other: ananya, status: FriendStatus.accepted, incoming: false),
      const FriendLink(id: 2, other: priya, status: FriendStatus.accepted, incoming: true),
      const FriendLink(id: 3, other: rahul, status: FriendStatus.pending, incoming: true),
    ]);
    final now = DateTime.now();
    _posts.addAll([
      Post(
        id: 'p1',
        author: priya,
        caption: 'Sunday meal prep done! Made this with leftover rice and the last two eggs 🙌',
        createdAt: now.subtract(const Duration(hours: 2)),
        dishName: 'Egg fried rice',
        emoji: '🍳',
        kcal: 420,
        protein: 18,
        recipe: Recipe(
          id: 'demo_recipe',
          title: 'Egg fried rice',
          emoji: '🍳',
          summary: 'Quick fried rice with leftover rice and eggs.',
          minutes: 15,
          servings: 1,
          difficulty: 'Easy',
          ingredients: const [
            RecipeIngredient(name: 'Cooked rice', amount: '1 cup'),
            RecipeIngredient(name: 'Eggs', amount: '2'),
            RecipeIngredient(name: 'Onion, chopped', amount: '¼ cup'),
            RecipeIngredient(name: 'Oil', amount: '2 tsp', fromPantry: false),
          ],
          steps: const [
            RecipeStep(
              title: 'Scramble eggs',
              detail: 'Heat 1 tsp oil on medium, scramble the eggs until just set. Set aside.',
              minutes: 3,
            ),
            RecipeStep(
              title: 'Fry onion',
              detail: 'Add the rest of the oil, fry onion 2 minutes until soft.',
              minutes: 2,
            ),
            RecipeStep(
              title: 'Toss rice',
              detail: 'Add rice and eggs on high heat, toss 3 minutes until hot. Season.',
              minutes: 4,
            ),
          ],
          tips: const ['Day-old rice fries best.'],
          perServing: const Macros(kcal: 420, protein: 18, carbs: 52, fat: 15),
          gramsPerServing: 300,
          createdAt: now,
        ),
        reactions: const {'😋': 3, '🔥': 1},
        commentCount: 1,
      ),
      Post(
        id: 'p2',
        author: ananya,
        caption: 'Hit my protein goal 5 days in a row! Paneer tikka for dinner.',
        createdAt: now.subtract(const Duration(hours: 20)),
        dishName: 'Paneer tikka',
        emoji: '🧀',
        kcal: 360,
        protein: 26,
        reactions: const {'👏': 2, '❤️': 1},
      ),
      Post(
        id: 'p3',
        author: ananya,
        caption: 'Sunrise 5k before work. Legs are tired but the head is clear ☀️',
        createdAt: now.subtract(const Duration(hours: 5)),
        category: PostCategory.cardio,
        activity: const PostActivity(type: 'Run', minutes: 31, distanceKm: 5.2, kcal: 340),
        reactions: const {'🔥': 4},
      ),
    ]);
    _comments['p1'] = [
      PostComment(
        id: 1,
        author: ananya,
        body: 'Looks so good! Saving this one.',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
    ];
  }

  SocialProfile _requireMe() => _me ?? (throw const SocialException('Pick a username first.'));

  @override
  Future<SocialProfile?> myProfile() async {
    await _delay(200);
    return _me;
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    await _delay(250);
    return !_people.values.any((p) => p.username == username.toLowerCase());
  }

  @override
  Future<SocialProfile> saveProfile({
    required String username,
    required String displayName,
    required String emoji,
    String bio = '',
    String? avatarUrl,
  }) async {
    await _delay();
    if (!await isUsernameAvailable(username)) throw const SocialException('That username is taken.');
    _me = SocialProfile(
      id: _myId,
      username: username.toLowerCase(),
      displayName: displayName,
      avatarEmoji: emoji,
      mochiLevel: _me?.mochiLevel ?? 1,
      streak: _me?.streak ?? 0,
      bio: bio,
      avatarUrl: avatarUrl,
    );
    return _me!;
  }

  /// Demo keeps photos in memory and returns a data URL.
  final avatarBytes = <String, List<int>>{};

  @override
  Future<String> uploadAvatar(List<int> jpeg) async {
    await _delay(500);
    final key = 'memory://avatar/${DateTime.now().millisecondsSinceEpoch}';
    avatarBytes[key] = jpeg;
    return key;
  }

  @override
  Future<void> syncStats({required int streak, required int mochiLevel}) async {
    _me = _me?.copyWith(streak: streak, mochiLevel: mochiLevel);
  }

  @override
  Future<List<SocialProfile>> search(String query) async {
    await _delay();
    final q = query.trim().toLowerCase().replaceAll('@', '');
    if (q.length < 2) return const [];
    return _people.values.where((p) => p.username.startsWith(q) || p.displayName.toLowerCase().contains(q)).toList();
  }

  @override
  Future<List<FriendLink>> friendships() async {
    await _delay();
    return List.of(_links);
  }

  @override
  Future<RequestResult> sendRequest(String userId) async {
    await _delay();
    _requireMe();
    final i = _links.indexWhere((l) => l.other.id == userId);
    if (i >= 0) {
      final l = _links[i];
      if (l.isFriend) return RequestResult.alreadyFriends;
      if (l.incoming) {
        _links[i] = FriendLink(id: l.id, other: l.other, status: FriendStatus.accepted, incoming: true);
        return RequestResult.accepted;
      }
      return RequestResult.alreadySent;
    }
    _links.insert(
      0,
      FriendLink(id: _nextLink++, other: _people[userId]!, status: FriendStatus.pending, incoming: false),
    );
    return RequestResult.sent;
  }

  @override
  Future<void> respond(int linkId, {required bool accept}) async {
    await _delay();
    final i = _links.indexWhere((l) => l.id == linkId);
    if (i < 0) return;
    final l = _links[i];
    if (accept) {
      _links[i] = FriendLink(id: l.id, other: l.other, status: FriendStatus.accepted, incoming: l.incoming);
    } else {
      _links.removeAt(i);
    }
  }

  @override
  Future<void> removeLink(int linkId) async {
    await _delay();
    _links.removeWhere((l) => l.id == linkId);
  }

  bool _visible(Post p) => p.author.id == _myId || _links.any((l) => l.isFriend && l.other.id == p.author.id);

  @override
  Future<List<Post>> feed({DateTime? before}) async {
    await _delay(450);
    if (before != null) return const [];
    return _posts.where(_visible).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<Post>> postsBy(String userId) async {
    await _delay();
    return _posts.where((p) => p.author.id == userId && _visible(p)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Post> createPost(NewPost post) async {
    await _delay(700);
    final me = _requireMe();
    final p = Post(
      id: 'mine_${DateTime.now().microsecondsSinceEpoch}',
      author: me,
      caption: post.caption.trim(),
      createdAt: DateTime.now(),
      photoBytes: post.photo,
      dishName: post.dishName,
      emoji: post.emoji,
      kcal: post.kcal,
      protein: post.protein,
      recipe: post.recipe,
      category: post.category,
      activity: post.activity,
    );
    _posts.insert(0, p);
    return p;
  }

  @override
  Future<void> deletePost(Post post) async {
    await _delay();
    _posts.removeWhere((p) => p.id == post.id);
  }

  @override
  Future<void> react(String postId, String? emoji) async {
    await _delay(150);
    final i = _posts.indexWhere((p) => p.id == postId);
    if (i >= 0) _posts[i] = _posts[i].withMyReaction(emoji);
  }

  @override
  Future<List<PostComment>> comments(String postId) async {
    await _delay();
    return List.of(_comments[postId] ?? const []);
  }

  @override
  Future<PostComment> addComment(String postId, String body) async {
    await _delay();
    final c = PostComment(id: _nextComment++, author: _requireMe(), body: body.trim(), createdAt: DateTime.now());
    (_comments[postId] ??= []).add(c);
    final i = _posts.indexWhere((p) => p.id == postId);
    if (i >= 0) _posts[i] = _posts[i].copyWith(commentCount: _posts[i].commentCount + 1);
    return c;
  }

  @override
  Future<void> deleteComment(int commentId) async {
    await _delay();
    for (final e in _comments.entries) {
      final before = e.value.length;
      e.value.removeWhere((c) => c.id == commentId);
      if (e.value.length != before) {
        final i = _posts.indexWhere((p) => p.id == e.key);
        if (i >= 0) _posts[i] = _posts[i].copyWith(commentCount: _posts[i].commentCount - 1);
      }
    }
  }

  // ------------------------------------------------------------ stories

  final _stories = <Story>[];
  final _views = <String, List<StoryViewer>>{};
  var _storiesSeeded = false;

  void _seedStories() {
    if (_storiesSeeded) return;
    _storiesSeeded = true;
    final now = DateTime.now();
    final priya = _people['u3']!;
    final ananya = _people['u1']!;
    _stories.addAll([
      Story(
        id: 's1',
        author: priya,
        kind: StoryKind.progress,
        createdAt: now.subtract(const Duration(hours: 3)),
        expiresAt: now.add(const Duration(hours: 21)),
        caption: '41 days and counting 💪',
        progress: const StoryProgress(
          kcal: 1640,
          kcalGoal: 1700,
          protein: 112,
          proteinGoal: 110,
          waterMl: 2750,
          waterGoalMl: 2500,
          streak: 41,
          mochiLevel: 8,
          outfit: ['crown', 'sunglasses'],
          meals: 4,
        ),
      ),
      Story(
        id: 's2',
        author: priya,
        kind: StoryKind.photo,
        createdAt: now.subtract(const Duration(hours: 1)),
        expiresAt: now.add(const Duration(hours: 23)),
        caption: 'Trying Mochi\'s egg fried rice tonight 🍳',
        recipe: _posts.firstWhere((p) => p.id == 'p1').recipe,
      ),
      Story(
        id: 's3',
        author: ananya,
        kind: StoryKind.progress,
        createdAt: now.subtract(const Duration(hours: 6)),
        expiresAt: now.add(const Duration(hours: 18)),
        caption: 'Protein goal again!',
        progress: const StoryProgress(
          kcal: 1920,
          kcalGoal: 2100,
          protein: 128,
          proteinGoal: 120,
          waterMl: 1800,
          waterGoalMl: 2500,
          streak: 23,
          mochiLevel: 6,
          outfit: ['chefHat', 'scarf'],
          meals: 3,
        ),
      ),
    ]);
  }

  @override
  Future<List<Story>> stories() async {
    await _delay(300);
    _seedStories();
    final now = DateTime.now();
    return _stories
        .where(
          (s) =>
              s.expiresAt.isAfter(now) &&
              (s.author.id == _myId || _links.any((l) => l.isFriend && l.other.id == s.author.id)),
        )
        .map(
          (s) => s.author.id == _myId
              ? Story(
                  id: s.id,
                  author: s.author,
                  kind: s.kind,
                  createdAt: s.createdAt,
                  expiresAt: s.expiresAt,
                  caption: s.caption,
                  photoBytes: s.photoBytes,
                  progress: s.progress,
                  recipe: s.recipe,
                  viewed: true,
                  viewCount: _views[s.id]?.length ?? 0,
                )
              : s,
        )
        .toList();
  }

  @override
  Future<Story> createStory(NewStory story) async {
    await _delay(600);
    final now = DateTime.now();
    final s = Story(
      id: 'mine_s${now.microsecondsSinceEpoch}',
      author: _requireMe(),
      kind: story.kind,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
      caption: story.caption.trim(),
      photoBytes: story.photo,
      progress: story.progress,
      recipe: story.recipe,
      viewed: true,
      viewCount: 0,
    );
    _stories.add(s);
    // Pretend a friend watched it.
    _views[s.id] = [StoryViewer(viewer: _people['u1']!, viewedAt: now, reaction: '🔥')];
    return s;
  }

  @override
  Future<void> deleteStory(Story story) async {
    await _delay();
    _stories.removeWhere((s) => s.id == story.id);
  }

  @override
  Future<void> viewStory(String storyId, {String? reaction}) async {
    final i = _stories.indexWhere((s) => s.id == storyId);
    if (i >= 0) _stories[i] = _stories[i].markViewed();
  }

  @override
  Future<List<StoryViewer>> storyViewers(String storyId) async {
    await _delay();
    return List.of(_views[storyId] ?? const []);
  }

  // ---------------------------------------------------------- challenges

  final _challenges = <Challenge>[];
  var _challengesSeeded = false;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _seedChallenges() {
    if (_challengesSeeded) return;
    _challengesSeeded = true;
    final t = _today;
    _challenges.add(
      Challenge(
        id: 'c1',
        creator: _people['u1']!,
        title: '10k steps a day',
        emoji: '🚶',
        description: 'Walk at least 10,000 steps every day.',
        days: 14,
        startsOn: t.subtract(const Duration(days: 4)),
        today: t,
        members: [
          ChallengeMember(profile: _people['u1']!, checkins: 5, checkedToday: true),
          ChallengeMember(profile: _people['u3']!, checkins: 4, checkedToday: false),
        ],
      ),
    );
  }

  ChallengeMember? _meMember(Challenge c) {
    final me = _me;
    if (me == null) return null;
    return ChallengeMember(profile: me, checkins: c.myDays.length, checkedToday: c.myDays.contains(c.today));
  }

  Challenge _withMe(Challenge c) => c.copyWith(
    members: [
      for (final m in c.members)
        if (m.profile.id != _myId) m,
      if (c.joined) ?_meMember(c),
    ],
  );

  @override
  Future<List<Challenge>> challenges() async {
    await _delay(300);
    _seedChallenges();
    return [
      for (final c in _challenges)
        _withMe(c).copyWith(
          toReview: c.joined
              ? c.members
                  .where((m) => m.profile.id != _myId && m.checkedToday && !_reviewed.contains('${c.id}/${m.profile.id}'))
                  .length
              : 0,
        ),
    ];
  }

  @override
  Future<void> createChallenge({
    required String title,
    required String emoji,
    String description = '',
    required int days,
  }) async {
    await _delay();
    final me = _requireMe();
    _challenges.insert(
      0,
      Challenge(
        id: 'mine_c${DateTime.now().microsecondsSinceEpoch}',
        creator: me,
        title: title,
        emoji: emoji,
        description: description,
        days: days,
        startsOn: _today,
        today: _today,
        joined: true,
      ),
    );
  }

  void _update(String id, Challenge Function(Challenge) f) {
    final i = _challenges.indexWhere((c) => c.id == id);
    if (i >= 0) _challenges[i] = f(_challenges[i]);
  }

  @override
  Future<void> joinChallenge(String id) async {
    await _delay();
    _requireMe();
    _update(id, (c) => c.copyWith(joined: true));
  }

  @override
  Future<void> leaveChallenge(String id) async {
    await _delay();
    _update(id, (c) => c.copyWith(joined: false, myDays: {}));
  }

  final _reviewed = <String>{};

  @override
  Future<List<CheckinReview>> checkinsToReview(String challengeId) async {
    await _delay();
    final c = _challenges.where((x) => x.id == challengeId).firstOrNull;
    if (c == null || !c.joined) return const [];
    return [
      for (final m in c.members)
        if (m.profile.id != _myId && m.checkedToday && !_reviewed.contains('$challengeId/${m.profile.id}'))
          CheckinReview(
            challengeId: challengeId,
            profile: m.profile,
            day: c.today,
            note: 'Morning walk done, 11,240 steps 🚶',
          ),
    ];
  }

  @override
  Future<void> voteCheckin(CheckinReview review, {required bool approve}) async {
    await _delay(200);
    _reviewed.add('${review.challengeId}/${review.profile.id}');
  }

  @override
  Future<void> checkIn(String id, {required bool done, List<int>? photo, String note = ''}) async {
    await _delay(200);
    _update(id, (c) => c.copyWith(myDays: done ? {...c.myDays, c.today} : ({...c.myDays}..remove(c.today))));
  }

  @override
  Future<void> signOut() async {
    _me = null;
  }
}
