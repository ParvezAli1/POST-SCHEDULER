import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../models/social_platform.dart';

class OAuthTokens {
  const OAuthTokens({
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

class OAuthService {
  Future<OAuthTokens> connect(
    SocialPlatform platform, {
    required String handle,
  }) async {
    final config = _configFor(platform);
    final hasInteractiveConfig =
        config.authUrl.isNotEmpty &&
        config.tokenUrl.isNotEmpty &&
        config.clientId.isNotEmpty &&
        config.redirectUri.isNotEmpty;

    final interactive = await _connectInteractive(
      platform: platform,
      config: config,
      handle: handle,
    );
    if (interactive != null) {
      return interactive;
    }

    if (hasInteractiveConfig) {
      return _mockTokens(platform, handle);
    }

    if (config.tokenUrl.isEmpty ||
        config.clientId.isEmpty ||
        config.clientSecret.isEmpty) {
      return _mockTokens(platform, handle);
    }

    final uri = Uri.tryParse(config.tokenUrl);
    if (uri == null) {
      return _mockTokens(platform, handle);
    }

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'grant_type': 'client_credentials',
              'client_id': config.clientId,
              'client_secret': config.clientSecret,
              'scope': config.scope,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _mockTokens(platform, handle);
      }

      final payload = jsonDecode(response.body);
      final accessToken = payload['access_token'] as String?;
      final refreshToken = payload['refresh_token'] as String?;
      final expiresIn = payload['expires_in'] as int?;

      if (accessToken == null || accessToken.isEmpty) {
        return _mockTokens(platform, handle);
      }

      final resolvedHandle = await _resolveConnectedHandle(
        platform: platform,
        accessToken: accessToken,
        fallbackHandle: handle,
        config: config,
      );

      return OAuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken ?? _fakeToken(prefix: 'refresh'),
        expiresAt: DateTime.now().add(Duration(seconds: expiresIn ?? 3600)),
        handle: resolvedHandle,
        isRealAuth: true,
      );
    } catch (_) {
      return _mockTokens(platform, handle);
    }
  }

  Future<OAuthTokens?> _connectInteractive({
    required SocialPlatform platform,
    required _OAuthConfig config,
    required String handle,
  }) async {
    if (config.authUrl.isEmpty ||
        config.tokenUrl.isEmpty ||
        config.clientId.isEmpty ||
        config.redirectUri.isEmpty) {
      return null;
    }

    final authUriBase = Uri.tryParse(config.authUrl);
    final tokenUri = Uri.tryParse(config.tokenUrl);
    final redirectUri = Uri.tryParse(config.redirectUri);
    if (authUriBase == null || tokenUri == null || redirectUri == null) {
      return null;
    }

    final state = _randomString(24);
    final codeVerifier = _randomString(64);
    final codeChallenge = _buildCodeChallenge(codeVerifier);
    final authUri = authUriBase.replace(
      queryParameters: {
        ...authUriBase.queryParameters,
        'response_type': 'code',
        'client_id': config.clientId,
        'redirect_uri': config.redirectUri,
        if (config.scope.isNotEmpty) 'scope': config.scope,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'state': state,
      },
    );

    try {
      final resultUrl = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: redirectUri.scheme,
      );

      final callbackUri = Uri.parse(resultUrl);
      final callbackState = callbackUri.queryParameters['state'];
      if (callbackState != null && callbackState != state) {
        return null;
      }

      final code = callbackUri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        return null;
      }

      final tokenResponse = await http
          .post(
            tokenUri,
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'grant_type': 'authorization_code',
              'code': code,
              'redirect_uri': config.redirectUri,
              'client_id': config.clientId,
              'code_verifier': codeVerifier,
              if (config.clientSecret.isNotEmpty)
                'client_secret': config.clientSecret,
            },
          )
          .timeout(const Duration(seconds: 25));

      if (tokenResponse.statusCode < 200 || tokenResponse.statusCode >= 300) {
        return null;
      }

      final payload = _tryDecodeMap(tokenResponse.body);
      final accessToken = payload?['access_token'] as String?;
      final refreshToken = payload?['refresh_token'] as String?;
      final expiresIn = payload?['expires_in'];
      final expiresInSeconds = expiresIn is int
          ? expiresIn
          : int.tryParse(expiresIn?.toString() ?? '');

      if (accessToken == null || accessToken.isEmpty) {
        return null;
      }

      final resolvedHandle = await _resolveConnectedHandle(
        platform: platform,
        accessToken: accessToken,
        fallbackHandle: handle,
        config: config,
      );

      return OAuthTokens(
        accessToken: accessToken,
        refreshToken:
            refreshToken ?? _fakeToken(prefix: '${platform.name}_refresh'),
        expiresAt: DateTime.now().add(
          Duration(seconds: expiresInSeconds ?? 3600),
        ),
        handle: resolvedHandle,
        isRealAuth: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<OAuthTokens?> refresh(
    SocialPlatform platform, {
    required String refreshToken,
    required String handle,
  }) async {
    final config = _configFor(platform);

    if (refreshToken.isEmpty) {
      return null;
    }

    if (config.refreshUrl.isEmpty && config.tokenUrl.isEmpty) {
      return OAuthTokens(
        accessToken: _fakeToken(prefix: 'access'),
        refreshToken: refreshToken,
        expiresAt: DateTime.now().add(const Duration(minutes: 55)),
        handle: handle,
        isRealAuth: false,
      );
    }

    final refreshUrl = config.refreshUrl.isNotEmpty
        ? config.refreshUrl
        : config.tokenUrl;
    final uri = Uri.tryParse(refreshUrl);
    if (uri == null) {
      return null;
    }

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'grant_type': 'refresh_token',
              'refresh_token': refreshToken,
              'client_id': config.clientId,
              if (config.clientSecret.isNotEmpty)
                'client_secret': config.clientSecret,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final payload = jsonDecode(response.body);
      final accessToken = payload['access_token'] as String?;
      final nextRefreshToken = payload['refresh_token'] as String?;
      final expiresIn = payload['expires_in'] as int?;

      if (accessToken == null || accessToken.isEmpty) {
        return null;
      }

      return OAuthTokens(
        accessToken: accessToken,
        refreshToken: nextRefreshToken ?? refreshToken,
        expiresAt: DateTime.now().add(Duration(seconds: expiresIn ?? 3600)),
        handle: handle,
        isRealAuth: true,
      );
    } catch (_) {
      return null;
    }
  }

  OAuthTokens _mockTokens(SocialPlatform platform, String handle) {
    return OAuthTokens(
      accessToken: _fakeToken(prefix: '${platform.name}_access'),
      refreshToken: _fakeToken(prefix: '${platform.name}_refresh'),
      expiresAt: DateTime.now().add(const Duration(minutes: 55)),
      handle: handle,
      isRealAuth: false,
    );
  }

  Map<String, dynamic>? _tryDecodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String> _resolveConnectedHandle({
    required SocialPlatform platform,
    required String accessToken,
    required String fallbackHandle,
    required _OAuthConfig config,
  }) async {
    final profileUri = _profileUriFor(platform, config);
    if (profileUri == null) {
      return fallbackHandle;
    }

    try {
      final response = await http
          .get(
            profileUri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return fallbackHandle;
      }

      final payload = _tryDecodeMap(response.body);
      if (payload == null) {
        return fallbackHandle;
      }

      final extracted = _extractHandle(payload);
      if (extracted == null || extracted.isEmpty) {
        return fallbackHandle;
      }

      return extracted;
    } catch (_) {
      return fallbackHandle;
    }
  }

  Uri? _profileUriFor(SocialPlatform platform, _OAuthConfig config) {
    if (config.profileUrl.isNotEmpty) {
      return Uri.tryParse(config.profileUrl);
    }

    switch (platform) {
      case SocialPlatform.instagram:
        return Uri.tryParse(
          'https://graph.instagram.com/me?fields=id,username',
        );
      case SocialPlatform.facebook:
        return Uri.tryParse('https://graph.facebook.com/me?fields=id,name');
      case SocialPlatform.x:
        return Uri.tryParse('https://api.x.com/2/users/me');
      case SocialPlatform.threads:
        return Uri.tryParse('https://graph.threads.net/me?fields=id,username');
      case SocialPlatform.linkedin:
        return Uri.tryParse('https://api.linkedin.com/v2/userinfo');
    }
  }

  String? _extractHandle(Map<String, dynamic> payload) {
    final direct = _pickString(payload, const [
      'username',
      'name',
      'screen_name',
      'handle',
      'preferred_username',
      'preferredUsername',
      'localizedFirstName',
      'given_name',
      'sub',
    ]);
    if (direct != null) {
      return direct;
    }

    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      final nested = _extractHandle(data);
      if (nested != null) {
        return nested;
      }
    }

    final user = payload['user'];
    if (user is Map<String, dynamic>) {
      final nested = _extractHandle(user);
      if (nested != null) {
        return nested;
      }
    }

    final first = _pickString(payload, const [
      'localizedFirstName',
      'given_name',
    ]);
    final last = _pickString(payload, const [
      'localizedLastName',
      'family_name',
    ]);
    if (first != null && last != null) {
      return '$first $last';
    }
    if (first != null) {
      return first;
    }

    return null;
  }

  String? _pickString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  _OAuthConfig _configFor(SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.instagram:
        return const _OAuthConfig(
          authUrl: String.fromEnvironment('SOCIAL_INSTAGRAM_OAUTH_AUTH_URL'),
          tokenUrl: String.fromEnvironment('SOCIAL_INSTAGRAM_OAUTH_TOKEN_URL'),
          refreshUrl: String.fromEnvironment(
            'SOCIAL_INSTAGRAM_OAUTH_REFRESH_URL',
          ),
          redirectUri: String.fromEnvironment(
            'SOCIAL_INSTAGRAM_OAUTH_REDIRECT_URI',
            defaultValue: 'postscheduler://oauth',
          ),
          profileUrl: String.fromEnvironment(
            'SOCIAL_INSTAGRAM_OAUTH_PROFILE_URL',
          ),
          clientId: String.fromEnvironment('SOCIAL_INSTAGRAM_CLIENT_ID'),
          clientSecret: String.fromEnvironment(
            'SOCIAL_INSTAGRAM_CLIENT_SECRET',
          ),
          scope: 'basic',
        );
      case SocialPlatform.facebook:
        return const _OAuthConfig(
          authUrl: String.fromEnvironment('SOCIAL_FACEBOOK_OAUTH_AUTH_URL'),
          tokenUrl: String.fromEnvironment('SOCIAL_FACEBOOK_OAUTH_TOKEN_URL'),
          refreshUrl: String.fromEnvironment(
            'SOCIAL_FACEBOOK_OAUTH_REFRESH_URL',
          ),
          redirectUri: String.fromEnvironment(
            'SOCIAL_FACEBOOK_OAUTH_REDIRECT_URI',
            defaultValue: 'postscheduler://oauth',
          ),
          profileUrl: String.fromEnvironment(
            'SOCIAL_FACEBOOK_OAUTH_PROFILE_URL',
          ),
          clientId: String.fromEnvironment('SOCIAL_FACEBOOK_CLIENT_ID'),
          clientSecret: String.fromEnvironment('SOCIAL_FACEBOOK_CLIENT_SECRET'),
          scope: 'pages_manage_posts',
        );
      case SocialPlatform.x:
        return const _OAuthConfig(
          authUrl: String.fromEnvironment('SOCIAL_X_OAUTH_AUTH_URL'),
          tokenUrl: String.fromEnvironment('SOCIAL_X_OAUTH_TOKEN_URL'),
          refreshUrl: String.fromEnvironment('SOCIAL_X_OAUTH_REFRESH_URL'),
          redirectUri: String.fromEnvironment(
            'SOCIAL_X_OAUTH_REDIRECT_URI',
            defaultValue: 'postscheduler://oauth',
          ),
          profileUrl: String.fromEnvironment('SOCIAL_X_OAUTH_PROFILE_URL'),
          clientId: String.fromEnvironment('SOCIAL_X_CLIENT_ID'),
          clientSecret: String.fromEnvironment('SOCIAL_X_CLIENT_SECRET'),
          scope: 'tweet.write',
        );
      case SocialPlatform.threads:
        return const _OAuthConfig(
          authUrl: String.fromEnvironment('SOCIAL_THREADS_OAUTH_AUTH_URL'),
          tokenUrl: String.fromEnvironment('SOCIAL_THREADS_OAUTH_TOKEN_URL'),
          refreshUrl: String.fromEnvironment(
            'SOCIAL_THREADS_OAUTH_REFRESH_URL',
          ),
          redirectUri: String.fromEnvironment(
            'SOCIAL_THREADS_OAUTH_REDIRECT_URI',
            defaultValue: 'postscheduler://oauth',
          ),
          profileUrl: String.fromEnvironment(
            'SOCIAL_THREADS_OAUTH_PROFILE_URL',
          ),
          clientId: String.fromEnvironment('SOCIAL_THREADS_CLIENT_ID'),
          clientSecret: String.fromEnvironment('SOCIAL_THREADS_CLIENT_SECRET'),
          scope: 'threads_basic',
        );
      case SocialPlatform.linkedin:
        return const _OAuthConfig(
          authUrl: String.fromEnvironment('SOCIAL_LINKEDIN_OAUTH_AUTH_URL'),
          tokenUrl: String.fromEnvironment('SOCIAL_LINKEDIN_OAUTH_TOKEN_URL'),
          refreshUrl: String.fromEnvironment(
            'SOCIAL_LINKEDIN_OAUTH_REFRESH_URL',
          ),
          redirectUri: String.fromEnvironment(
            'SOCIAL_LINKEDIN_OAUTH_REDIRECT_URI',
            defaultValue: 'postscheduler://oauth',
          ),
          profileUrl: String.fromEnvironment(
            'SOCIAL_LINKEDIN_OAUTH_PROFILE_URL',
          ),
          clientId: String.fromEnvironment('SOCIAL_LINKEDIN_CLIENT_ID'),
          clientSecret: String.fromEnvironment('SOCIAL_LINKEDIN_CLIENT_SECRET'),
          scope: 'w_member_social',
        );
    }
  }

  String _fakeToken({required String prefix}) {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix = List.generate(
      20,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    return '${prefix}_$suffix';
  }

  String _randomString(int length) {
    final random = Random();
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _buildCodeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}

class _OAuthConfig {
  const _OAuthConfig({
    required this.authUrl,
    required this.tokenUrl,
    required this.refreshUrl,
    required this.redirectUri,
    required this.profileUrl,
    required this.clientId,
    required this.clientSecret,
    required this.scope,
  });

  final String authUrl;
  final String tokenUrl;
  final String refreshUrl;
  final String redirectUri;
  final String profileUrl;
  final String clientId;
  final String clientSecret;
  final String scope;
}
