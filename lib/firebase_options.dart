import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your CampusConnect Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD4yVR5musBotSaCa18_ANJS5NnUxNvlhQ',
    appId: '1:968272670430:web:db9af89be851f5ae0ddc4f',
    messagingSenderId: '968272670430',
    projectId: 'campusconnect-486c9',
    authDomain: 'campusconnect-486c9.firebaseapp.com',
    storageBucket: 'campusconnect-486c9.firebasestorage.app',
    measurementId: 'G-8DN5DPHX97',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD4yVR5musBotSaCa18_ANJS5NnUxNvlhQ',
    appId: '1:968272670430:web:db9af89be851f5ae0ddc4f',
    messagingSenderId: '968272670430',
    projectId: 'campusconnect-486c9',
    storageBucket: 'campusconnect-486c9.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD4yVR5musBotSaCa18_ANJS5NnUxNvlhQ',
    appId: '1:968272670430:web:db9af89be851f5ae0ddc4f',
    messagingSenderId: '968272670430',
    projectId: 'campusconnect-486c9',
    storageBucket: 'campusconnect-486c9.firebasestorage.app',
    iosBundleId: 'com.campusconnect.campusConnect',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD4yVR5musBotSaCa18_ANJS5NnUxNvlhQ',
    appId: '1:968272670430:web:db9af89be851f5ae0ddc4f',
    messagingSenderId: '968272670430',
    projectId: 'campusconnect-486c9',
    storageBucket: 'campusconnect-486c9.firebasestorage.app',
    iosBundleId: 'com.campusconnect.campusConnect',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyD4yVR5musBotSaCa18_ANJS5NnUxNvlhQ',
    appId: '1:968272670430:web:db9af89be851f5ae0ddc4f',
    messagingSenderId: '968272670430',
    projectId: 'campusconnect-486c9',
    authDomain: 'campusconnect-486c9.firebaseapp.com',
    storageBucket: 'campusconnect-486c9.firebasestorage.app',
    measurementId: 'G-8DN5DPHX97',
  );
}
