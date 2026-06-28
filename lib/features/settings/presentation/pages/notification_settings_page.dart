import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/notification_provider.dart';
import 'package:cap/services/notification_service.dart';
import 'package:cap/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final NotificationService _service = NotificationService();
  Map<String, dynamic>? _row;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await _service.getSettings();
      if (!mounted) return;
      setState(() {
        _row = row;
        _loading = false;
      });
      if (row?['push_enabled'] == true) {
        await PushNotificationService.ensureRegistrationIfEnabled();
        if (!mounted) return;
        final refreshed = await _service.getSettings();
        if (!mounted) return;
        setState(() => _row = refreshed);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _patch(String key, bool value) async {
    final prev = _row?[key];
    setState(() {
      _row = {...?_row, key: value};
    });
    try {
      await _service.updateSettings({key: value});
      if (!mounted) return;
      await context.read<NotificationProvider>().refreshUnreadCount();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _row = {...?_row, key: prev};
        _error = e.toString();
      });
    }
  }

  Future<void> _requestPush() async {
    final tokenSaved =
        await context.read<NotificationProvider>().requestPushPermissionAndFlag();
    await _load();
    if (!mounted) return;

    final pushOn = _b('push_enabled', defaultValue: false);
    final String message;
    if (!pushOn) {
      message =
          'Notification permission was denied. Open Settings → AgriLink → Notifications to allow alerts.';
    } else if (!tokenSaved) {
      message =
          'Push is on, but no device token was saved. Try again, or use a physical iPhone.';
    } else {
      message =
          'Push notifications enabled. You’ll get alerts when the app is closed.';
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: !pushOn
            ? SnackBarAction(
                label: 'Settings',
                onPressed: PushNotificationService.openSystemNotificationSettings,
              )
            : null,
      ),
    );
  }

  bool _b(String key, {bool defaultValue = true}) {
    final v = _row?[key];
    if (v is bool) return v;
    return defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Notification settings'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _row == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Sign in to manage notification preferences.'),
                  ),
                )
              : ListView(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppTheme.errorRed),
                        ),
                      ),
                    const Text(
                      'Choose what you are notified about in the app. Push delivery still requires Firebase (FCM) setup on the project.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    _toggle(
                      'New posts in the feed',
                      'notify_new_posts_feed',
                    ),
                    _toggle(
                      'New polls',
                      'notify_new_polls',
                    ),
                    _toggle(
                      'Likes on your posts',
                      'notify_post_likes',
                    ),
                    _toggle(
                      'Comments on your posts',
                      'notify_post_comments',
                    ),
                    _toggle(
                      'Polls you voted in close',
                      'notify_poll_closed',
                    ),
                    _toggle(
                      'New followers',
                      'notify_new_followers',
                    ),
                    _toggle(
                      'Chat messages',
                      'notify_chat_messages',
                    ),
                    _toggle(
                      'Community project activity',
                      'notify_project_activity',
                    ),
                    _toggle(
                      'Repository files and links',
                      'notify_repository_activity',
                    ),
                    _toggle(
                      'Workshop files and links',
                      'notify_workshop_activity',
                    ),
                    const Divider(height: 32),
                    SwitchListTile(
                      title: const Text('Push notifications (permission)'),
                      subtitle: const Text(
                        'Alerts when the app is in the background or closed.',
                      ),
                      value: _b('push_enabled', defaultValue: false),
                      onChanged: (v) async {
                        if (v) {
                          await _requestPush();
                        } else {
                          await PushNotificationService.disableRemotePush();
                          await _load();
                        }
                      },
                    ),
                  ],
                ),
    );
  }

  Widget _toggle(String label, String key) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: _b(key),
      onChanged: (v) => _patch(key, v),
    );
  }
}
