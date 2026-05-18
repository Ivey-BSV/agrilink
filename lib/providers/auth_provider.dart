import 'package:flutter/material.dart';
import 'package:cap/core/config/supabase_config.dart';
import 'package:cap/core/utils/username_utils.dart';
import 'package:cap/services/push_notification_service.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  static const String currentBuildVersion = 'web-2025-09-22-1';

  bool _isAuthenticated = false;
  String? _userId;
  String? _userName;
  String? _userEmail;
  String? _userAvatar;
  ProfileProvider? _profileProvider;

  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userAvatar => _userAvatar;
  AuthProvider() {
    _profileProvider = ProfileProvider();
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();

    final storedBuildVersion = prefs.getString('appBuildVersion');
    if (storedBuildVersion != currentBuildVersion) {
      await prefs.clear();
      await prefs.setString('appBuildVersion', currentBuildVersion);
      _isAuthenticated = false;
      _userId = null;
      _userName = null;
      _userEmail = null;
      _userAvatar = null;
    }

    final session = Supabase.instance.client.auth.currentSession;
    final user = session?.user;

    if (user == null) {
      _isAuthenticated = false;
      _userId = null;
      _userName = null;
      _userEmail = null;
      _userAvatar = null;
      await prefs.setBool('isAuthenticated', false);
      notifyListeners();
      return;
    }

    _isAuthenticated = true;
    _userId = user.id;
    _userName = (user.userMetadata?['username'] as String? ??
            user.email?.split('@').first)
        ?.toLowerCase();
    _userEmail = user.email;
    _userAvatar = user.userMetadata?['avatar_url'] as String?;

    await _profileProvider?.loadProfile(user.id);

    await _saveAuthState();
    notifyListeners();
  }

  Future<bool> login(String usernameOrEmail, String password) async {
    _profileProvider?.clearProfile();

    final supabase = Supabase.instance.client;

    String email = usernameOrEmail;

    if (!usernameOrEmail.contains('@')) {
      try {
        final response = await supabase.rpc('get_email_by_username', params: {
          'username_param': normalizeUsername(usernameOrEmail),
        });
        if (response != null && response.toString().isNotEmpty) {
          email = response.toString();
        }
      } catch (e) {
        email = usernameOrEmail;
      }
    }

    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final session = response.session;
    final user = response.user;
    if (session != null && user != null) {
      try {
        final profileResponse = await supabase
            .from('user_profiles')
            .select('username, full_name, avatar_url')
            .eq('id', user.id)
            .single();

        _isAuthenticated = true;
        _userId = user.id;
        _userName =
            (profileResponse['username'] ?? user.email?.split('@').first)
                ?.toString()
                .toLowerCase();
        _userEmail = user.email;
        _userAvatar = profileResponse['avatar_url'];

        await _profileProvider?.loadProfile(user.id);

        await _saveAuthState();
        notifyListeners();
        return true;
      } catch (e) {
        _isAuthenticated = true;
        _userId = user.id;
        _userName = ((user.userMetadata?['username'] as String?) ??
                user.email?.split('@').first)
            ?.toLowerCase();
        _userEmail = user.email;
        _userAvatar = user.userMetadata?['avatar_url'] as String?;

        await _profileProvider?.ensureProfile(user.id, _userName ?? 'user');
        await _profileProvider?.loadProfile(user.id);

        await _saveAuthState();
        notifyListeners();
        return true;
      }
    }

    return false;
  }

  Future<void> _saveAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appBuildVersion', currentBuildVersion);
    await prefs.setBool('isAuthenticated', true);
    await prefs.setString('userId', _userId!);
    await prefs.setString('userName', _userName!);
    await prefs.setString('userEmail', _userEmail!);
    if (_userAvatar != null) {
      await prefs.setString('userAvatar', _userAvatar!);
    }
  }

  Future<String?> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
  }) async {
    final normalizedUsername = normalizeUsername(username);
    if (normalizedUsername.length < 2) {
      return 'Username must be at least 2 characters.';
    }
    final taken =
        await _profileProvider?.isUsernameTaken(normalizedUsername) ?? false;
    if (taken) {
      return 'That username is already taken. Please choose another.';
    }
    final supabase = Supabase.instance.client;
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': normalizedUsername,
        if (fullName != null) 'full_name': fullName,
      },
    );

    final user = response.user;
    if (user != null) {
      await _profileProvider?.ensureProfile(user.id, normalizedUsername,
          fullName: fullName);

      _isAuthenticated = true;
      _userId = user.id;
      _userName = normalizedUsername;
      _userEmail = email;
      _userAvatar = null;

      await _profileProvider?.loadProfile(user.id);

      await _saveAuthState();
      notifyListeners();
      return null;
    }

    return 'Registration failed. Please try again.';
  }

  Future<void> logout() async {
    try {
      await PushNotificationService.clearForLogout();
    } catch (_) {}
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    _isAuthenticated = false;
    _userId = null;
    _userName = null;
    _userEmail = null;
    _userAvatar = null;

    _profileProvider?.clearProfile();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    notifyListeners();
  }

  Future<String?> deleteAccount() async {
    final currentUserId = _userId;
    if (currentUserId == null) return 'Not authenticated';

    try {
      final supabase = Supabase.instance.client;
      final res = await supabase.functions.invoke(
        'delete_account',
        body: const {},
      );

      if (res.status >= 200 && res.status < 300) {
        await logout();
        return null;
      }

      final body = res.data;
      if (body is Map && body['error'] != null) {
        return body['error'].toString();
      }
      return 'Failed to delete account';
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('not found') || msg.contains('404')) {
        return 'Delete account service unavailable. Deploy Supabase Edge Function "delete_account".';
      }
      return msg.length > 120
          ? 'Network or server error. Please try again.'
          : msg;
    }
  }

  static const String _resetCode = '1234';

  Future<String?> resetPasswordWithCode({
    required String usernameOrEmail,
    required String code,
    required String newPassword,
  }) async {
    if (code != _resetCode) return 'Invalid code';
    if (newPassword.length < 6) return 'Password must be at least 6 characters';
    final supabase = Supabase.instance.client;
    try {
      final res = await supabase.functions.invoke(
        'reset_password',
        body: {
          'usernameOrEmail': usernameOrEmail.trim().contains('@')
              ? usernameOrEmail.trim()
              : normalizeUsername(usernameOrEmail),
          'code': code,
          'new_password': newPassword,
        },
        headers: {
          'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
        },
      );
      if (res.status >= 200 && res.status < 300) return null;
      final body = res.data;
      if (body is Map && body.containsKey('error')) {
        return body['error'] as String? ?? 'Reset failed';
      }
      if (res.status == 404)
        return 'No account found for that email or username';
      if (res.status >= 500) return 'Server error. Try again later.';
      return 'Could not reset password';
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('404') ||
          msg.contains('not found') ||
          msg.contains('Connection')) {
        return 'Reset password service unavailable. Deploy the Supabase Edge Function "reset_password" or check your connection.';
      }
      return msg.length > 80 ? 'Network or server error. Try again.' : msg;
    }
  }

}
