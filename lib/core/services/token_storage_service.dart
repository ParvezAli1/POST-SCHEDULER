import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/social_platform.dart';

class StoredOAuthSession {
  const StoredOAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.handle,
    required this.isRealAuth,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String handle;
  final bool isRealAuth;
}

class StoredLoginCredentials {
  const StoredLoginCredentials({
    required this.email,
    required this.passwordHash,
  });

  final String email;
  final String passwordHash;
}

class TokenStorageService {
  TokenStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;
  static const String _biometricRequiredKey = 'publishing_biometric_required';
  static const String _loginCredentialsKey = 'local_login_credentials';

  Future<void> saveSession(
    SocialPlatform platform, {
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
    required String handle,
    required bool isRealAuth,
  }) async {
    final key = _keyFor(platform);
    final payload = jsonEncode({
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt.toIso8601String(),
      'handle': handle,
      'isRealAuth': isRealAuth,
    });

    await _storage.write(key: key, value: payload);
  }

  Future<void> clearSession(SocialPlatform platform) async {
    await _storage.delete(key: _keyFor(platform));
  }

  Future<Map<SocialPlatform, StoredOAuthSession>> readAllSessions() async {
    final result = <SocialPlatform, StoredOAuthSession>{};

    for (final platform in SocialPlatform.values) {
      final raw = await _storage.read(key: _keyFor(platform));
      if (raw == null || raw.isEmpty) {
        continue;
      }

      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final accessToken = decoded['accessToken'] as String?;
        final refreshToken = decoded['refreshToken'] as String?;
        final expiresAtRaw = decoded['expiresAt'] as String?;
        final handle = decoded['handle'] as String?;
        final isRealAuth = decoded['isRealAuth'];

        if (accessToken == null ||
            refreshToken == null ||
            expiresAtRaw == null ||
            handle == null) {
          continue;
        }

        final expiresAt = DateTime.tryParse(expiresAtRaw);
        if (expiresAt == null) {
          continue;
        }

        result[platform] = StoredOAuthSession(
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiresAt: expiresAt,
          handle: handle,
          isRealAuth: isRealAuth == true,
        );
      } catch (_) {
        // Ignore malformed records and keep booting with valid entries.
      }
    }

    return result;
  }

  Future<void> saveBiometricRequired(bool value) async {
    await _storage.write(key: _biometricRequiredKey, value: value.toString());
  }

  Future<bool> readBiometricRequired({bool defaultValue = true}) async {
    final raw = await _storage.read(key: _biometricRequiredKey);
    if (raw == null) {
      return defaultValue;
    }

    return raw.toLowerCase() == 'true';
  }

  Future<void> saveLoginCredentials({
    required String email,
    required String passwordHash,
  }) async {
    final payload = jsonEncode({'email': email, 'passwordHash': passwordHash});
    await _storage.write(key: _loginCredentialsKey, value: payload);
  }

  Future<StoredLoginCredentials?> readLoginCredentials() async {
    final raw = await _storage.read(key: _loginCredentialsKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final email = decoded['email'] as String?;
      final passwordHash = decoded['passwordHash'] as String?;
      if (email == null || passwordHash == null) {
        return null;
      }

      return StoredLoginCredentials(email: email, passwordHash: passwordHash);
    } catch (_) {
      return null;
    }
  }

  String _keyFor(SocialPlatform platform) => 'oauth_session_${platform.name}';
}
