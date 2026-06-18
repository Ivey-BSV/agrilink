import 'package:flutter/material.dart';
import 'package:cap/core/utils/username_utils.dart';
import 'package:cap/shared/models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class ProfileProvider extends ChangeNotifier {
  UserProfile? _currentProfile;
  bool _isLoading = false;
  String? _error;

  UserProfile? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> loadProfile(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('id', userId)
          .single();

      final profile = UserProfile.fromJson(response);

      _currentProfile = profile;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load profile: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({
    String? username,
    String? fullName,
    String? bio,
    String? location,
    String? farmType,
    String? experienceLevel,
    String? avatarUrl,
  }) async {
    if (_currentProfile == null) return false;

    if (username != null) {
      final normalized = normalizeUsername(username);
      if (normalized.isEmpty) {
        _setError('Invalid username');
        return false;
      }
      if (normalized != normalizeUsername(_currentProfile!.username ?? '')) {
        final taken = await isUsernameTaken(normalized,
            excludeUserId: _currentProfile!.id);
        if (taken) {
          _setError('That username is already taken. Please choose another.');
          return false;
        }
      }
    }

    _setLoading(true);
    _clearError();

    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (username != null) {
        updateData['username'] = normalizeUsername(username);
      }
      updateData['full_name'] = fullName;
      updateData['bio'] = bio;
      updateData['location'] = location;
      updateData['farm_type'] = farmType;
      updateData['experience_level'] = experienceLevel;
      updateData['avatar_url'] = avatarUrl;

      await _supabase
          .from('user_profiles')
          .update(updateData)
          .eq('id', _currentProfile!.id);

      await loadProfile(_currentProfile!.id);
      return true;
    } catch (e) {
      _setError('Failed to update profile: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> ensureProfile(String userId, String username,
      {String? fullName}) async {
    try {
      final u = normalizeUsername(username);
      if (u.isEmpty) return;
      await _supabase.from('user_profiles').upsert({
        'id': userId,
        'username': u,
        if (fullName != null) 'full_name': fullName,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'id');
    } catch (e) {
      _setError('Failed to create profile: ${e.toString()}');
    }
  }

  Future<String?> uploadProfilePicture(String userId, File file) async {
    _setLoading(true);
    _clearError();
    try {
      final bytes = await file.readAsBytes();
      final fileExt = file.path.split('.').last;
      final fileName = '$userId/profile_$userId.$fileExt';

      await _supabase.storage.from('avatars').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl =
          _supabase.storage.from('avatars').getPublicUrl(fileName);

      await _supabase
          .from('user_profiles')
          .update({'avatar_url': publicUrl}).eq('id', userId);

      await loadProfile(userId);

      return publicUrl;
    } catch (e) {
      _setError('Failed to upload profile picture: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<UserProfile?> getProfileByUsername(String username) async {
    try {
      final key = normalizeUsername(username);
      if (key.isEmpty) return null;
      final response = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('username', key)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      _setError('Failed to get profile: ${e.toString()}');
      return null;
    }
  }

  Future<bool> isUsernameTaken(String username, {String? excludeUserId}) async {
    try {
      final key = normalizeUsername(username);
      if (key.isEmpty) return false;
      var query =
          _supabase.from('user_profiles').select('id').eq('username', key);
      if (excludeUserId != null && excludeUserId.isNotEmpty) {
        query = query.neq('id', excludeUserId);
      }
      final response = await query.limit(1);
      return response.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, bool>> getBlockStatus(String targetUserId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null || targetUserId.isEmpty) {
        return {'iBlocked': false, 'blockedMe': false};
      }

      final iBlockedRes = await _supabase
          .from('user_blocks')
          .select('id')
          .eq('blocker_id', currentUser.id)
          .eq('blocked_id', targetUserId)
          .maybeSingle();

      final blockedMeRes = await _supabase
          .from('user_blocks')
          .select('id')
          .eq('blocker_id', targetUserId)
          .eq('blocked_id', currentUser.id)
          .maybeSingle();

      return {
        'iBlocked': iBlockedRes != null,
        'blockedMe': blockedMeRes != null,
      };
    } catch (_) {
      return {'iBlocked': false, 'blockedMe': false};
    }
  }

  Future<Set<String>> getBlockedOrBlockingUserIds() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return <String>{};

      final rows = await _supabase
          .from('user_blocks')
          .select('blocker_id, blocked_id')
          .or('blocker_id.eq.${currentUser.id},blocked_id.eq.${currentUser.id}');

      final Set<String> excludedUserIds = <String>{};
      for (final raw in rows as List<dynamic>) {
        final row = raw as Map<String, dynamic>;
        final blockerId = row['blocker_id'] as String;
        final blockedId = row['blocked_id'] as String;
        if (blockerId == currentUser.id) {
          excludedUserIds.add(blockedId);
        } else if (blockedId == currentUser.id) {
          excludedUserIds.add(blockerId);
        }
      }
      return excludedUserIds;
    } catch (_) {
      return <String>{};
    }
  }

  Future<bool> blockUser(String targetUserId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null || targetUserId.isEmpty) return false;
      if (currentUser.id == targetUserId) return false;

      await _supabase.from('user_blocks').upsert({
        'blocker_id': currentUser.id,
        'blocked_id': targetUserId,
      }, onConflict: 'blocker_id,blocked_id');

      await _supabase
          .from('follows')
          .delete()
          .eq('follower_id', currentUser.id)
          .eq('following_id', targetUserId);
      await _supabase
          .from('follows')
          .delete()
          .eq('follower_id', targetUserId)
          .eq('following_id', currentUser.id);

      return true;
    } catch (e) {
      _setError('Failed to block user: ${e.toString()}');
      return false;
    }
  }

  Future<bool> unblockUser(String targetUserId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null || targetUserId.isEmpty) return false;

      await _supabase
          .from('user_blocks')
          .delete()
          .eq('blocker_id', currentUser.id)
          .eq('blocked_id', targetUserId);
      return true;
    } catch (e) {
      _setError('Failed to unblock user: ${e.toString()}');
      return false;
    }
  }

  Future<List<UserProfile>> searchProfiles({
    String? location,
    String? farmType,
    int limit = 20,
  }) async {
    try {
      var query = _supabase.from('user_profiles').select('*');

      if (location != null && location.isNotEmpty) {
        query = query.ilike('location', '%$location%');
      }

      if (farmType != null && farmType.isNotEmpty) {
        query = query.eq('farm_type', farmType);
      }

      final response =
          await query.order('created_at', ascending: true).limit(limit);

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      _setError('Failed to search profiles: ${e.toString()}');
      return [];
    }
  }

  Future<UserProfile?> loadUserProfileById(
      String userId, String currentUserId) async {
    _clearError();

    try {
      final profileResponse = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('id', userId)
          .single();

      final followsResponse = await _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', currentUserId)
          .eq('following_id', userId)
          .maybeSingle();

      final isFollowing = followsResponse != null;

      return UserProfile(
        id: profileResponse['id'] as String,
        username: profileResponse['username'] as String?,
        fullName: profileResponse['full_name'] as String?,
        bio: profileResponse['bio'] as String?,
        location: profileResponse['location'] as String?,
        farmType: profileResponse['farm_type'] as String?,
        experienceLevel: profileResponse['experience_level'] as String?,
        avatarUrl: profileResponse['avatar_url'] as String?,
        createdAt: profileResponse['created_at'] != null
            ? DateTime.parse(profileResponse['created_at'] as String)
            : null,
        updatedAt: profileResponse['updated_at'] != null
            ? DateTime.parse(profileResponse['updated_at'] as String)
            : null,
        followerCount: profileResponse['follower_count'] as int? ?? 0,
        followingCount: profileResponse['following_count'] as int? ?? 0,
        isFollowing: isFollowing,
      );
    } catch (e) {
      _setError('Failed to load profile: ${e.toString()}');
      return null;
    }
  }

  Future<bool> followUser(String targetUserId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        _setError('You must be logged in to follow users');
        return false;
      }

      await _supabase.from('follows').insert({
        'follower_id': currentUser.id,
        'following_id': targetUserId,
      });

      if (_currentProfile != null) {
        await loadProfile(currentUser.id);
      }

      return true;
    } catch (e) {
      _setError('Failed to follow user: ${e.toString()}');
      return false;
    }
  }

  Future<bool> unfollowUser(String targetUserId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        _setError('You must be logged in to unfollow users');
        return false;
      }

      await _supabase
          .from('follows')
          .delete()
          .eq('follower_id', currentUser.id)
          .eq('following_id', targetUserId);

      if (_currentProfile != null) {
        await loadProfile(currentUser.id);
      }

      return true;
    } catch (e) {
      _setError('Failed to unfollow user: ${e.toString()}');
      return false;
    }
  }

  Future<List<UserProfile>> getFollowers(String userId,
      {int limit = 50}) async {
    try {
      final currentUser = _supabase.auth.currentUser;

      final response = await _supabase
          .from('follows')
          .select('follower_id, created_at')
          .eq('following_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      if (response.isEmpty) return [];

      final followerIds = (response as List)
          .map((row) => row['follower_id'] as String)
          .toList();

      final profilesResponse = await _supabase
          .from('user_profiles')
          .select('*')
          .inFilter('id', followerIds);

      final profiles = (profilesResponse as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();

      if (currentUser != null && profiles.isNotEmpty) {
        final followsCheck = await _supabase
            .from('follows')
            .select('following_id')
            .eq('follower_id', currentUser.id)
            .inFilter('following_id', followerIds);

        final followingIds = (followsCheck as List)
            .map((row) => row['following_id'] as String)
            .toSet();

        final updatedProfiles = profiles.map((profile) {
          final isFollowing = followingIds.contains(profile.id);
          return isFollowing ? profile.copyWith(isFollowing: true) : profile;
        }).toList();

        return updatedProfiles;
      }

      return profiles;
    } catch (e) {
      _setError('Failed to get followers: ${e.toString()}');
      return [];
    }
  }

  Future<List<UserProfile>> getFollowing(String userId,
      {int limit = 50}) async {
    try {
      final currentUser = _supabase.auth.currentUser;

      final response = await _supabase
          .from('follows')
          .select('following_id, created_at')
          .eq('follower_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      if (response.isEmpty) return [];

      final followingIds = (response as List)
          .map((row) => row['following_id'] as String)
          .toList();

      final profilesResponse = await _supabase
          .from('user_profiles')
          .select('*')
          .inFilter('id', followingIds);

      final profiles = (profilesResponse as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();

      if (currentUser != null && profiles.isNotEmpty) {
        final followsCheck = await _supabase
            .from('follows')
            .select('following_id')
            .eq('follower_id', currentUser.id)
            .inFilter('following_id', followingIds);

        final followingIdsSet = (followsCheck as List)
            .map((row) => row['following_id'] as String)
            .toSet();

        final updatedProfiles = profiles.map((profile) {
          final isFollowing = followingIdsSet.contains(profile.id);
          return isFollowing ? profile.copyWith(isFollowing: true) : profile;
        }).toList();

        return updatedProfiles;
      }

      return profiles;
    } catch (e) {
      _setError('Failed to get following: ${e.toString()}');
      return [];
    }
  }

  void clearProfile() {
    _currentProfile = null;
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
