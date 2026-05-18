import 'package:cap/firebase_options.dart';
import 'package:cap/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!DefaultFirebaseOptions.isConfigured) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint(
        'PushNotificationService: Firebase not configured (run flutterfire configure).',
      );
      return;
    }
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
        await _persistToken(t);
      });
      _initialized = true;
    } catch (e, st) {
      debugPrint('PushNotificationService: init failed: $e\n$st');
    }
  }

  static Future<void> _persistToken(String? token) async {
    if (token == null || token.isEmpty) return;
    if (Supabase.instance.client.auth.currentUser == null) return;
    try {
      await NotificationService().setFcmToken(token);
    } catch (e) {
      debugPrint('PushNotificationService: failed to save FCM token: $e');
    }
  }

  static Future<void> registerAfterUserOptIn() async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    final perm = await Permission.notification.request();
    final granted = perm.isGranted || perm.isLimited;
    await NotificationService().setPushEnabled(granted);
    if (!granted) return;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        await NotificationService().setPushEnabled(false);
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      await _persistToken(token);
    } catch (e) {
      debugPrint('PushNotificationService: register failed: $e');
    }
  }

  static Future<void> syncTokenIfAllowed() async {
    if (!_initialized) await initialize();
    if (!_initialized) return;
    if (Supabase.instance.client.auth.currentUser == null) return;

    final perm = await Permission.notification.status;
    if (!perm.isGranted && !perm.isLimited) return;

    final settings = await NotificationService().getSettings();
    if (settings != null && settings['push_enabled'] != true) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      await _persistToken(token);
    } catch (e) {
      debugPrint('PushNotificationService: sync token failed: $e');
    }
  }

  static Future<void> clearForLogout() async {
    try {
      await NotificationService().setFcmToken(null);
    } catch (_) { /* ignored */ }
    if (!_initialized) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) { /* ignored */ }
  }

  static Future<void> disableRemotePush() async {
    await NotificationService().setPushEnabled(false);
    try {
      await NotificationService().setFcmToken(null);
    } catch (_) { /* ignored */ }
    if (!_initialized) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) { /* ignored */ }
  }
}
