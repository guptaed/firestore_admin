import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for android',
        );
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios',
        );
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Web configuration - used as base for desktop platforms
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCgNNxTCWmAuygURSFYpOzbdz9ZfEOP-LI',
    appId: '1:490924808031:web:c3276a58bb7458decac8ea',
    messagingSenderId: '490924808031',
    projectId: 'vietfuelprocapp',
    authDomain: 'vietfuelprocapp.firebaseapp.com',
    storageBucket: 'vietfuelprocapp.firebasestorage.app',
  );

  // Windows uses the same config as web for Firestore access
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCgNNxTCWmAuygURSFYpOzbdz9ZfEOP-LI',
    appId: '1:490924808031:web:c3276a58bb7458decac8ea',
    messagingSenderId: '490924808031',
    projectId: 'vietfuelprocapp',
    authDomain: 'vietfuelprocapp.firebaseapp.com',
    storageBucket: 'vietfuelprocapp.firebasestorage.app',
  );

  // macOS uses the same config as web for Firestore access
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCgNNxTCWmAuygURSFYpOzbdz9ZfEOP-LI',
    appId: '1:490924808031:web:c3276a58bb7458decac8ea',
    messagingSenderId: '490924808031',
    projectId: 'vietfuelprocapp',
    authDomain: 'vietfuelprocapp.firebaseapp.com',
    storageBucket: 'vietfuelprocapp.firebasestorage.app',
  );

  // Linux uses the same config as web for Firestore access
  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyCgNNxTCWmAuygURSFYpOzbdz9ZfEOP-LI',
    appId: '1:490924808031:web:c3276a58bb7458decac8ea',
    messagingSenderId: '490924808031',
    projectId: 'vietfuelprocapp',
    authDomain: 'vietfuelprocapp.firebaseapp.com',
    storageBucket: 'vietfuelprocapp.firebasestorage.app',
  );
}
