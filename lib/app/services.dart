import '../features/auth/data/auth_repository.dart';
import '../features/media/data/media_repository.dart';
import '../features/scheduler/data/post_repository.dart';

class AppServices {
  static final AuthRepository authRepository = AuthRepository();
  static final PostRepository postRepository = PostRepository(
    isPlatformConnected: (platform) {
      return authRepository.accounts.any(
        (account) => account.platform == platform && account.connected,
      );
    },
    resolveAccessToken: authRepository.resolveAccessToken,
    refreshAccessTokenIfNeeded: authRepository.refreshAccessTokenIfNeeded,
  );
  static final MediaRepository mediaRepository = MediaRepository();
}
