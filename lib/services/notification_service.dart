import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final SupabaseClient _client = Supabase.instance.client;

  String? get _uid => _client.auth.currentUser?.id;

  Future<int> countUnread() async {
    final uid = _uid;
    if (uid == null) return 0;
    final rows = await _client
        .from('user_notifications')
        .select('id')
        .eq('user_id', uid)
        .isFilter('read_at', null);
    return (rows as List).length;
  }

  Future<List<Map<String, dynamic>>> listNotifications({int limit = 80}) async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from('user_notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> markRead(String notificationId) async {
    final uid = _uid;
    if (uid == null) return;
    await _client
        .from('user_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId)
        .eq('user_id', uid);
  }

  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    await _client
        .from('user_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', uid)
        .isFilter('read_at', null);
  }

  Future<Map<String, dynamic>?> getSettings() async {
    final uid = _uid;
    if (uid == null) return null;
    final row = await _client
        .from('user_notification_settings')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    if (row != null) return Map<String, dynamic>.from(row);
    await _client.from('user_notification_settings').insert({'user_id': uid});
    final again = await _client
        .from('user_notification_settings')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    return again == null ? null : Map<String, dynamic>.from(again);
  }

  Future<void> updateSettings(Map<String, dynamic> patch) async {
    final uid = _uid;
    if (uid == null) return;
    await _client
        .from('user_notification_settings')
        .update(patch)
        .eq('user_id', uid);
  }

  Future<void> setPushEnabled(bool enabled) async {
    await updateSettings({'push_enabled': enabled});
  }

  Future<void> setFcmToken(String? token) async {
    final uid = _uid;
    if (uid == null) return;
    await _client
        .from('user_profiles')
        .update({'fcm_token': token}).eq('id', uid);
  }
}
