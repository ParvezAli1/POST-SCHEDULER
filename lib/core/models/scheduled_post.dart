import 'social_platform.dart';

enum PostStatus { draft, scheduled, publishing, published, failed }

enum PostType { text, photo, video, story }

class ScheduledPost {
  ScheduledPost({
    required this.id,
    required this.platform,
    required this.message,
    required this.postType,
    required this.mediaUrls,
    this.caption,
    this.instagramCloseFriends = false,
    required this.scheduledAt,
    required this.status,
  });

  final String id;
  final SocialPlatform platform;
  final String message;
  final PostType postType;
  final List<String> mediaUrls;
  final String? caption;
  final bool instagramCloseFriends;
  final DateTime scheduledAt;
  final PostStatus status;

  ScheduledPost copyWith({
    String? message,
    PostType? postType,
    List<String>? mediaUrls,
    String? caption,
    bool? instagramCloseFriends,
    DateTime? scheduledAt,
    PostStatus? status,
  }) {
    return ScheduledPost(
      id: id,
      platform: platform,
      message: message ?? this.message,
      postType: postType ?? this.postType,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      caption: caption ?? this.caption,
      instagramCloseFriends:
          instagramCloseFriends ?? this.instagramCloseFriends,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
    );
  }
}

class RealtimeUpdate {
  RealtimeUpdate({
    required this.postId,
    required this.status,
    required this.at,
    required this.note,
  });

  final String postId;
  final PostStatus status;
  final DateTime at;
  final String note;
}

extension PostTypeLabels on PostType {
  String get label {
    switch (this) {
      case PostType.text:
        return 'Text';
      case PostType.photo:
        return 'Photo';
      case PostType.video:
        return 'Video';
      case PostType.story:
        return 'Story';
    }
  }
}
