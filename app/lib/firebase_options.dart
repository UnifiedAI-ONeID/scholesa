// lib/firebase_options.dart
// Firebase configuration for Scholesa platform

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase configuration options for Scholesa.
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
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Web configuration - Scholesa Edu 2.0
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC4csH-LBRiikaAMyD5EQewcINLVrmXQbs',
    appId: '1:97120825720:web:71fa701dd5d4561f8bd88d',
    messagingSenderId: '97120825720',
    projectId: 'studio-3328096157-e3f79',
    authDomain: 'studio-3328096157-e3f79.firebaseapp.com',
    storageBucket: 'studio-3328096157-e3f79.firebasestorage.app',
  );

  // Android configuration
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCM26X4EXiP3c4uqmLiF1yqXSnRlnWRePY',
    appId: '1:97120825720:android:35db27e28bfd838d8bd88d',
    messagingSenderId: '97120825720',
    projectId: 'studio-3328096157-e3f79',
    storageBucket: 'studio-3328096157-e3f79.firebasestorage.app',
  );

  // iOS configuration
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDPClAxcvuy3hddlXjwgTGxXpL7YJOMqVM',
    appId: '1:97120825720:ios:8bf1aacba9762af78bd88d',
    messagingSenderId: '97120825720',
    projectId: 'studio-3328096157-e3f79',
    storageBucket: 'studio-3328096157-e3f79.firebasestorage.app',
    iosBundleId: 'com.scholesa.app',
  );

  // macOS configuration (uses iOS app)
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDPClAxcvuy3hddlXjwgTGxXpL7YJOMqVM',
    appId: '1:97120825720:ios:a803c68fc7a72d428bd88d',
    messagingSenderId: '97120825720',
    projectId: 'studio-3328096157-e3f79',
    storageBucket: 'studio-3328096157-e3f79.firebasestorage.app',
    iosBundleId: 'com.scholesa.app',
  );

  // Windows configuration (uses web app)
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyC4csH-LBRiikaAMyD5EQewcINLVrmXQbs',
    appId: '1:97120825720:web:0ba0ad959aafdbd38bd88d',
    messagingSenderId: '97120825720',
    projectId: 'studio-3328096157-e3f79',
    storageBucket: 'studio-3328096157-e3f79.firebasestorage.app',
  );
}
