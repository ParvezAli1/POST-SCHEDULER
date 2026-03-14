import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/models/social_account.dart';
import '../../../core/models/social_platform.dart';
import '../../../core/services/biometric_auth_service.dart';
import '../../../core/services/oauth_service.dart';
import '../../../core/services/token_storage_service.dart';

class AuthRepository {
  AuthRepository() {
    accountsNotifier = ValueNotifier<List<SocialAccount>>(_seedAccounts());
    biometricRequiredNotifier = ValueNotifier<bool>(true);
    authenticatedNotifier = ValueNotifier<bool>(false);
    _rehydrateFromSecureStorage();
    _loadBiometricPreference();
    _listenToFirebaseAuth();
  }

  late final ValueNotifier<List<SocialAccount>> accountsNotifier;
  late final ValueNotifier<bool> biometricRequiredNotifier;
  late final ValueNotifier<bool> authenticatedNotifier;
  final OAuthService _oauthService = OAuthService();
  final TokenStorageService _tokenStorageService = TokenStorageService();
  final BiometricAuthService _biometricAuthService = BiometricAuthService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  FirebaseAuth? get _firebaseAuth =>
      Firebase.apps.isNotEmpty ? FirebaseAuth.instance : null;
  DateTime? _lastBiometricUnlockAt;
  StreamSubscription<User?>? _authSubscription;

  static const Duration _biometricUnlockTtl = Duration(minutes: 2);

  List<SocialAccount> get accounts => accountsNotifier.value;

  Future<bool> login({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();
    if (!_isValidEmail(normalizedEmail) || normalizedPassword.isEmpty) {
      return false;
    }

    final firebaseAuth = _firebaseAuth;
    if (firebaseAuth != null) {
      try {
        await firebaseAuth.signInWithEmailAndPassword(
          email: normalizedEmail,
          password: normalizedPassword,
        );
        authenticatedNotifier.value = true;
        return true;
      } on FirebaseAuthException catch (error) {
        // If provider is not enabled yet in Firebase, preserve app usability.
        if (error.code == 'operation-not-allowed') {
          return _loginWithLocal(
            email: normalizedEmail,
            password: normalizedPassword,
          );
        }
        return false;
      } catch (_) {
        return false;
      }
    }

    return _loginWithLocal(
      email: normalizedEmail,
      password: normalizedPassword,
    );
  }

  Future<bool> signup({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();
    if (!_isValidEmail(normalizedEmail) || normalizedPassword.length < 6) {
      return false;
    }

    final firebaseAuth = _firebaseAuth;
    if (firebaseAuth != null) {
      try {
        await firebaseAuth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: normalizedPassword,
        );
        await firebaseAuth.signOut();
        authenticatedNotifier.value = false;
        return true;
      } on FirebaseAuthException catch (error) {
        // If provider is not enabled yet in Firebase, preserve app usability.
        if (error.code == 'operation-not-allowed') {
          return _signupWithLocal(
            email: normalizedEmail,
            password: normalizedPassword,
          );
        }
        return false;
      } catch (_) {
        return false;
      }
    }

    return _signupWithLocal(
      email: normalizedEmail,
      password: normalizedPassword,
    );
  }

  Future<bool> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return false;
      }

      final firebaseAuth = _firebaseAuth;
      if (firebaseAuth != null) {
        final auth = await account.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: auth.accessToken,
          idToken: auth.idToken,
        );
        await firebaseAuth.signInWithCredential(credential);
      }

      authenticatedNotifier.value = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail({required String email}) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!_isValidEmail(normalizedEmail)) {
      return false;
    }

    final firebaseAuth = _firebaseAuth;
    if (firebaseAuth != null) {
      try {
        await firebaseAuth.sendPasswordResetEmail(email: normalizedEmail);
        return true;
      } on FirebaseAuthException {
        return false;
      } catch (_) {
        return false;
      }
    }

    // Placeholder reset flow until backend auth provider is connected.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return true;
  }

  void logout() {
    final firebaseAuth = _firebaseAuth;
    if (firebaseAuth != null) {
      firebaseAuth.signOut();
    }
    authenticatedNotifier.value = false;
    _lastBiometricUnlockAt = null;
  }

  void _listenToFirebaseAuth() {
    final firebaseAuth = _firebaseAuth;
    if (firebaseAuth == null) {
      return;
    }

    authenticatedNotifier.value = firebaseAuth.currentUser != null;
    _authSubscription?.cancel();
    _authSubscription = firebaseAuth.authStateChanges().listen((user) {
      authenticatedNotifier.value = user != null;
    });
  }

  Future<void> connectWithOAuth(SocialPlatform platform) async {
    final account = _accountFor(platform);
    if (account == null) {
      return;
    }

    final tokens = await _oauthService.connect(
      platform,
      handle: account.handle,
    );

    _replaceAccount(
      account.copyWith(
        connected: true,
        isRealAuth: tokens.isRealAuth,
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        accessTokenExpiresAt: tokens.expiresAt,
        handle: tokens.handle,
      ),
    );

    await _tokenStorageService.saveSession(
      platform,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresAt: tokens.expiresAt,
      handle: tokens.handle,
      isRealAuth: tokens.isRealAuth,
    );
  }

  Future<void> disconnect(SocialPlatform platform) async {
    final account = _accountFor(platform);
    if (account == null) {
      return;
    }

    _replaceAccount(account.copyWith(connected: false, clearTokens: true));
    await _tokenStorageService.clearSession(platform);
  }

  Future<bool> refreshAccessTokenIfNeeded(SocialPlatform platform) async {
    final account = _accountFor(platform);
    if (account == null || !account.connected) {
      return false;
    }

    final expiresAt = account.accessTokenExpiresAt;
    if (account.accessToken != null &&
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
      return true;
    }

    final refreshToken = account.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final refreshed = await _oauthService.refresh(
      platform,
      refreshToken: refreshToken,
      handle: account.handle,
    );

    if (refreshed == null) {
      return false;
    }

    _replaceAccount(
      account.copyWith(
        isRealAuth: refreshed.isRealAuth,
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken,
        accessTokenExpiresAt: refreshed.expiresAt,
        handle: refreshed.handle,
      ),
    );

    await _tokenStorageService.saveSession(
      platform,
      accessToken: refreshed.accessToken,
      refreshToken: refreshed.refreshToken,
      expiresAt: refreshed.expiresAt,
      handle: refreshed.handle,
      isRealAuth: refreshed.isRealAuth,
    );

    return true;
  }

  Future<String?> resolveAccessToken(SocialPlatform platform) async {
    final authorized = await authorizePublishingWithBiometrics();
    if (!authorized) {
      return null;
    }

    await refreshAccessTokenIfNeeded(platform);
    return _accountFor(platform)?.accessToken;
  }

  Future<bool> authorizePublishingWithBiometrics() async {
    if (!biometricRequiredNotifier.value) {
      return true;
    }

    final unlockedAt = _lastBiometricUnlockAt;
    if (unlockedAt != null &&
        DateTime.now().difference(unlockedAt) < _biometricUnlockTtl) {
      return true;
    }

    final authenticated = await _biometricAuthService
        .authenticateForPublishing();
    if (authenticated) {
      _lastBiometricUnlockAt = DateTime.now();
      return true;
    }

    return false;
  }

  Future<void> setBiometricRequiredForPublishing(bool required) async {
    biometricRequiredNotifier.value = required;
    await _tokenStorageService.saveBiometricRequired(required);
    if (!required) {
      _lastBiometricUnlockAt = null;
    }
  }

  Future<void> toggleConnection(SocialPlatform platform) async {
    final account = _accountFor(platform);
    if (account == null) {
      return;
    }

    if (account.connected) {
      await disconnect(platform);
      return;
    }

    await connectWithOAuth(platform);
  }

  Future<void> _rehydrateFromSecureStorage() async {
    final sessions = await _tokenStorageService.readAllSessions();
    if (sessions.isEmpty) {
      return;
    }

    final updated = accounts.map((account) {
      final session = sessions[account.platform];
      if (session == null) {
        return account;
      }

      return account.copyWith(
        connected: true,
        isRealAuth: session.isRealAuth,
        handle: session.handle,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        accessTokenExpiresAt: session.expiresAt,
      );
    }).toList();

    accountsNotifier.value = updated;
  }

  Future<void> _loadBiometricPreference() async {
    final required = await _tokenStorageService.readBiometricRequired(
      defaultValue: true,
    );
    biometricRequiredNotifier.value = required;
  }

  SocialAccount? _accountFor(SocialPlatform platform) {
    for (final account in accounts) {
      if (account.platform == platform) {
        return account;
      }
    }
    return null;
  }

  void _replaceAccount(SocialAccount nextAccount) {
    final updated = accounts.map((account) {
      if (account.platform == nextAccount.platform) {
        return nextAccount;
      }
      return account;
    }).toList();

    accountsNotifier.value = updated;
  }

  List<SocialAccount> _seedAccounts() {
    return SocialPlatform.values
        .map(
          (platform) => SocialAccount(
            platform: platform,
            handle: platform.handleHint,
            connected:
                platform == SocialPlatform.instagram ||
                platform == SocialPlatform.linkedin,
          ),
        )
        .toList();
  }

  bool _isValidEmail(String email) {
    final normalized = email.trim();
    return normalized.contains('@') && normalized.contains('.');
  }

  String _hashPassword(String password) {
    return sha256.convert(password.codeUnits).toString();
  }

  Future<bool> _loginWithLocal({
    required String email,
    required String password,
  }) async {
    final stored = await _tokenStorageService.readLoginCredentials();
    if (stored == null) {
      return false;
    }

    if (stored.email != email) {
      return false;
    }

    if (stored.passwordHash != _hashPassword(password)) {
      return false;
    }

    authenticatedNotifier.value = true;
    return true;
  }

  Future<bool> _signupWithLocal({
    required String email,
    required String password,
  }) async {
    await _tokenStorageService.saveLoginCredentials(
      email: email,
      passwordHash: _hashPassword(password),
    );
    authenticatedNotifier.value = false;
    return true;
  }
}
