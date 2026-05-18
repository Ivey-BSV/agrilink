import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const String _iosAppIdPlaceholder = 'REPLACE_ME_IOS_APP_ID';

  static bool get isConfigured {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return true;
      case TargetPlatform.iOS:
        return ios.appId != _iosAppIdPlaceholder;
      default:
        return false;
    }
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('FCM is not set up for web in this app.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCehm_NORJwQd-SVeuOxtzKdLsjnRcHNe0',
    appId: '1:632705951068:android:e356017bb29b8d6555cd99',
    messagingSenderId: '632705951068',
    projectId: 'ivey-cap',
    storageBucket: 'ivey-cap.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCehm_NORJwQd-SVeuOxtzKdLsjnRcHNe0',
    appId: _iosAppIdPlaceholder,
    messagingSenderId: '632705951068',
    projectId: 'ivey-cap',
    storageBucket: 'ivey-cap.firebasestorage.app',
    iosBundleId: 'com.ansel.cap',
  );
}
