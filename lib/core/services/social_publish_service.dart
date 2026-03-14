import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/scheduled_post.dart';
import '../models/social_platform.dart';

class PublishResult {
  const PublishResult({required this.success, required this.note});

  final bool success;
  final String note;
}

class SocialPublishService {
  SocialPublishService({
    required this.resolveAccessToken,
    required this.refreshAccessTokenIfNeeded,
  });

  final Future<String?> Function(SocialPlatform platform) resolveAccessToken;
  final Future<bool> Function(SocialPlatform platform)
  refreshAccessTokenIfNeeded;

  Future<PublishResult> publish(ScheduledPost post) async {
    final config = _configFor(post.platform);
    await refreshAccessTokenIfNeeded(post.platform);
    final oauthAccessToken = await resolveAccessToken(post.platform);
    final accessToken =
        (oauthAccessToken != null && oauthAccessToken.isNotEmpty)
        ? oauthAccessToken
        : config.accessToken;

    if (accessToken.isEmpty) {
      return PublishResult(
        success: false,
        note:
            'Fingerprint auth required or auth/API config missing for ${post.platform.label}. Connect OAuth or set ${config.urlEnvKey} and ${config.tokenEnvKey}.',
      );
    }

    if (post.platform == SocialPlatform.instagram &&
        _canUseInstagramGraph(config)) {
      return _publishViaInstagramGraph(post, config, accessToken);
    }

    if (post.platform == SocialPlatform.facebook &&
        post.postType != PostType.story &&
        _canUseFacebookGraph(config)) {
      return _publishViaFacebookGraph(post, config, accessToken);
    }

    if (post.platform == SocialPlatform.linkedin &&
        post.postType != PostType.story &&
        _canUseLinkedInApi(config)) {
      return _publishViaLinkedInApi(post, config, accessToken);
    }

    if (config.publishUrl.isEmpty) {
      return PublishResult(
        success: false,
        note:
            'Missing API config for ${post.platform.label}. Set ${config.urlEnvKey}.',
      );
    }

    if (_requiresMedia(post.postType) && post.mediaUrls.isEmpty) {
      return PublishResult(
        success: false,
        note:
            '${post.postType.label} post for ${post.platform.label} requires at least one media URL.',
      );
    }

    if (!_isTypeSupported(post.platform, post.postType)) {
      return PublishResult(
        success: false,
        note:
            '${post.postType.label} posts are not supported on ${post.platform.label} in this handler.',
      );
    }

    final request = _resolveRequest(post, config);
    if (request.error != null) {
      return PublishResult(success: false, note: request.error!);
    }

    final uri = Uri.tryParse(request.publishUrl);
    if (uri == null) {
      return PublishResult(
        success: false,
        note: 'Invalid publish URL for ${post.platform.label}.',
      );
    }

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(request.payload),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return PublishResult(
          success: true,
          note: 'Uploaded to ${post.platform.label}',
        );
      }

      return PublishResult(
        success: false,
        note:
            '${post.platform.label} API error (${response.statusCode}): ${_trim(response.body)}',
      );
    } catch (error) {
      return PublishResult(
        success: false,
        note: 'Upload failed for ${post.platform.label}: $error',
      );
    }
  }

  bool _canUseInstagramGraph(_PlatformPublishConfig config) {
    return config.instagramGraphBaseUrl.isNotEmpty &&
        config.instagramUserId.isNotEmpty;
  }

  bool _canUseFacebookGraph(_PlatformPublishConfig config) {
    return config.facebookGraphBaseUrl.isNotEmpty &&
        config.facebookPageId.isNotEmpty;
  }

  bool _canUseLinkedInApi(_PlatformPublishConfig config) {
    return config.linkedinApiBaseUrl.isNotEmpty &&
        config.linkedinAuthorUrn.isNotEmpty;
  }

  Future<PublishResult> _publishViaLinkedInApi(
    ScheduledPost post,
    _PlatformPublishConfig config,
    String accessToken,
  ) async {
    if (post.postType == PostType.story) {
      return const PublishResult(
        success: false,
        note:
            'LinkedIn story is not supported in LinkedIn API mode. Configure SOCIAL_LINKEDIN_STORY_PUBLISH_URL for endpoint mode.',
      );
    }

    final uri = Uri.parse('${config.linkedinApiBaseUrl}/posts');

    final payload = <String, dynamic>{
      'author': config.linkedinAuthorUrn,
      'commentary': post.message,
      'visibility': 'PUBLIC',
      'distribution': {
        'feedDistribution': 'MAIN_FEED',
        'targetEntities': <String>[],
        'thirdPartyDistributionChannels': <String>[],
      },
      'lifecycleState': 'PUBLISHED',
      'isReshareDisabledByAuthor': false,
    };

    if (post.mediaUrls.isNotEmpty) {
      payload['content'] = {
        'article': {
          'source': post.mediaUrls.first,
          'title': post.message.isEmpty
              ? 'Scheduled post'
              : post.message.substring(
                  0,
                  post.message.length > 200 ? 200 : post.message.length,
                ),
        },
      };
    }

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
              'LinkedIn-Version': config.linkedinVersion,
              'X-Restli-Protocol-Version': '2.0.0',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const PublishResult(
          success: true,
          note: 'Uploaded to LinkedIn via REST API',
        );
      }

      return PublishResult(
        success: false,
        note:
            'LinkedIn API publish error (${response.statusCode}): ${_trim(response.body)}',
      );
    } catch (error) {
      return PublishResult(
        success: false,
        note: 'LinkedIn API publish failed: $error',
      );
    }
  }

  Future<PublishResult> _publishViaFacebookGraph(
    ScheduledPost post,
    _PlatformPublishConfig config,
    String accessToken,
  ) async {
    final baseUrl = config.facebookGraphBaseUrl;
    final pageId = config.facebookPageId;

    Uri uri;
    final body = <String, String>{
      'access_token': accessToken,
      if (post.message.isNotEmpty) 'message': post.message,
    };

    switch (post.postType) {
      case PostType.text:
        uri = Uri.parse('$baseUrl/$pageId/feed');
        break;
      case PostType.photo:
        if (post.mediaUrls.isEmpty) {
          return const PublishResult(
            success: false,
            note: 'Facebook photo publish requires one media URL.',
          );
        }
        uri = Uri.parse('$baseUrl/$pageId/photos');
        body['url'] = post.mediaUrls.first;
        break;
      case PostType.video:
        if (post.mediaUrls.isEmpty) {
          return const PublishResult(
            success: false,
            note: 'Facebook video publish requires one media URL.',
          );
        }
        uri = Uri.parse('$baseUrl/$pageId/videos');
        body['file_url'] = post.mediaUrls.first;
        body['description'] = post.message;
        break;
      case PostType.story:
        return const PublishResult(
          success: false,
          note:
              'Facebook story is not enabled in Graph mode. Configure SOCIAL_FACEBOOK_STORY_PUBLISH_URL for endpoint mode.',
        );
    }

    try {
      final response = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const PublishResult(
          success: true,
          note: 'Uploaded to Facebook via Graph API',
        );
      }

      return PublishResult(
        success: false,
        note:
            'Facebook Graph publish error (${response.statusCode}): ${_trim(response.body)}',
      );
    } catch (error) {
      return PublishResult(
        success: false,
        note: 'Facebook Graph API publish failed: $error',
      );
    }
  }

  Future<PublishResult> _publishViaInstagramGraph(
    ScheduledPost post,
    _PlatformPublishConfig config,
    String accessToken,
  ) async {
    if (post.postType == PostType.text) {
      return const PublishResult(
        success: false,
        note:
            'Instagram Graph API requires media for publishing. Choose photo, video, or story.',
      );
    }

    if (post.mediaUrls.isEmpty) {
      return const PublishResult(
        success: false,
        note: 'Instagram publish requires at least one media URL.',
      );
    }

    final mediaUrl = post.mediaUrls.first;
    final containerUri = Uri.parse(
      '${config.instagramGraphBaseUrl}/${config.instagramUserId}/media',
    );

    final caption = (post.caption ?? '').trim().isNotEmpty
        ? (post.caption ?? '').trim()
        : post.message;

    final containerBody = <String, String>{
      'access_token': accessToken,
      if (caption.isNotEmpty) 'caption': caption,
    };

    switch (post.postType) {
      case PostType.photo:
        containerBody['image_url'] = mediaUrl;
        break;
      case PostType.video:
        containerBody['video_url'] = mediaUrl;
        containerBody['media_type'] = 'REELS';
        break;
      case PostType.story:
        if (_looksLikeVideo(mediaUrl)) {
          containerBody['video_url'] = mediaUrl;
        } else {
          containerBody['image_url'] = mediaUrl;
        }
        containerBody['media_type'] = 'STORIES';
        if (post.instagramCloseFriends) {
          containerBody['close_friends'] = 'true';
        }
        break;
      case PostType.text:
        break;
    }

    try {
      final createResponse = await http
          .post(
            containerUri,
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: containerBody,
          )
          .timeout(const Duration(seconds: 25));

      if (createResponse.statusCode < 200 || createResponse.statusCode >= 300) {
        return PublishResult(
          success: false,
          note:
              'Instagram container error (${createResponse.statusCode}): ${_trim(createResponse.body)}',
        );
      }

      final createJson = _tryDecodeMap(createResponse.body);
      final creationId =
          (createJson?['id'] as String?) ??
          (createJson?['creation_id'] as String?);
      if (creationId == null || creationId.isEmpty) {
        return const PublishResult(
          success: false,
          note: 'Instagram container created without an id.',
        );
      }

      final ready = await _waitForInstagramContainerReady(
        creationId: creationId,
        accessToken: accessToken,
        config: config,
      );

      if (!ready) {
        return const PublishResult(
          success: false,
          note: 'Instagram media container is not ready for publish.',
        );
      }

      final publishUri = Uri.parse(
        '${config.instagramGraphBaseUrl}/${config.instagramUserId}/media_publish',
      );

      final publishResponse = await http
          .post(
            publishUri,
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {'creation_id': creationId, 'access_token': accessToken},
          )
          .timeout(const Duration(seconds: 25));

      if (publishResponse.statusCode >= 200 &&
          publishResponse.statusCode < 300) {
        return const PublishResult(
          success: true,
          note: 'Uploaded to Instagram via Graph API',
        );
      }

      return PublishResult(
        success: false,
        note:
            'Instagram publish error (${publishResponse.statusCode}): ${_trim(publishResponse.body)}',
      );
    } catch (error) {
      return PublishResult(
        success: false,
        note: 'Instagram Graph API publish failed: $error',
      );
    }
  }

  Future<bool> _waitForInstagramContainerReady({
    required String creationId,
    required String accessToken,
    required _PlatformPublishConfig config,
  }) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final statusUri = Uri.parse(
        '${config.instagramGraphBaseUrl}/$creationId?fields=status_code,status&access_token=$accessToken',
      );

      try {
        final statusResponse = await http
            .get(statusUri)
            .timeout(const Duration(seconds: 12));

        if (statusResponse.statusCode >= 200 &&
            statusResponse.statusCode < 300) {
          final statusJson = _tryDecodeMap(statusResponse.body);
          final statusCode =
              (statusJson?['status_code'] as String?) ??
              (statusJson?['status'] as String?) ??
              '';

          if (statusCode.toUpperCase() == 'FINISHED' || statusCode.isEmpty) {
            return true;
          }

          if (statusCode.toUpperCase() == 'ERROR' ||
              statusCode.toUpperCase() == 'EXPIRED') {
            return false;
          }
        }
      } catch (_) {
        // Keep polling until attempts are exhausted.
      }

      await Future<void>.delayed(const Duration(seconds: 2));
    }

    return false;
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

  bool _looksLikeVideo(String url) {
    final normalized = url.toLowerCase();
    return normalized.endsWith('.mp4') ||
        normalized.endsWith('.mov') ||
        normalized.endsWith('.m4v') ||
        normalized.contains('video');
  }

  _ResolvedPublishRequest _resolveRequest(
    ScheduledPost post,
    _PlatformPublishConfig config,
  ) {
    final publishUrl = _publishUrlForType(post.postType, config);
    if (publishUrl.isEmpty) {
      return _ResolvedPublishRequest(
        publishUrl: '',
        payload: const {},
        error:
            'Missing endpoint for ${post.platform.label} ${post.postType.label}. Set ${_urlEnvKeyForType(post.postType, config)}.',
      );
    }

    return _ResolvedPublishRequest(
      publishUrl: publishUrl,
      payload: _payloadForPlatform(post),
      error: null,
    );
  }

  String _publishUrlForType(PostType type, _PlatformPublishConfig config) {
    switch (type) {
      case PostType.text:
        return config.textPublishUrl.isNotEmpty
            ? config.textPublishUrl
            : config.publishUrl;
      case PostType.photo:
        return config.photoPublishUrl.isNotEmpty
            ? config.photoPublishUrl
            : config.publishUrl;
      case PostType.video:
        return config.videoPublishUrl.isNotEmpty
            ? config.videoPublishUrl
            : config.publishUrl;
      case PostType.story:
        return config.storyPublishUrl.isNotEmpty
            ? config.storyPublishUrl
            : config.publishUrl;
    }
  }

  String _urlEnvKeyForType(PostType type, _PlatformPublishConfig config) {
    switch (type) {
      case PostType.text:
        return config.textUrlEnvKey;
      case PostType.photo:
        return config.photoUrlEnvKey;
      case PostType.video:
        return config.videoUrlEnvKey;
      case PostType.story:
        return config.storyUrlEnvKey;
    }
  }

  Map<String, dynamic> _payloadForPlatform(ScheduledPost post) {
    final caption = (post.caption ?? '').trim();
    final base = <String, dynamic>{
      'scheduledAt': post.scheduledAt.toIso8601String(),
      'postType': post.postType.name,
      'mediaUrls': post.mediaUrls,
      if (caption.isNotEmpty) 'caption': caption,
    };

    switch (post.platform) {
      case SocialPlatform.instagram:
        return {
          ...base,
          'caption': caption.isNotEmpty ? caption : post.message,
          'mediaUrl': post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null,
          'isStory': post.postType == PostType.story,
          'closeFriends': post.instagramCloseFriends,
        };
      case SocialPlatform.facebook:
        return {
          ...base,
          'message': post.message,
          'mediaUrl': post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null,
          'story': post.postType == PostType.story,
        };
      case SocialPlatform.x:
        return {
          ...base,
          'text': post.message,
          'mediaUrl': post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null,
        };
      case SocialPlatform.threads:
        return {
          ...base,
          'text': post.message,
          'mediaUrl': post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null,
        };
      case SocialPlatform.linkedin:
        return {
          ...base,
          'commentary': post.message,
          'mediaUrl': post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null,
          'visibility': 'PUBLIC',
        };
    }
  }

  bool _requiresMedia(PostType type) {
    return type == PostType.photo ||
        type == PostType.video ||
        type == PostType.story;
  }

  bool _isTypeSupported(SocialPlatform platform, PostType type) {
    switch (platform) {
      case SocialPlatform.instagram:
      case SocialPlatform.facebook:
        return true;
      case SocialPlatform.x:
      case SocialPlatform.threads:
      case SocialPlatform.linkedin:
        return type != PostType.story;
    }
  }

  _PlatformPublishConfig _configFor(SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.instagram:
        return const _PlatformPublishConfig(
          urlEnvKey: 'SOCIAL_INSTAGRAM_PUBLISH_URL',
          tokenEnvKey: 'SOCIAL_INSTAGRAM_ACCESS_TOKEN',
          publishUrl: String.fromEnvironment('SOCIAL_INSTAGRAM_PUBLISH_URL'),
          instagramGraphBaseUrl: String.fromEnvironment(
            'SOCIAL_INSTAGRAM_GRAPH_BASE_URL',
            defaultValue: 'https://graph.facebook.com/v21.0',
          ),
          instagramGraphBaseUrlEnvKey: 'SOCIAL_INSTAGRAM_GRAPH_BASE_URL',
          instagramUserId: String.fromEnvironment('SOCIAL_INSTAGRAM_USER_ID'),
          instagramUserIdEnvKey: 'SOCIAL_INSTAGRAM_USER_ID',
          textUrlEnvKey: 'SOCIAL_INSTAGRAM_TEXT_PUBLISH_URL',
          textPublishUrl: String.fromEnvironment(
            'SOCIAL_INSTAGRAM_TEXT_PUBLISH_URL',
          ),
          photoUrlEnvKey: 'SOCIAL_INSTAGRAM_PHOTO_PUBLISH_URL',
          photoPublishUrl: String.fromEnvironment(
            'SOCIAL_INSTAGRAM_PHOTO_PUBLISH_URL',
          ),
          videoUrlEnvKey: 'SOCIAL_INSTAGRAM_VIDEO_PUBLISH_URL',
          videoPublishUrl: String.fromEnvironment(
            'SOCIAL_INSTAGRAM_VIDEO_PUBLISH_URL',
          ),
          storyUrlEnvKey: 'SOCIAL_INSTAGRAM_STORY_PUBLISH_URL',
          storyPublishUrl: String.fromEnvironment(
            'SOCIAL_INSTAGRAM_STORY_PUBLISH_URL',
          ),
          facebookGraphBaseUrl: '',
          facebookGraphBaseUrlEnvKey: '',
          facebookPageId: '',
          facebookPageIdEnvKey: '',
          linkedinApiBaseUrl: '',
          linkedinApiBaseUrlEnvKey: '',
          linkedinAuthorUrn: '',
          linkedinAuthorUrnEnvKey: '',
          linkedinVersion: '',
          linkedinVersionEnvKey: '',
          accessToken: String.fromEnvironment('SOCIAL_INSTAGRAM_ACCESS_TOKEN'),
        );
      case SocialPlatform.facebook:
        return const _PlatformPublishConfig(
          urlEnvKey: 'SOCIAL_FACEBOOK_PUBLISH_URL',
          tokenEnvKey: 'SOCIAL_FACEBOOK_ACCESS_TOKEN',
          publishUrl: String.fromEnvironment('SOCIAL_FACEBOOK_PUBLISH_URL'),
          instagramGraphBaseUrl: '',
          instagramGraphBaseUrlEnvKey: '',
          instagramUserId: '',
          instagramUserIdEnvKey: '',
          textUrlEnvKey: 'SOCIAL_FACEBOOK_TEXT_PUBLISH_URL',
          textPublishUrl: String.fromEnvironment(
            'SOCIAL_FACEBOOK_TEXT_PUBLISH_URL',
          ),
          photoUrlEnvKey: 'SOCIAL_FACEBOOK_PHOTO_PUBLISH_URL',
          photoPublishUrl: String.fromEnvironment(
            'SOCIAL_FACEBOOK_PHOTO_PUBLISH_URL',
          ),
          videoUrlEnvKey: 'SOCIAL_FACEBOOK_VIDEO_PUBLISH_URL',
          videoPublishUrl: String.fromEnvironment(
            'SOCIAL_FACEBOOK_VIDEO_PUBLISH_URL',
          ),
          storyUrlEnvKey: 'SOCIAL_FACEBOOK_STORY_PUBLISH_URL',
          storyPublishUrl: String.fromEnvironment(
            'SOCIAL_FACEBOOK_STORY_PUBLISH_URL',
          ),
          facebookGraphBaseUrl: String.fromEnvironment(
            'SOCIAL_FACEBOOK_GRAPH_BASE_URL',
            defaultValue: 'https://graph.facebook.com/v21.0',
          ),
          facebookGraphBaseUrlEnvKey: 'SOCIAL_FACEBOOK_GRAPH_BASE_URL',
          facebookPageId: String.fromEnvironment('SOCIAL_FACEBOOK_PAGE_ID'),
          facebookPageIdEnvKey: 'SOCIAL_FACEBOOK_PAGE_ID',
          linkedinApiBaseUrl: '',
          linkedinApiBaseUrlEnvKey: '',
          linkedinAuthorUrn: '',
          linkedinAuthorUrnEnvKey: '',
          linkedinVersion: '',
          linkedinVersionEnvKey: '',
          accessToken: String.fromEnvironment('SOCIAL_FACEBOOK_ACCESS_TOKEN'),
        );
      case SocialPlatform.x:
        return const _PlatformPublishConfig(
          urlEnvKey: 'SOCIAL_X_PUBLISH_URL',
          tokenEnvKey: 'SOCIAL_X_ACCESS_TOKEN',
          publishUrl: String.fromEnvironment('SOCIAL_X_PUBLISH_URL'),
          instagramGraphBaseUrl: '',
          instagramGraphBaseUrlEnvKey: '',
          instagramUserId: '',
          instagramUserIdEnvKey: '',
          textUrlEnvKey: 'SOCIAL_X_TEXT_PUBLISH_URL',
          textPublishUrl: String.fromEnvironment('SOCIAL_X_TEXT_PUBLISH_URL'),
          photoUrlEnvKey: 'SOCIAL_X_PHOTO_PUBLISH_URL',
          photoPublishUrl: String.fromEnvironment('SOCIAL_X_PHOTO_PUBLISH_URL'),
          videoUrlEnvKey: 'SOCIAL_X_VIDEO_PUBLISH_URL',
          videoPublishUrl: String.fromEnvironment('SOCIAL_X_VIDEO_PUBLISH_URL'),
          storyUrlEnvKey: 'SOCIAL_X_STORY_PUBLISH_URL',
          storyPublishUrl: String.fromEnvironment('SOCIAL_X_STORY_PUBLISH_URL'),
          facebookGraphBaseUrl: '',
          facebookGraphBaseUrlEnvKey: '',
          facebookPageId: '',
          facebookPageIdEnvKey: '',
          linkedinApiBaseUrl: '',
          linkedinApiBaseUrlEnvKey: '',
          linkedinAuthorUrn: '',
          linkedinAuthorUrnEnvKey: '',
          linkedinVersion: '',
          linkedinVersionEnvKey: '',
          accessToken: String.fromEnvironment('SOCIAL_X_ACCESS_TOKEN'),
        );
      case SocialPlatform.threads:
        return const _PlatformPublishConfig(
          urlEnvKey: 'SOCIAL_THREADS_PUBLISH_URL',
          tokenEnvKey: 'SOCIAL_THREADS_ACCESS_TOKEN',
          publishUrl: String.fromEnvironment('SOCIAL_THREADS_PUBLISH_URL'),
          instagramGraphBaseUrl: '',
          instagramGraphBaseUrlEnvKey: '',
          instagramUserId: '',
          instagramUserIdEnvKey: '',
          textUrlEnvKey: 'SOCIAL_THREADS_TEXT_PUBLISH_URL',
          textPublishUrl: String.fromEnvironment(
            'SOCIAL_THREADS_TEXT_PUBLISH_URL',
          ),
          photoUrlEnvKey: 'SOCIAL_THREADS_PHOTO_PUBLISH_URL',
          photoPublishUrl: String.fromEnvironment(
            'SOCIAL_THREADS_PHOTO_PUBLISH_URL',
          ),
          videoUrlEnvKey: 'SOCIAL_THREADS_VIDEO_PUBLISH_URL',
          videoPublishUrl: String.fromEnvironment(
            'SOCIAL_THREADS_VIDEO_PUBLISH_URL',
          ),
          storyUrlEnvKey: 'SOCIAL_THREADS_STORY_PUBLISH_URL',
          storyPublishUrl: String.fromEnvironment(
            'SOCIAL_THREADS_STORY_PUBLISH_URL',
          ),
          facebookGraphBaseUrl: '',
          facebookGraphBaseUrlEnvKey: '',
          facebookPageId: '',
          facebookPageIdEnvKey: '',
          linkedinApiBaseUrl: '',
          linkedinApiBaseUrlEnvKey: '',
          linkedinAuthorUrn: '',
          linkedinAuthorUrnEnvKey: '',
          linkedinVersion: '',
          linkedinVersionEnvKey: '',
          accessToken: String.fromEnvironment('SOCIAL_THREADS_ACCESS_TOKEN'),
        );
      case SocialPlatform.linkedin:
        return const _PlatformPublishConfig(
          urlEnvKey: 'SOCIAL_LINKEDIN_PUBLISH_URL',
          tokenEnvKey: 'SOCIAL_LINKEDIN_ACCESS_TOKEN',
          publishUrl: String.fromEnvironment('SOCIAL_LINKEDIN_PUBLISH_URL'),
          instagramGraphBaseUrl: '',
          instagramGraphBaseUrlEnvKey: '',
          instagramUserId: '',
          instagramUserIdEnvKey: '',
          textUrlEnvKey: 'SOCIAL_LINKEDIN_TEXT_PUBLISH_URL',
          textPublishUrl: String.fromEnvironment(
            'SOCIAL_LINKEDIN_TEXT_PUBLISH_URL',
          ),
          photoUrlEnvKey: 'SOCIAL_LINKEDIN_PHOTO_PUBLISH_URL',
          photoPublishUrl: String.fromEnvironment(
            'SOCIAL_LINKEDIN_PHOTO_PUBLISH_URL',
          ),
          videoUrlEnvKey: 'SOCIAL_LINKEDIN_VIDEO_PUBLISH_URL',
          videoPublishUrl: String.fromEnvironment(
            'SOCIAL_LINKEDIN_VIDEO_PUBLISH_URL',
          ),
          storyUrlEnvKey: 'SOCIAL_LINKEDIN_STORY_PUBLISH_URL',
          storyPublishUrl: String.fromEnvironment(
            'SOCIAL_LINKEDIN_STORY_PUBLISH_URL',
          ),
          facebookGraphBaseUrl: '',
          facebookGraphBaseUrlEnvKey: '',
          facebookPageId: '',
          facebookPageIdEnvKey: '',
          linkedinApiBaseUrl: String.fromEnvironment(
            'SOCIAL_LINKEDIN_API_BASE_URL',
            defaultValue: 'https://api.linkedin.com/rest',
          ),
          linkedinApiBaseUrlEnvKey: 'SOCIAL_LINKEDIN_API_BASE_URL',
          linkedinAuthorUrn: String.fromEnvironment(
            'SOCIAL_LINKEDIN_AUTHOR_URN',
          ),
          linkedinAuthorUrnEnvKey: 'SOCIAL_LINKEDIN_AUTHOR_URN',
          linkedinVersion: String.fromEnvironment(
            'SOCIAL_LINKEDIN_VERSION',
            defaultValue: '202501',
          ),
          linkedinVersionEnvKey: 'SOCIAL_LINKEDIN_VERSION',
          accessToken: String.fromEnvironment('SOCIAL_LINKEDIN_ACCESS_TOKEN'),
        );
    }
  }

  String _trim(String value) {
    if (value.length <= 140) {
      return value;
    }
    return '${value.substring(0, 140)}...';
  }
}

class _PlatformPublishConfig {
  const _PlatformPublishConfig({
    required this.urlEnvKey,
    required this.tokenEnvKey,
    required this.publishUrl,
    required this.instagramGraphBaseUrl,
    required this.instagramGraphBaseUrlEnvKey,
    required this.instagramUserId,
    required this.instagramUserIdEnvKey,
    required this.textUrlEnvKey,
    required this.textPublishUrl,
    required this.photoUrlEnvKey,
    required this.photoPublishUrl,
    required this.videoUrlEnvKey,
    required this.videoPublishUrl,
    required this.storyUrlEnvKey,
    required this.storyPublishUrl,
    required this.facebookGraphBaseUrl,
    required this.facebookGraphBaseUrlEnvKey,
    required this.facebookPageId,
    required this.facebookPageIdEnvKey,
    required this.linkedinApiBaseUrl,
    required this.linkedinApiBaseUrlEnvKey,
    required this.linkedinAuthorUrn,
    required this.linkedinAuthorUrnEnvKey,
    required this.linkedinVersion,
    required this.linkedinVersionEnvKey,
    required this.accessToken,
  });

  final String urlEnvKey;
  final String tokenEnvKey;
  final String publishUrl;
  final String instagramGraphBaseUrl;
  final String instagramGraphBaseUrlEnvKey;
  final String instagramUserId;
  final String instagramUserIdEnvKey;
  final String textUrlEnvKey;
  final String textPublishUrl;
  final String photoUrlEnvKey;
  final String photoPublishUrl;
  final String videoUrlEnvKey;
  final String videoPublishUrl;
  final String storyUrlEnvKey;
  final String storyPublishUrl;
  final String facebookGraphBaseUrl;
  final String facebookGraphBaseUrlEnvKey;
  final String facebookPageId;
  final String facebookPageIdEnvKey;
  final String linkedinApiBaseUrl;
  final String linkedinApiBaseUrlEnvKey;
  final String linkedinAuthorUrn;
  final String linkedinAuthorUrnEnvKey;
  final String linkedinVersion;
  final String linkedinVersionEnvKey;
  final String accessToken;
}

class _ResolvedPublishRequest {
  const _ResolvedPublishRequest({
    required this.publishUrl,
    required this.payload,
    required this.error,
  });

  final String publishUrl;
  final Map<String, dynamic> payload;
  final String? error;
}
