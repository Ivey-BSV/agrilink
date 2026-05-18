import 'package:flutter/material.dart';
import 'package:cap/shared/models/comment.dart';
import 'package:cap/shared/models/post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostProvider extends ChangeNotifier {
  List<Post> _posts = [];
  bool _isLoading = false;
  final Map<String, List<Comment>> _postComments = {};

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;

  PostProvider();

  Future<Set<String>> _getExcludedUserIds(SupabaseClient supabase) async {
    final user = supabase.auth.currentUser;
    if (user == null) return <String>{};
    try {
      final rows = await supabase
          .from('user_blocks')
          .select('blocker_id, blocked_id')
          .or('blocker_id.eq.${user.id},blocked_id.eq.${user.id}');
      final Set<String> ids = <String>{};
      for (final raw in rows as List<dynamic>) {
        final row = raw as Map<String, dynamic>;
        final blocker = row['blocker_id'] as String;
        final blocked = row['blocked_id'] as String;
        if (blocker == user.id) {
          ids.add(blocked);
        } else if (blocked == user.id) {
          ids.add(blocker);
        }
      }
      return ids;
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> loadPostsFromSupabase() async {
    _isLoading = true;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final excludedUserIds = await _getExcludedUserIds(supabase);
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
        final List<dynamic> commentRows = await supabase
            .from('comments')
            .select('post_id')
            .inFilter('post_id', postIds.toList());

        for (final comment in commentRows) {
          final postId = comment['post_id'] as String;
          postCommentCounts[postId] = (postCommentCounts[postId] ?? 0) + 1;
        }
      }

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

        return Post.fromSupabaseRow(row,
            userName: username,
            userAvatar: avatarUrl,
            commentCount: commentCount);
      }).toList();

      _posts = fetched;
    } catch (_) { /* ignored */ } finally {
      _isLoading = false;
      notifyListeners();
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
      final excludedUserIds = await _getExcludedUserIds(supabase);
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
    } catch (e) { /* ignored */ }
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
    } catch (e) { /* ignored */ }
  }

  Future<void> deleteComment(String commentId, String postId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('comments').delete().eq('id', commentId);

      await loadCommentsForPost(postId);
    } catch (e) { /* ignored */ }
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
              } catch (e) { /* ignored */ }
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
    for (var post in _posts) {
      final commentList = _postComments[post.id];
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        final newCount = commentList?.length ?? 0;
        _posts[index] = _posts[index].copyWith(
          comments: newCount,
        );
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

  void clearPosts() {
    _posts = [];
    _postComments.clear();
    _isLoading = false;
    notifyListeners();
  }
}
