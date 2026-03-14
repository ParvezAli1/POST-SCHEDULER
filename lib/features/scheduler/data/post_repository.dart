import 'package:flutter/foundation.dart';

import '../../../core/models/scheduled_post.dart';
import '../../../core/models/social_platform.dart';
import '../../../core/services/realtime_updates_service.dart';
import '../../../core/services/social_publish_service.dart';

class PostRepository {
  PostRepository({
    required this.isPlatformConnected,
    required this.resolveAccessToken,
    required this.refreshAccessTokenIfNeeded,
  }) {
    _posts = _seedPosts();
    _drafts = _seedDrafts();
    scheduledPostsNotifier = ValueNotifier<List<ScheduledPost>>(_posts);
    draftsNotifier = ValueNotifier<List<ScheduledPost>>(_drafts);
    _socialPublishService = SocialPublishService(
      resolveAccessToken: resolveAccessToken,
      refreshAccessTokenIfNeeded: refreshAccessTokenIfNeeded,
    );
    _realtimeService = RealtimeUpdatesService(
      resolvePosts: () => _posts,
      isPlatformConnected: isPlatformConnected,
      publishPost: _socialPublishService.publish,
    );
    _realtimeService.start();
    _realtimeService.updates.listen(_applyRealtimeUpdate);
  }

  final bool Function(SocialPlatform platform) isPlatformConnected;
  final Future<String?> Function(SocialPlatform platform) resolveAccessToken;
  final Future<bool> Function(SocialPlatform platform)
  refreshAccessTokenIfNeeded;

  late final ValueNotifier<List<ScheduledPost>> scheduledPostsNotifier;
  late final ValueNotifier<List<ScheduledPost>> draftsNotifier;
  late final RealtimeUpdatesService _realtimeService;
  late final SocialPublishService _socialPublishService;
  late List<ScheduledPost> _posts;
  late List<ScheduledPost> _drafts;

  Stream<RealtimeUpdate> get updates => _realtimeService.updates;

  String addDraft({
    required SocialPlatform platform,
    required String message,
    PostType postType = PostType.text,
    List<String> mediaUrls = const [],
    String? caption,
    bool instagramCloseFriends = false,
    DateTime? scheduledAt,
  }) {
    final draftId = 'draft_${DateTime.now().millisecondsSinceEpoch}';
    final draft = ScheduledPost(
      id: draftId,
      platform: platform,
      message: message,
      postType: postType,
      mediaUrls: mediaUrls,
      caption: caption,
      instagramCloseFriends: instagramCloseFriends,
      scheduledAt: scheduledAt ?? DateTime.now().add(const Duration(hours: 2)),
      status: PostStatus.draft,
    );

    _drafts = [..._drafts, draft];
    draftsNotifier.value = _drafts;
    return draftId;
  }

  void scheduleDraft(String draftId) {
    final draftIndex = _drafts.indexWhere((draft) => draft.id == draftId);
    if (draftIndex == -1) {
      return;
    }

    final draft = _drafts[draftIndex];
    final scheduled = draft.copyWith(status: PostStatus.scheduled);

    _drafts = [..._drafts]..removeAt(draftIndex);
    _posts = [..._posts, scheduled];
    draftsNotifier.value = _drafts;
    scheduledPostsNotifier.value = _posts;
  }

  void deleteDraft(String draftId) {
    final nextDrafts = _drafts.where((draft) => draft.id != draftId).toList();
    if (nextDrafts.length == _drafts.length) {
      return;
    }

    _drafts = nextDrafts;
    draftsNotifier.value = _drafts;
  }

  void _applyRealtimeUpdate(RealtimeUpdate update) {
    final index = _posts.indexWhere((post) => post.id == update.postId);
    if (index == -1) {
      return;
    }

    final post = _posts[index];
    final updated = post.copyWith(status: update.status);
    _posts = [..._posts]..[index] = updated;
    scheduledPostsNotifier.value = _posts;
  }

  List<ScheduledPost> _seedPosts() {
    final now = DateTime.now();
    return [
      ScheduledPost(
        id: 'post_001',
        platform: SocialPlatform.instagram,
        message: 'New drop teaser and countdown story.',
        postType: PostType.photo,
        mediaUrls: const ['https://cdn.example.com/media/launch_hero.jpg'],
        scheduledAt: now.subtract(const Duration(minutes: 1)),
        status: PostStatus.scheduled,
      ),
      ScheduledPost(
        id: 'post_002',
        platform: SocialPlatform.linkedin,
        message: 'Hiring update and team spotlight.',
        postType: PostType.text,
        mediaUrls: const [],
        scheduledAt: now.add(const Duration(hours: 6)),
        status: PostStatus.scheduled,
      ),
      ScheduledPost(
        id: 'post_003',
        platform: SocialPlatform.x,
        message: 'Live event thread schedule post.',
        postType: PostType.video,
        mediaUrls: const ['https://cdn.example.com/media/live_teaser.mp4'],
        scheduledAt: now.add(const Duration(hours: 9)),
        status: PostStatus.scheduled,
      ),
    ];
  }

  List<ScheduledPost> _seedDrafts() {
    return [
      ScheduledPost(
        id: 'draft_001',
        platform: SocialPlatform.threads,
        message: 'Threads launch recap highlights.',
        postType: PostType.text,
        mediaUrls: const [],
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
        status: PostStatus.draft,
      ),
      ScheduledPost(
        id: 'draft_002',
        platform: SocialPlatform.facebook,
        message: 'Community poll and Q&A prompt.',
        postType: PostType.story,
        mediaUrls: const ['https://cdn.example.com/media/community_story.jpg'],
        scheduledAt: DateTime.now().add(const Duration(days: 2)),
        status: PostStatus.draft,
      ),
    ];
  }
}
