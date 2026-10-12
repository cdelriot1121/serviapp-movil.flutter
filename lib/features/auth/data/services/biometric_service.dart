import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Credenciales guardadas para el inicio de sesión con huella.
class SavedCredentials {
  final String email;
  final String password;

  const SavedCredentials({
    required this.email,
    required this.password,
  });
}

/// Maneja el inicio de sesión con huella / rostro.
///
/// Las credenciales se guardan cifradas en el Keystore (Android) o
/// Keychain (iOS) y solo se leen después de que el usuario se
/// autentica con su biometría.
class BiometricService {
  static const _emailKey = 'biometric_email';
  static const _passwordKey = 'biometric_password';

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Indica si el dispositivo tiene huella/rostro registrado.
  Future<bool> isAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;

      final biometrics = await _localAuth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  /// Indica si el usuario ya activó el inicio con huella.
  Future<bool> isEnabled() async {
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    return email != null && password != null;
  }

  /// Guarda las credenciales para usarlas con la huella.
  Future<void> enable({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _passwordKey, value: password);
  }

  /// Borra las credenciales guardadas.
  Future<void> disable() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }

  /// Pide la huella y, si es correcta, devuelve las credenciales.
  /// Devuelve null si el usuario cancela o la huella no coincide.
  Future<SavedCredentials?> authenticate() async {
    final ok = await _pedirHuella('Usa tu huella para entrar a ServiApp');
    if (!ok) return null;

    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);

    if (email == null || password == null) return null;

    return SavedCredentials(email: email, password: password);
  }

  /// Pide la huella solo para confirmar que es el dueño del celular.
  Future<bool> confirmIdentity() {
    return _pedirHuella('Confirma tu huella para activarla en ServiApp');
  }

  Future<bool> _pedirHuella(String motivo) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: motivo,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      if (e.code == LocalAuthExceptionCode.userCanceled ||
          e.code == LocalAuthExceptionCode.systemCanceled ||
          e.code == LocalAuthExceptionCode.timeout ||
          e.code == LocalAuthExceptionCode.userRequestedFallback) {
        return false;
      }

      if (e.code == LocalAuthExceptionCode.temporaryLockout ||
          e.code == LocalAuthExceptionCode.biometricLockout) {
        throw Exception(
          'Demasiados intentos con la huella. Ingresa con tu contraseña.',
        );
      }

      throw Exception(
        'No fue posible usar la huella. Ingresa con tu contraseña.',
      );
    } on PlatformException {
      throw Exception(
        'No fue posible usar la huella. Ingresa con tu contraseña.',
      );
    }
  }
}
