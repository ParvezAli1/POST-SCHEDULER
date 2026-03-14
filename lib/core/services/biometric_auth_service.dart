import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  BiometricAuthService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  Future<bool> authenticateForPublishing() async {
    final isSupported = await _localAuth.isDeviceSupported();
    if (!isSupported) {
      return false;
    }

    final canCheckBiometrics = await _localAuth.canCheckBiometrics;
    if (!canCheckBiometrics) {
      return false;
    }

    final available = await _localAuth.getAvailableBiometrics();
    final hasFingerprint =
        available.contains(BiometricType.fingerprint) ||
        available.contains(BiometricType.strong) ||
        available.contains(BiometricType.weak);

    if (!hasFingerprint) {
      return false;
    }

    try {
      return await _localAuth.authenticate(
        localizedReason:
            'Authenticate with fingerprint to publish scheduled posts',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
