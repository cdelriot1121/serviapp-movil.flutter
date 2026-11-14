import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Configuración del proyecto de Firebase "serviapp-6e524" (la misma de
/// android/app/google-services.json). Estos datos identifican la app ante
/// Firebase y viajan dentro del APK: no son secretos.
///
/// Solo Android por ahora; para iOS hay que registrar la app en Firebase.
class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return null;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDQMPOZl9mkNpJGETPFhtC9mEVNKebVeWI',
    appId: '1:604437131574:android:b6b64ce6c222bce2ae4397',
    messagingSenderId: '604437131574',
    projectId: 'serviapp-6e524',
    storageBucket: 'serviapp-6e524.firebasestorage.app',
  );
}
