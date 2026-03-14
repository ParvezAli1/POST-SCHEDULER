import 'dart:async';

import '../models/scheduled_post.dart';
import '../models/social_platform.dart';
import 'social_publish_service.dart';

class RealtimeUpdatesService {
  RealtimeUpdatesService({
    required this.resolvePosts,
    required this.isPlatformConnected,
    required this.publishPost,
  });

  final List<ScheduledPost> Function() resolvePosts;
  final bool Function(SocialPlatform platform) isPlatformConnected;
  final Future<PublishResult> Function(ScheduledPost post) publishPost;
  final StreamController<RealtimeUpdate> _controller =
      StreamController<RealtimeUpdate>.broadcast();
  final Set<String> _inFlightPostIds = <String>{};
  Timer? _timer;

  Stream<RealtimeUpdate> get updates => _controller.stream;

  void start() {
    if (_timer != null) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _processDuePosts();
    });
    _processDuePosts();
  }

  void _processDuePosts() {
    final posts = resolvePosts();
    if (posts.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final duePosts = posts.where(
      (post) =>
          post.status == PostStatus.scheduled &&
          !post.scheduledAt.isAfter(now) &&
          !_inFlightPostIds.contains(post.id),
    );

    for (final post in duePosts) {
      _startUpload(post);
    }
  }

  Future<void> _startUpload(ScheduledPost post) async {
    _inFlightPostIds.add(post.id);

    _controller.add(
      RealtimeUpdate(
        postId: post.id,
        status: PostStatus.publishing,
        at: DateTime.now(),
        note: 'Uploading to ${post.platform.label}',
      ),
    );

    if (!isPlatformConnected(post.platform)) {
      _controller.add(
        RealtimeUpdate(
          postId: post.id,
          status: PostStatus.failed,
          at: DateTime.now(),
          note: '${post.platform.label} account is not connected',
        ),
      );
      _inFlightPostIds.remove(post.id);
      return;
    }

    final result = await publishPost(post);
    final finalStatus = result.success
        ? PostStatus.published
        : PostStatus.failed;

    _controller.add(
      RealtimeUpdate(
        postId: post.id,
        status: finalStatus,
        at: DateTime.now(),
        note: result.note,
      ),
    );
    _inFlightPostIds.remove(post.id);
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
