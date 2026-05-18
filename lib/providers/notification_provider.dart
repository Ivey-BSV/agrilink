import 'dart:async';

import 'package:cap/services/notification_service.dart';
import 'package:cap/services/push_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _onAuthChanged();
    });
    _onAuthChanged();
  }

  final NotificationService _service = NotificationService();
  StreamSubscription<dynamic>? _authSub;
  RealtimeChannel? _realtimeChannel;

  int _unreadCount = 0;
  bool _loading = false;
  String? _error;

  int get unreadCount => _unreadCount;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> _onAuthChanged() async {
    await _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;

    if (Supabase.instance.client.auth.currentUser == null) {
      _unreadCount = 0;
      _error = null;
      notifyListeners();
      return;
    }

    await refreshUnreadCount();
    _subscribeRealtime();
    await PushNotificationService.syncTokenIfAllowed();
  }

  void _subscribeRealtime() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _realtimeChannel = Supabase.instance.client
        .channel('user_notifications_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_notifications',
          callback: (_) {
            refreshUnreadCount();
          },
        )
        .subscribe();
  }

  Future<void> refreshUnreadCount() async {
    try {
      _error = null;
      final n = await _service.countUnread();
      if (_unreadCount != n) {
        _unreadCount = n;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> requestPushPermissionAndFlag() async {
    await PushNotificationService.initialize();
    await PushNotificationService.registerAfterUserOptIn();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
