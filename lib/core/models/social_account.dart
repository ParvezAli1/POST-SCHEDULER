import 'social_platform.dart';

class SocialAccount {
  SocialAccount({
    required this.platform,
    required this.handle,
    required this.connected,
    this.isRealAuth = false,
    this.accessToken,
    this.refreshToken,
    this.accessTokenExpiresAt,
  });

  final SocialPlatform platform;
  final String handle;
  final bool connected;
  final bool isRealAuth;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? accessTokenExpiresAt;

  SocialAccount copyWith({
    String? handle,
    bool? connected,
    bool? isRealAuth,
    String? accessToken,
    String? refreshToken,
    DateTime? accessTokenExpiresAt,
    bool clearTokens = false,
  }) {
    return SocialAccount(
      platform: platform,
      handle: handle ?? this.handle,
      connected: connected ?? this.connected,
      isRealAuth: clearTokens ? false : (isRealAuth ?? this.isRealAuth),
      accessToken: clearTokens ? null : (accessToken ?? this.accessToken),
      refreshToken: clearTokens ? null : (refreshToken ?? this.refreshToken),
      accessTokenExpiresAt: clearTokens
          ? null
          : (accessTokenExpiresAt ?? this.accessTokenExpiresAt),
    );
  }
}
