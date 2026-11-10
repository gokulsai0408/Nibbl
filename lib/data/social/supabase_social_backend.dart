import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/social.dart';

/// Social features backed by Supabase (see `supabase/schema.sql`).
///
/// Users get an anonymous account automatically the first time they open the
/// social screens; their username is how friends find them.
class SupabaseSocialBackend implements SocialBackend {
  SupabaseSocialBackend(this._db);

  final SupabaseClient _db;
  static const _bucket = 'post-photos';

  @override
  bool get isLive => true;

  Future<String> _uid() async {
    final current = _db.auth.currentUser;
    if (current != null) return current.id;
    try {
      final res = await _db.auth.signInAnonymously();
      final id = res.user?.id;
      if (id == null) throw const SocialException('Could not create your account. Try again.');
      return id;
    } on AuthException catch (e) {
      throw SocialException(
        e.message.toLowerCase().contains('anonymous')
            ? 'Anonymous sign-ins are disabled in Supabase. Enable them under Authentication → Providers.'
            : e.message,
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on SocialException {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const SocialException('That username is taken.');
      throw SocialException(_friendly(e.message));
    } on StorageException catch (e) {
      throw SocialException('Photo upload failed: ${e.message}');
    } on AuthException catch (e) {
      throw SocialException(e.message);
    } catch (e) {
      final s = e.toString();
      if (s.contains('SocketException') || s.contains('ClientException') || s.contains('Failed host lookup')) {
        throw const SocialException("You're offline. Check your connection and try again.");
      }
      throw SocialException(s);
    }
  }

  String _friendly(String m) {
    if (m.contains('JWT') || m.contains('auth')) return 'Your session expired. Reopen the screen.';
    if (m.contains('could not find the function') || m.contains('does not exist')) {
      return 'The social database isn\'t set up yet. Run supabase/schema.sql in your Supabase project.';
    }
    return m;
  }

  List<Map<String, dynamic>> _list(Object? data) =>
      [for (final e in (data as List? ?? const [])) Map<String, dynamic>.from(e as Map)];

  /// Turns photo paths into short-lived signed URLs in one request.
  Future<List<Post>> _posts(Object? data) async {
    final rows = _list(data);
    final paths = [for (final r in rows) if (r['photo_path'] is String) r['photo_path'] as String];
    final urls = <String, String>{};
    if (paths.isNotEmpty) {
      try {
        final signed = await _db.storage.from(_bucket).createSignedUrlsResult(paths, 60 * 60 * 6);
        for (final s in signed.whereType<SignedUrlSuccess>()) {
          urls[s.path] = s.signedUrl;
        }
      } catch (_) {
        // Posts still show without photos.
      }
    }
    return [for (final r in rows) Post.fromJson(r, photoUrl: urls[r['photo_path']])];
  }

  @override
  Future<SocialProfile?> myProfile() => _guard(() async {
        // Don't create an account just because the app opened; that happens
        // when the user picks a username.
        final uid = _db.auth.currentUser?.id;
        if (uid == null) return null;
        final row = await _db.from('profiles').select().eq('id', uid).maybeSingle();
        return row == null ? null : SocialProfile.fromJson(row);
      });

  @override
  Future<bool> isUsernameAvailable(String username) => _guard(() async {
        final uid = await _uid();
        final row = await _db.from('profiles').select('id').eq('username', username.toLowerCase()).maybeSingle();
        return row == null || row['id'] == uid;
      });

  @override
  Future<SocialProfile> saveProfile({
    required String username,
    required String displayName,
    required String emoji,
    String bio = '',
    String? avatarUrl,
  }) =>
      _guard(() async {
        final uid = await _uid();
        final row = await _db
            .from('profiles')
            .upsert({
              'id': uid,
              'username': username.trim().toLowerCase(),
              'display_name': displayName.trim(),
              'avatar_emoji': emoji,
              'bio': bio.trim(),
              'avatar_url': avatarUrl,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .select()
            .single();
        return SocialProfile.fromJson(row);
      });

  @override
  Future<String> uploadAvatar(List<int> jpeg) => _guard(() async {
        final uid = await _uid();
        // A new file name each time so phones don't show a cached old photo.
        final path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _db.storage.from('avatars').uploadBinary(
              path,
              Uint8List.fromList(jpeg),
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
            );
        return _db.storage.from('avatars').getPublicUrl(path);
      });

  @override
  Future<void> syncStats({required int streak, required int mochiLevel}) => _guard(() async {
        final uid = await _uid();
        await _db.from('profiles').update({'streak': streak, 'mochi_level': mochiLevel}).eq('id', uid);
      });

  @override
  Future<List<SocialProfile>> search(String query) => _guard(() async {
        await _uid();
        final data = await _db.rpc('search_profiles', params: {'q': query});
        return [for (final r in _list(data)) SocialProfile.fromJson(r)];
      });

  @override
  Future<List<FriendLink>> friendships() => _guard(() async {
        await _uid();
        final data = await _db.rpc('get_friendships');
        return [for (final r in _list(data)) FriendLink.fromJson(r)];
      });

  @override
  Future<RequestResult> sendRequest(String userId) => _guard(() async {
        await _uid();
        final res = await _db.rpc('send_friend_request', params: {'p_to': userId});
        return switch (res) {
          'accepted' => RequestResult.accepted,
          'already_sent' => RequestResult.alreadySent,
          'already_friends' => RequestResult.alreadyFriends,
          _ => RequestResult.sent,
        };
      });

  @override
  Future<void> respond(int linkId, {required bool accept}) => _guard(() async {
        await _db.rpc('respond_friend_request', params: {'p_id': linkId, 'p_accept': accept});
      });

  @override
  Future<void> removeLink(int linkId) => _guard(() async {
        await _db.rpc('remove_friendship', params: {'p_id': linkId});
      });

  @override
  Future<List<Post>> feed({DateTime? before}) => _guard(() async {
        await _uid();
        final data = await _db.rpc('get_feed', params: {
          'p_before': (before ?? DateTime.now().add(const Duration(minutes: 1))).toUtc().toIso8601String(),
          'p_limit': 20,
        });
        return _posts(data);
      });

  @override
  Future<List<Post>> postsBy(String userId) => _guard(() async {
        await _uid();
        final data = await _db.rpc('get_user_posts', params: {'p_user': userId});
        return _posts(data);
      });

  @override
  Future<Post> createPost(NewPost post) => _guard(() async {
        final uid = await _uid();
        final id = const Uuid().v4();
        String? path;
        if (post.photo != null) {
          path = '$uid/$id.jpg';
          await _db.storage.from(_bucket).uploadBinary(
                path,
                Uint8List.fromList(post.photo!),
                fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
              );
        }
        await _db.from('posts').insert({
          'id': id,
          'author': uid,
          'caption': post.caption.trim(),
          'photo_path': path,
          'dish_name': post.dishName,
          'emoji': post.emoji,
          'kcal': post.kcal,
          'protein': post.protein,
          'recipe': post.recipe?.toJson(),
          'category': post.category.name,
          'activity': post.activity?.toJson(),
        });
        final mine = await postsBy(uid);
        return mine.firstWhere((p) => p.id == id, orElse: () => mine.first);
      });

  @override
  Future<void> deletePost(Post post) => _guard(() async {
        await _db.from('posts').delete().eq('id', post.id);
        if (post.photoPath != null) {
          try {
            await _db.storage.from(_bucket).remove([post.photoPath!]);
          } catch (_) {}
        }
      });

  @override
  Future<void> react(String postId, String? emoji) => _guard(() async {
        final uid = await _uid();
        if (emoji == null) {
          await _db.from('reactions').delete().eq('post_id', postId).eq('user_id', uid);
        } else {
          await _db.from('reactions').upsert({'post_id': postId, 'user_id': uid, 'emoji': emoji});
        }
      });

  @override
  Future<List<PostComment>> comments(String postId) => _guard(() async {
        final data = await _db.rpc('get_comments', params: {'p_post': postId});
        return [for (final r in _list(data)) PostComment.fromJson(r)];
      });

  @override
  Future<PostComment> addComment(String postId, String body) => _guard(() async {
        final uid = await _uid();
        await _db.from('comments').insert({'post_id': postId, 'author': uid, 'body': body.trim()});
        final all = await comments(postId);
        return all.lastWhere((c) => c.author.id == uid, orElse: () => all.last);
      });

  @override
  Future<void> deleteComment(int commentId) => _guard(() async {
        await _db.from('comments').delete().eq('id', commentId);
      });

  // ------------------------------------------------------------ stories

  Future<Map<String, String>> _sign(List<String> paths) async {
    final urls = <String, String>{};
    if (paths.isEmpty) return urls;
    try {
      final signed = await _db.storage.from(_bucket).createSignedUrlsResult(paths, 60 * 60 * 6);
      for (final s in signed.whereType<SignedUrlSuccess>()) {
        urls[s.path] = s.signedUrl;
      }
    } catch (_) {}
    return urls;
  }

  @override
  Future<List<Story>> stories() => _guard(() async {
        if (_db.auth.currentUser == null) return const [];
        final rows = _list(await _db.rpc('get_stories'));
        final urls = await _sign([for (final r in rows) if (r['photo_path'] is String) r['photo_path'] as String]);
        return [for (final r in rows) Story.fromJson(r, photoUrl: urls[r['photo_path']])];
      });

  @override
  Future<Story> createStory(NewStory story) => _guard(() async {
        final uid = await _uid();
        final id = const Uuid().v4();
        String? path;
        if (story.photo != null) {
          path = '$uid/stories/$id.jpg';
          await _db.storage.from(_bucket).uploadBinary(
                path,
                Uint8List.fromList(story.photo!),
                fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
              );
        }
        await _db.from('stories').insert({
          'id': id,
          'author': uid,
          'kind': story.kind.name,
          'photo_path': path,
          'caption': story.caption.trim(),
          'data': story.progress?.toJson(),
          'recipe': story.recipe?.toJson(),
        });
        final all = await stories();
        return all.firstWhere((s) => s.id == id);
      });

  @override
  Future<void> deleteStory(Story story) => _guard(() async {
        await _db.from('stories').delete().eq('id', story.id);
        if (story.photoPath != null) {
          try {
            await _db.storage.from(_bucket).remove([story.photoPath!]);
          } catch (_) {}
        }
      });

  @override
  Future<void> viewStory(String storyId, {String? reaction}) => _guard(() async {
        await _db.rpc('view_story', params: {'p_story': storyId, 'p_reaction': reaction});
      });

  @override
  Future<List<StoryViewer>> storyViewers(String storyId) => _guard(() async {
        final rows = _list(await _db.rpc('get_story_viewers', params: {'p_story': storyId}));
        return [for (final r in rows) StoryViewer.fromJson(r)];
      });

  // ---------------------------------------------------------- challenges

  @override
  Future<List<Challenge>> challenges() => _guard(() async {
        if (_db.auth.currentUser == null) return const [];
        final rows = _list(await _db.rpc('get_challenges'));
        return [for (final r in rows) Challenge.fromJson(r)];
      });

  @override
  Future<void> createChallenge({
    required String title,
    required String emoji,
    String description = '',
    required int days,
  }) =>
      _guard(() async {
        await _uid();
        await _db.rpc('create_challenge', params: {
          'p_title': title,
          'p_emoji': emoji,
          'p_description': description,
          'p_days': days,
        });
      });

  @override
  Future<void> joinChallenge(String id) => _guard(() async {
        await _db.rpc('join_challenge', params: {'p_id': id});
      });

  @override
  Future<void> leaveChallenge(String id) => _guard(() async {
        await _db.rpc('leave_challenge', params: {'p_id': id});
      });

  @override
  Future<void> checkIn(String id, {required bool done, List<int>? photo, String note = ''}) => _guard(() async {
        final uid = await _uid();
        String? path;
        if (done && photo != null) {
          final today = DateTime.now();
          final day = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          path = '$uid/checkins/$id/$day-${today.millisecondsSinceEpoch}.jpg';
          await _db.storage.from(_bucket).uploadBinary(
                path,
                Uint8List.fromList(photo),
                fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
              );
        }
        await _db.rpc('challenge_check_in', params: {
          'p_id': id,
          'p_done': done,
          'p_photo_path': path,
          'p_note': note,
        });
      });

  @override
  Future<List<CheckinReview>> checkinsToReview(String challengeId) => _guard(() async {
        final rows = _list(await _db.rpc('get_checkins_to_review', params: {'p_id': challengeId}));
        final urls = await _sign([for (final r in rows) if (r['photo_path'] is String) r['photo_path'] as String]);
        return [for (final r in rows) CheckinReview.fromJson(r, photoUrl: urls[r['photo_path']])];
      });

  @override
  Future<void> voteCheckin(CheckinReview review, {required bool approve}) => _guard(() async {
        final d = review.day;
        await _db.rpc('vote_checkin', params: {
          'p_id': review.challengeId,
          'p_user': review.profile.id,
          'p_day': '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
          'p_approve': approve,
        });
      });

  @override
  Future<void> signOut() => _guard(() => _db.auth.signOut());

}
