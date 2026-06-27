import 'package:flutter/material.dart';
import 'package:cap/shared/models/comment.dart';
import 'package:cap/shared/models/post.dart';
import 'package:cap/shared/utils/user_block_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostProvider extends ChangeNotifier {
  List<Post> _posts = [];
  bool _isLoading = false;
  final Map<String, List<Comment>> _postComments = {};
  final Set<String> _likedByMe = {};
  final Map<String, int> _extraLikeCounts = {};
  final Map<String, int> _commentCountsByPostId = {};

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;

  bool isPostLikedByMe(String postId) => _likedByMe.contains(postId);

  int likeCountForPost(String postId) {
    final inList = _posts.where((p) => p.id == postId).firstOrNull;
    if (inList != null) return inList.likes;
    return _extraLikeCounts[postId] ?? 0;
  }

  int commentCountForPost(String postId) {
    final loadedComments = _postComments[postId];
    if (loadedComments != null) return loadedComments.length;

    final inList = _posts.where((p) => p.id == postId).firstOrNull;
    if (inList != null) return inList.comments;

    return _commentCountsByPostId[postId] ?? 0;
  }

  PostProvider();

  Future<void> loadPostsFromSupabase() async {
    _isLoading = true;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final excludedUserIds = await blockedUserIdsForCurrentUser(supabase);
      final List<dynamic> rows = await supabase
          .from('posts')
          .select(
              'id, user_id, title, content, image_urls, tags, location, created_at')
          .order('created_at', ascending: false)
          .limit(50);

      final filteredRows = rows.where((raw) {
        final row = raw as Map<String, dynamic>;
        final uid = row['user_id'] as String;
        return !excludedUserIds.contains(uid);
      }).toList();

      final Set<String> userIds = filteredRows
          .map((r) => (r as Map<String, dynamic>)['user_id'] as String)
          .toSet();

      final Set<String> postIds = filteredRows
          .map((r) => (r as Map<String, dynamic>)['id'] as String)
          .toSet();

      Map<String, Map<String, dynamic>> userIdToProfile = {};
      if (userIds.isNotEmpty) {
        final profileRows = await supabase
            .from('user_profiles')
            .select('id, full_name, username, avatar_url')
            .inFilter('id', userIds.toList());
        for (final p in profileRows as List<dynamic>) {
          final row = p as Map<String, dynamic>;
          userIdToProfile[row['id'] as String] = row;
        }
      }

      Map<String, int> postCommentCounts = {};
      if (postIds.isNotEmpty) {
        postCommentCounts = await _fetchCommentCountsForPosts(
          supabase,
          postIds,
          excludedUserIds,
        );
        _commentCountsByPostId
          ..clear()
          ..addAll(postCommentCounts);
      } else {
        _commentCountsByPostId.clear();
      }

      final likeData = await _fetchLikeData(supabase, postIds);

      final fetched = filteredRows.map((raw) {
        final row = raw as Map<String, dynamic>;
        final profile = userIdToProfile[row['user_id'] as String];
        final displayName = profile != null
            ? (profile['full_name'] as String?) ??
                (profile['username'] as String?)
            : null;
        final username = displayName ?? 'User';
        final avatarUrl =
            profile != null ? profile['avatar_url'] as String? : null;
        final postId = row['id'] as String;
        final commentCount = postCommentCounts[postId] ?? 0;

        return Post.fromSupabaseRow(
          row,
          userName: username,
          userAvatar: avatarUrl,
          commentCount: commentCount,
          likeCount: likeData.counts[postId] ?? 0,
        );
      }).toList();

      _posts = fetched;
      _applyLikedByMe(likeData.likedByMe, replace: true);
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Post?> fetchPostById(String postId) async {
    try {
      final supabase = Supabase.instance.client;
      final row = await supabase
          .from('posts')
          .select(
              'id, user_id, title, content, image_urls, tags, location, created_at')
          .eq('id', postId)
          .maybeSingle();

      if (row == null) return null;

      final rowMap = row;
      final userId = rowMap['user_id'] as String;

      final profileRow = await supabase
          .from('user_profiles')
          .select('id, full_name, username, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      String userName = 'User';
      String? avatarUrl;
      if (profileRow != null) {
        userName = (profileRow['full_name'] as String?) ??
            (profileRow['username'] as String?) ??
            'User';
        avatarUrl = profileRow['avatar_url'] as String?;
      }

      final List<dynamic> commentRows = await supabase
          .from('comments')
          .select('user_id')
          .eq('post_id', postId);
      var commentCount = 0;
      final excludedUserIds = await blockedUserIdsForCurrentUser(supabase);
      for (final raw in commentRows) {
        final uid = raw['user_id'] as String;
        if (!excludedUserIds.contains(uid)) commentCount++;
      }
      _commentCountsByPostId[postId] = commentCount;

      final likeData = await _fetchLikeData(supabase, {postId});
      _applyLikedByMe(likeData.likedByMe, replace: false);
      final likeCount = likeData.counts[postId] ?? 0;
      _extraLikeCounts[postId] = likeCount;

      return Post.fromSupabaseRow(
        rowMap,
        userName: userName,
        userAvatar: avatarUrl,
        commentCount: commentCount,
        likeCount: likeCount,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> createPost(
    String content, {
    String? imageUrl,
    List<String>? tags,
    String? location,
    String? title,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await supabase.from('posts').insert({
        'user_id': user.id,
        'title': title == null || title.isEmpty ? 'Post' : title,
        'content': content,
        'post_type': 'general',
        'tags': tags ?? [],
        'image_urls': imageUrl != null ? [imageUrl] : [],
        if (location != null) 'location': location,
      });

      await loadPostsFromSupabase();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Comment>? getCommentsForPost(String postId) {
    return _postComments[postId];
  }

  Future<void> loadCommentsForPost(String postId) async {
    try {
      final supabase = Supabase.instance.client;
      final excludedUserIds = await blockedUserIdsForCurrentUser(supabase);
      final List<dynamic> commentRows = await supabase
          .from('comments')
          .select('id, post_id, user_id, content, created_at, parent_id')
          .eq('post_id', postId)
          .order('created_at', ascending: false);

      final filteredCommentRows = commentRows.where((raw) {
        final row = raw as Map<String, dynamic>;
        final uid = row['user_id'] as String;
        return !excludedUserIds.contains(uid);
      }).toList();

      final Set<String> userIds = filteredCommentRows
          .map((r) => (r as Map<String, dynamic>)['user_id'] as String)
          .toSet();

      Map<String, Map<String, dynamic>> userIdToProfile = {};
      if (userIds.isNotEmpty) {
        final profileRows = await supabase
            .from('user_profiles')
            .select('id, full_name, username, avatar_url')
            .inFilter('id', userIds.toList());
        for (final p in profileRows as List<dynamic>) {
          final row = p as Map<String, dynamic>;
          userIdToProfile[row['id'] as String] = row;
        }
      }

      final comments = filteredCommentRows.map((raw) {
        final row = raw as Map<String, dynamic>;
        final profile = userIdToProfile[row['user_id'] as String];
        final displayName = profile != null
            ? (profile['full_name'] as String?) ??
                (profile['username'] as String?)
            : null;
        final username = displayName ?? 'User';
        final handle = profile != null
            ? (profile['username'] as String?)?.trim().toLowerCase()
            : null;
        final avatarUrl =
            profile != null ? profile['avatar_url'] as String? : null;
        return Comment.fromSupabaseRow(row,
            userName: username, usernameHandle: handle, userAvatar: avatarUrl);
      }).toList();

      _postComments[postId] = comments;
      _updateCommentCounts();
      notifyListeners();
    } catch (e) {}
  }

  Future<void> addComment(String postId, String content,
      {String? parentId}) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await supabase.from('comments').insert({
        'post_id': postId,
        'user_id': user.id,
        'content': content,
        if (parentId != null) 'parent_id': parentId,
      });

      await loadCommentsForPost(postId);
    } catch (e) {}
  }

  Future<void> deleteComment(String commentId, String postId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('comments').delete().eq('id', commentId);

      await loadCommentsForPost(postId);
    } catch (e) {}
  }

  Future<void> deletePost(String postId) async {
    try {
      final supabase = Supabase.instance.client;

      final postData = await supabase
          .from('posts')
          .select('image_urls')
          .eq('id', postId)
          .maybeSingle();

      if (postData != null) {
        final imageUrls = postData['image_urls'] as List<dynamic>?;
        if (imageUrls != null && imageUrls.isNotEmpty) {
          for (final url in imageUrls) {
            final imageUrl = url.toString();
            if (imageUrl.isNotEmpty) {
              try {
                final uri = Uri.parse(imageUrl);
                final pathSegments = uri.pathSegments;

                final bucketIndex = pathSegments.indexOf('public');
                if (bucketIndex != -1 &&
                    bucketIndex < pathSegments.length - 1) {
                  final bucket = pathSegments[bucketIndex + 1];
                  final path = pathSegments.sublist(bucketIndex + 2).join('/');

                  await supabase.storage.from(bucket).remove([path]);
                }
              } catch (e) {}
            }
          }
        }
      }

      await supabase.from('comments').delete().eq('post_id', postId);

      await supabase.from('posts').delete().eq('id', postId);

      _posts.removeWhere((post) => post.id == postId);

      _postComments.remove(postId);

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void _updateCommentCounts() {
    for (final postId in _postComments.keys) {
      final commentList = _postComments[postId];
      final newCount = commentList?.length ?? 0;
      _commentCountsByPostId[postId] = newCount;

      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _posts[index] = _posts[index].copyWith(comments: newCount);
      }
    }
    notifyListeners();
  }

  List<Post> getPostsByUser(String userId) {
    return _posts.where((post) => post.userId == userId).toList();
  }

  int getPostsCountByUser(String userId) {
    return _posts.where((post) => post.userId == userId).length;
  }

  Future<Map<String, int>> getUserStats(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      final postsResult =
          await supabase.from('posts').select('id').eq('user_id', userId);

      final followersResult = await supabase
          .from('follows')
          .select('id')
          .eq('following_id', userId);

      final followingResult =
          await supabase.from('follows').select('id').eq('follower_id', userId);

      return {
        'posts': postsResult.length,
        'followers': followersResult.length,
        'following': followingResult.length,
      };
    } catch (e) {
      return {
        'posts': getPostsCountByUser(userId),
        'followers': 0,
        'following': 0,
      };
    }
  }

  Future<void> togglePostLike(String postId) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final wasLiked = _likedByMe.contains(postId);
    final previousCount = likeCountForPost(postId);

    if (wasLiked) {
      _likedByMe.remove(postId);
      _setLikeCount(postId, previousCount > 0 ? previousCount - 1 : 0);
    } else {
      _likedByMe.add(postId);
      _setLikeCount(postId, previousCount + 1);
    }
    notifyListeners();

    try {
      if (wasLiked) {
        await supabase
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', user.id);
      } else {
        await supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': user.id,
        });
      }
    } catch (_) {
      if (wasLiked) {
        _likedByMe.add(postId);
        _setLikeCount(postId, previousCount);
      } else {
        _likedByMe.remove(postId);
        _setLikeCount(postId, previousCount);
      }
      notifyListeners();
    }
  }

  Future<void> ensureLikesLoaded(String postId) async {
    if (_posts.any((p) => p.id == postId) &&
        (_extraLikeCounts.containsKey(postId) ||
            _posts.any((p) => p.id == postId && p.likes > 0))) {
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final likeData = await _fetchLikeData(supabase, {postId});
      _applyLikedByMe(likeData.likedByMe, replace: false);
      _setLikeCount(postId, likeData.counts[postId] ?? 0);
      notifyListeners();
    } catch (_) {}
  }

  void clearPosts() {
    _posts = [];
    _postComments.clear();
    _likedByMe.clear();
    _extraLikeCounts.clear();
    _commentCountsByPostId.clear();
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, int>> _fetchCommentCountsForPosts(
    SupabaseClient supabase,
    Set<String> postIds,
    Set<String> excludedUserIds,
  ) async {
    if (postIds.isEmpty) return {};

    final counts = <String, int>{};
    final ids = postIds.toList();
    const chunkSize = 10;

    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, (i + chunkSize).clamp(0, ids.length));
      await Future.wait(chunk.map((postId) async {
        try {
          final rows = await supabase
              .from('comments')
              .select('user_id')
              .eq('post_id', postId);
          var count = 0;
          for (final raw in rows) {
            final uid = raw['user_id'] as String;
            if (!excludedUserIds.contains(uid)) count++;
          }
          counts[postId] = count;
        } catch (_) {
          counts[postId] = 0;
        }
      }));
    }

    return counts;
  }

  Future<({Map<String, int> counts, Set<String> likedByMe})> _fetchLikeData(
    SupabaseClient supabase,
    Set<String> postIds,
  ) async {
    if (postIds.isEmpty) {
      return (counts: <String, int>{}, likedByMe: <String>{});
    }

    final user = supabase.auth.currentUser;
    final List<dynamic> likeRows = await supabase
        .from('post_likes')
        .select('post_id, user_id')
        .inFilter('post_id', postIds.toList());

    final counts = <String, int>{};
    final likedByMe = <String>{};
    for (final raw in likeRows) {
      final row = raw as Map<String, dynamic>;
      final postId = row['post_id'] as String;
      counts[postId] = (counts[postId] ?? 0) + 1;
      if (user != null && row['user_id'] == user.id) {
        likedByMe.add(postId);
      }
    }

    return (counts: counts, likedByMe: likedByMe);
  }

  void _applyLikedByMe(Set<String> likedPostIds, {required bool replace}) {
    if (replace) {
      _likedByMe
        ..clear()
        ..addAll(likedPostIds);
      return;
    }

    _likedByMe.addAll(likedPostIds);
  }

  void _setLikeCount(String postId, int count) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _posts[index] = _posts[index].copyWith(likes: count);
    } else {
      _extraLikeCounts[postId] = count;
    }
  }
}
