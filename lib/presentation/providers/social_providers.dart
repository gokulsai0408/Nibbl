import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/social/demo_social_backend.dart';
import '../../data/social/supabase_social_backend.dart';
import '../../core/utils/date_x.dart';
import '../../domain/entities/social.dart';
import 'core_providers.dart';
import 'log_providers.dart';
import 'mochi_providers.dart';

/// Failed social requests surface an error with a retry button instead of
/// retrying silently in the background.
Duration? _noRetry(int count, Object error) => null;

final socialBackendProvider = Provider<SocialBackend>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.hasSocial) {
    try {
      return SupabaseSocialBackend(Supabase.instance.client);
    } catch (_) {
      // Supabase failed to initialise (bad URL/key); fall back to the demo.
    }
  }
  return DemoSocialBackend();
});

// ------------------------------------------------------------------ me

class MyProfileNotifier extends AsyncNotifier<SocialProfile?> {
  @override
  Future<SocialProfile?> build() async {
    final backend = ref.watch(socialBackendProvider);
    final me = await backend.myProfile();
    if (me != null) _syncStats(backend, me);
    return me;
  }

  /// Keeps my streak and Mochi level on my public profile up to date.
  void _syncStats(SocialBackend backend, SocialProfile me) {
    final streak = ref.read(streakProvider);
    final level = ref.read(mochiProgressProvider).level;
    if (me.streak != streak || me.mochiLevel != level) {
      backend.syncStats(streak: streak, mochiLevel: level).ignore();
    }
  }

  /// Saves my profile. [photo] uploads a new picture; [removePhoto] clears it.
  Future<SocialProfile> save({
    required String username,
    required String displayName,
    required String emoji,
    String bio = '',
    List<int>? photo,
    bool removePhoto = false,
  }) async {
    final backend = ref.read(socialBackendProvider);
    var avatarUrl = removePhoto ? null : state.value?.avatarUrl;
    if (photo != null) avatarUrl = await backend.uploadAvatar(photo);
    final me = await backend.saveProfile(
      username: username,
      displayName: displayName,
      emoji: emoji,
      bio: bio,
      avatarUrl: avatarUrl,
    );
    _syncStats(backend, me);
    state = AsyncData(me);
    return me;
  }

  Future<void> signOut() async {
    await ref.read(socialBackendProvider).signOut();
    ref.invalidateSelf();
  }
}

final myProfileProvider = AsyncNotifierProvider<MyProfileNotifier, SocialProfile?>(
  MyProfileNotifier.new,
  retry: _noRetry,
);

// ------------------------------------------------------------- friends

class FriendsNotifier extends AsyncNotifier<List<FriendLink>> {
  @override
  Future<List<FriendLink>> build() async {
    final me = await ref.watch(myProfileProvider.future);
    if (me == null) return const [];
    return ref.watch(socialBackendProvider).friendships();
  }

  SocialBackend get _backend => ref.read(socialBackendProvider);

  Future<void> refresh() async {
    state = await AsyncValue.guard(_backend.friendships);
  }

  Future<RequestResult> send(SocialProfile to) async {
    final r = await _backend.sendRequest(to.id);
    await refresh();
    if (r == RequestResult.accepted) ref.invalidate(feedProvider);
    return r;
  }

  Future<void> respond(FriendLink link, {required bool accept}) async {
    final prev = state.value ?? const [];
    // Optimistic: update the list straight away.
    state = AsyncData([
      for (final l in prev)
        if (l.id != link.id)
          l
        else if (accept)
          FriendLink(id: l.id, other: l.other, status: FriendStatus.accepted, incoming: l.incoming),
    ]);
    try {
      await _backend.respond(link.id, accept: accept);
      if (accept) ref.invalidate(feedProvider);
    } catch (_) {
      state = AsyncData(prev);
      rethrow;
    }
  }

  Future<void> remove(FriendLink link) async {
    final prev = state.value ?? const [];
    state = AsyncData([
      for (final l in prev)
        if (l.id != link.id) l,
    ]);
    try {
      await _backend.removeLink(link.id);
      if (link.isFriend) ref.invalidate(feedProvider);
    } catch (_) {
      state = AsyncData(prev);
      rethrow;
    }
  }
}

final friendsProvider = AsyncNotifierProvider<FriendsNotifier, List<FriendLink>>(FriendsNotifier.new, retry: _noRetry);

/// Friend requests waiting for me (for badges).
final incomingRequestCountProvider = Provider<int>((ref) {
  final links = ref.watch(friendsProvider).value ?? const [];
  return links.where((l) => l.incoming && !l.isFriend).length;
});

// ---------------------------------------------------------------- feed

class FeedNotifier extends AsyncNotifier<List<Post>> {
  bool _hasMore = true;
  bool _loadingMore = false;

  bool get hasMore => _hasMore;

  @override
  Future<List<Post>> build() async {
    _hasMore = true;
    final me = await ref.watch(myProfileProvider.future);
    if (me == null) return const [];
    final posts = await ref.watch(socialBackendProvider).feed();
    _hasMore = posts.length >= 20;
    return posts;
  }

  SocialBackend get _backend => ref.read(socialBackendProvider);

  Future<void> refresh() async {
    final posts = await AsyncValue.guard(_backend.feed);
    _hasMore = (posts.value?.length ?? 0) >= 20;
    state = posts;
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (!_hasMore || _loadingMore || current == null || current.isEmpty) return;
    _loadingMore = true;
    try {
      final more = await _backend.feed(before: current.last.createdAt);
      _hasMore = more.length >= 20;
      final seen = {for (final p in current) p.id};
      state = AsyncData([...current, ...more.where((p) => !seen.contains(p.id))]);
    } finally {
      _loadingMore = false;
    }
  }

  void _replace(Post post) {
    final list = state.value;
    if (list == null) return;
    state = AsyncData([for (final p in list) p.id == post.id ? post : p]);
  }

  /// Tapping the same reaction again removes it.
  Future<void> react(Post post, String emoji) async {
    final next = post.myReaction == emoji ? null : emoji;
    _replace(post.withMyReaction(next));
    try {
      await _backend.react(post.id, next);
    } catch (_) {
      _replace(post);
      rethrow;
    }
  }

  Future<Post> create(NewPost draft) async {
    final post = await _backend.createPost(draft);
    // Show my own photo instantly even before its signed URL is used.
    final shown = post.photoUrl == null && draft.photo != null
        ? Post(
            id: post.id,
            author: post.author,
            caption: post.caption,
            createdAt: post.createdAt,
            photoBytes: draft.photo,
            photoPath: post.photoPath,
            dishName: post.dishName,
            emoji: post.emoji,
            kcal: post.kcal,
            protein: post.protein,
            recipe: post.recipe,
            category: post.category,
            activity: post.activity,
          )
        : post;
    state = AsyncData([shown, ...?state.value?.where((p) => p.id != post.id)]);
    return shown;
  }

  Future<void> delete(Post post) async {
    final prev = state.value ?? const [];
    state = AsyncData([
      for (final p in prev)
        if (p.id != post.id) p,
    ]);
    try {
      await _backend.deletePost(post);
    } catch (_) {
      state = AsyncData(prev);
      rethrow;
    }
  }

  void setCommentCount(String postId, int count) {
    final p = state.value?.where((x) => x.id == postId).firstOrNull;
    if (p != null) _replace(p.copyWith(commentCount: count));
  }
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, List<Post>>(FeedNotifier.new, retry: _noRetry);

// ------------------------------------------------------------- stories

class StoriesNotifier extends AsyncNotifier<List<Story>> {
  @override
  Future<List<Story>> build() async {
    final me = await ref.watch(myProfileProvider.future);
    if (me == null) return const [];
    return ref.watch(socialBackendProvider).stories();
  }

  SocialBackend get _backend => ref.read(socialBackendProvider);

  Future<void> refresh() async {
    state = await AsyncValue.guard(_backend.stories);
  }

  /// Marks a story seen locally right away, then tells the server.
  void markViewed(Story story, {String? reaction}) {
    final list = state.value;
    if (list != null && !story.viewed) {
      state = AsyncData([for (final s in list) s.id == story.id ? s.markViewed() : s]);
    }
    if (!story.viewed || reaction != null) {
      _backend.viewStory(story.id, reaction: reaction).ignore();
    }
  }

  Future<Story> create(NewStory draft) async {
    final story = await _backend.createStory(draft);
    final shown = story.photoUrl == null && draft.photo != null
        ? Story(
            id: story.id,
            author: story.author,
            kind: story.kind,
            createdAt: story.createdAt,
            expiresAt: story.expiresAt,
            caption: story.caption,
            photoBytes: draft.photo,
            photoPath: story.photoPath,
            progress: story.progress,
            recipe: story.recipe,
            viewed: true,
            viewCount: story.viewCount ?? 0,
          )
        : story;
    state = AsyncData([...?state.value?.where((s) => s.id != story.id), shown]);
    return shown;
  }

  Future<void> delete(Story story) async {
    final prev = state.value ?? const [];
    state = AsyncData([
      for (final s in prev)
        if (s.id != story.id) s,
    ]);
    try {
      await _backend.deleteStory(story);
    } catch (_) {
      state = AsyncData(prev);
      rethrow;
    }
  }
}

final storiesProvider = AsyncNotifierProvider<StoriesNotifier, List<Story>>(StoriesNotifier.new, retry: _noRetry);

/// Stories grouped per person: me first, then unseen, then seen.
final storyGroupsProvider = Provider<List<StoryGroup>>((ref) {
  final me = ref.watch(myProfileProvider).value;
  final stories = ref.watch(storiesProvider).value ?? const [];
  if (me == null) return const [];
  return groupStories(stories, me.id);
});

/// Today's numbers for a progress-card story.
final todayProgressProvider = Provider<StoryProgress>((ref) {
  final day = ref.watch(daySummaryProvider(DateTime.now().dayKey));
  return StoryProgress(
    kcal: day.totals.kcal.round(),
    kcalGoal: day.targets.calories.round(),
    protein: day.totals.protein.round(),
    proteinGoal: day.targets.protein.round(),
    waterMl: day.meta.waterMl,
    waterGoalMl: day.waterGoalMl,
    streak: ref.watch(streakProvider),
    mochiLevel: ref.watch(mochiProgressProvider).level,
    outfit: [for (final i in ref.watch(mochiOutfitProvider)) i.name],
    meals: day.logs.length,
  );
});

// ---------------------------------------------------------- challenges

class ChallengesNotifier extends AsyncNotifier<List<Challenge>> {
  @override
  Future<List<Challenge>> build() async {
    final me = await ref.watch(myProfileProvider.future);
    if (me == null) return const [];
    return ref.watch(socialBackendProvider).challenges();
  }

  SocialBackend get _backend => ref.read(socialBackendProvider);

  Future<void> refresh() async {
    state = await AsyncValue.guard(_backend.challenges);
  }

  Future<void> create({
    required String title,
    required String emoji,
    String description = '',
    required int days,
  }) async {
    await _backend.createChallenge(title: title, emoji: emoji, description: description, days: days);
    await refresh();
  }

  Future<void> join(Challenge c) async {
    await _backend.joinChallenge(c.id);
    await refresh();
  }

  Future<void> leave(Challenge c) async {
    await _backend.leaveChallenge(c.id);
    await refresh();
  }

  /// Optimistic check-in: the tick appears instantly.
  Future<void> checkIn(Challenge c, {required bool done, List<int>? photo, String note = ''}) async {
    final prev = state.value ?? const [];
    final me = ref.read(myProfileProvider).value;
    final days = {...c.myDays};
    done ? days.add(c.today) : days.remove(c.today);
    final updated = c.copyWith(
      myDays: days,
      members: [
        for (final m in c.members)
          m.profile.id == me?.id ? ChallengeMember(profile: m.profile, checkins: days.length, checkedToday: done) : m,
      ],
    );
    state = AsyncData([for (final x in prev) x.id == c.id ? updated : x]);
    try {
      await _backend.checkIn(c.id, done: done, photo: photo, note: note);
    } catch (_) {
      state = AsyncData(prev);
      rethrow;
    }
  }
}

final challengesProvider = AsyncNotifierProvider<ChallengesNotifier, List<Challenge>>(
  ChallengesNotifier.new,
  retry: _noRetry,
);

/// Challenges I finished every day of.
final trophyCountProvider = Provider<int>((ref) {
  final list = ref.watch(challengesProvider).value ?? const [];
  return list.where((c) => c.joined && c.completed).length;
});
