enum SocialPlatform { instagram, facebook, x, threads, linkedin }

extension SocialPlatformLabels on SocialPlatform {
  String get label {
    switch (this) {
      case SocialPlatform.instagram:
        return 'Instagram';
      case SocialPlatform.facebook:
        return 'Facebook';
      case SocialPlatform.x:
        return 'X';
      case SocialPlatform.threads:
        return 'Threads';
      case SocialPlatform.linkedin:
        return 'LinkedIn';
    }
  }

  String get handleHint {
    switch (this) {
      case SocialPlatform.instagram:
        return '@brand';
      case SocialPlatform.facebook:
        return '@page';
      case SocialPlatform.x:
        return '@handle';
      case SocialPlatform.threads:
        return '@threads';
      case SocialPlatform.linkedin:
        return 'company/page';
    }
  }
}
