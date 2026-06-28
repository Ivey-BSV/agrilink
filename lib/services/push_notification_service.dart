import 'dart:io';

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
  debugPrint('Background message: ${message.notification?.title}');
}

class PushNotificationService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint(
        'PushNotificationService: Firebase not configured for this platform.',
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

      // Foreground messages — app is open and in the foreground.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          'PushNotificationService: foreground message '
          '"${message.notification?.title}"',
        );
        // The OS does not show a notification banner when the app is in the
        // foreground on iOS unless you present it yourself.  The
        // setForegroundNotificationPresentationOptions call above handles
        // this on iOS; on Android the system notification is shown
        // automatically because we requested the channel in the manifest.
      });

      // User tapped a notification while the app was in the background
      // (not terminated).
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint(
          'PushNotificationService: app opened from background notification '
          '"${message.notification?.title}"',
        );
      });

      // App was terminated and the user tapped the notification to launch it.
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
          'PushNotificationService: launched from notification '
          '"${initialMessage.notification?.title}"',
        );
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        await _persistToken(token);
      });

      _initialized = true;
      debugPrint('PushNotificationService: initialized successfully.');
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

  static Future<bool> registerAfterUserOptIn() async {
    if (!_initialized) await initialize();
    if (!_initialized) return false;

    var granted = false;
    try {
      if (Platform.isIOS) {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        granted = settings.authorizationStatus ==
                AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      } else {
        final perm = await Permission.notification.request();
        granted = perm.isGranted || perm.isLimited;
        if (!granted) {
          await NotificationService().setPushEnabled(false);
          return false;
        }
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        granted = settings.authorizationStatus !=
            AuthorizationStatus.denied;
      }
    } catch (e) {
      debugPrint('PushNotificationService: permission request failed: $e');
    }

    await NotificationService().setPushEnabled(granted);
    if (!granted) return false;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      await _persistToken(token);
      return token != null && token.isNotEmpty;
    } catch (e) {
      debugPrint('PushNotificationService: register failed: $e');
      return false;
    }
  }

  static Future<void> openSystemNotificationSettings() async {
    await openAppSettings();
  }

  static Future<bool> _hasOsNotificationPermission() async {
    if (Platform.isIOS) {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }
    final perm = await Permission.notification.status;
    return perm.isGranted || perm.isLimited;
  }

  /// When [push_enabled] is true in Supabase but this device has not registered
  /// (no permission, missing token, or stale token from another install), fix it.
  static Future<bool> ensureRegistrationIfEnabled() async {
    if (!_initialized) await initialize();
    if (!_initialized) return false;
    if (Supabase.instance.client.auth.currentUser == null) return false;

    final settings = await NotificationService().getSettings();
    if (settings?['push_enabled'] != true) return false;

    if (!await _hasOsNotificationPermission()) {
      return registerAfterUserOptIn();
    }

    try {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        return registerAfterUserOptIn();
      }

      await _persistToken(token);
      return true;
    } catch (e) {
      debugPrint('PushNotificationService: ensure registration failed: $e');
      return false;
    }
  }

  static Future<void> syncTokenIfAllowed() async {
    await ensureRegistrationIfEnabled();
  }

  static Future<void> clearForLogout() async {
    try {
      await NotificationService().setFcmToken(null);
    } catch (_) {}
    if (!_initialized) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  static Future<void> disableRemotePush() async {
    await NotificationService().setPushEnabled(false);
    try {
      await NotificationService().setFcmToken(null);
    } catch (_) {}
    if (!_initialized) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}
