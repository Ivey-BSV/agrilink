import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const String _placeholder = 'REPLACE_ME';

  static bool get isConfigured {
    if (kIsWeb) return web.appId != _placeholder;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return true;
      case TargetPlatform.iOS:
        return ios.appId != _placeholder;
      default:
        return false;
    }
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      if (!isConfigured) {
        throw UnsupportedError(
          'Firebase web not configured. Register a web app in the ivey-cap '
          'Firebase Console, then paste the appId into web.appId below.',
        );
      }
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        if (!isConfigured) {
          throw UnsupportedError(
            'Firebase iOS not configured. Register the iOS app (bundle: '
            'com.ansel.cap) in the ivey-cap Firebase Console, download '
            'GoogleService-Info.plist, and paste the GOOGLE_APP_ID value '
            'into ios.appId below.',
          );
        }
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Android is fully configured — google-services.json is in android/app/.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCehm_NORJwQd-SVeuOxtzKdLsjnRcHNe0',
    appId: '1:632705951068:android:e356017bb29b8d6555cd99',
    messagingSenderId: '632705951068',
    projectId: 'ivey-cap',
    storageBucket: 'ivey-cap.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAtVMn0CCpO4jfO4_LuafFoQBhsHq3DWSI',
    appId: '1:632705951068:ios:61f4499742e8728755cd99',
    messagingSenderId: '632705951068',
    projectId: 'ivey-cap',
    storageBucket: 'ivey-cap.firebasestorage.app',
    iosBundleId: 'com.ansel.cap',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBhjDg-AOeNJxM8ylhf0yXxuzn6svmeaO0',
    appId: '1:632705951068:web:03c2c0084f7d05d055cd99',
    messagingSenderId: '632705951068',
    projectId: 'ivey-cap',
    storageBucket: 'ivey-cap.firebasestorage.app',
    authDomain: 'ivey-cap.firebaseapp.com',
    measurementId: 'G-NSETNNS5QV',
  );
}
