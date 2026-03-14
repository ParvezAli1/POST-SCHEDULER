# POST SCHEDULER

Realtime social media post scheduler for Instagram, Facebook, X, Threads, and LinkedIn.

## Features

- Animated launch screen with branded app-name reveal
- Signup and login screen before entering the main app
- Dashboard with realtime publishing updates
- Drafts and scheduling workflows
- Direct publish payload support for text, photo, video, and story post types
- Media library preview
- Analytics snapshot (stubbed)
- Notification settings (stubbed)
- Automatic upload of due posts to the selected social platform

## Run

```bash
flutter pub get
flutter run
```

## App Flow

1. Launch screen animation shows the app name.
2. User is routed to Login/Signup.
3. Login supports Continue with Google and Forgot password.
3. After successful auth, user enters the main app shell.
4. User can logout from Settings.

## Real Social API Configuration

Publishing uses runtime dart-defines per platform. Each platform needs:
- A publish endpoint URL
- An access token

Example run command:

```bash
flutter run \
	--dart-define=SOCIAL_INSTAGRAM_PUBLISH_URL=https://your-api.example.com/instagram/publish \
	--dart-define=SOCIAL_INSTAGRAM_ACCESS_TOKEN=replace_me \
	--dart-define=SOCIAL_FACEBOOK_PUBLISH_URL=https://your-api.example.com/facebook/publish \
	--dart-define=SOCIAL_FACEBOOK_ACCESS_TOKEN=replace_me \
	--dart-define=SOCIAL_X_PUBLISH_URL=https://your-api.example.com/x/publish \
	--dart-define=SOCIAL_X_ACCESS_TOKEN=replace_me \
	--dart-define=SOCIAL_THREADS_PUBLISH_URL=https://your-api.example.com/threads/publish \
	--dart-define=SOCIAL_THREADS_ACCESS_TOKEN=replace_me \
	--dart-define=SOCIAL_LINKEDIN_PUBLISH_URL=https://your-api.example.com/linkedin/publish \
	--dart-define=SOCIAL_LINKEDIN_ACCESS_TOKEN=replace_me
```

Notes:
- If account toggle is disconnected for a platform, scheduled posts for that platform fail automatically.
- If URL/token is missing, publish fails with a clear message in realtime updates.
- Keep tokens in secure CI/CD or secrets managers for production builds.
- Scheduler now sends structured payload including `postType` and `mediaUrls` for platform handlers.

Optional type-specific endpoint keys per platform:
- `SOCIAL_<PLATFORM>_TEXT_PUBLISH_URL`
- `SOCIAL_<PLATFORM>_PHOTO_PUBLISH_URL`
- `SOCIAL_<PLATFORM>_VIDEO_PUBLISH_URL`
- `SOCIAL_<PLATFORM>_STORY_PUBLISH_URL`

If type-specific keys are not provided, the app falls back to `SOCIAL_<PLATFORM>_PUBLISH_URL`.

Current handler support:
- Instagram: text, photo, video, story
- Facebook: text, photo, video, story
- X: text, photo, video
- Threads: text, photo, video
- LinkedIn: text, photo, video

Instagram production Graph API mode (recommended):
- `SOCIAL_INSTAGRAM_GRAPH_BASE_URL` (default: `https://graph.facebook.com/v21.0`)
- `SOCIAL_INSTAGRAM_USER_ID`
- `SOCIAL_INSTAGRAM_ACCESS_TOKEN`

When Graph mode keys are present, Instagram publish uses:
1. `/{ig-user-id}/media` container creation
2. container status polling
3. `/{ig-user-id}/media_publish`

If Graph mode keys are missing, Instagram falls back to endpoint mode via `SOCIAL_INSTAGRAM_PUBLISH_URL`.

Facebook production Graph API mode:
- `SOCIAL_FACEBOOK_GRAPH_BASE_URL` (default: `https://graph.facebook.com/v21.0`)
- `SOCIAL_FACEBOOK_PAGE_ID`
- `SOCIAL_FACEBOOK_ACCESS_TOKEN`

When Facebook Graph mode keys are present, text/photo/video publish uses:
1. `/{page-id}/feed` (text)
2. `/{page-id}/photos` (photo)
3. `/{page-id}/videos` (video)

Facebook story remains endpoint-based via `SOCIAL_FACEBOOK_STORY_PUBLISH_URL`.

LinkedIn production REST API mode:
- `SOCIAL_LINKEDIN_API_BASE_URL` (default: `https://api.linkedin.com/rest`)
- `SOCIAL_LINKEDIN_AUTHOR_URN` (example: `urn:li:organization:123456`)
- `SOCIAL_LINKEDIN_VERSION` (default: `202501`)
- `SOCIAL_LINKEDIN_ACCESS_TOKEN`

When LinkedIn mode keys are present, text/photo/video publish uses `POST /posts`
with LinkedIn REST headers.

Note: current LinkedIn implementation posts media URLs as linked article content.
For native uploaded image/video assets, add LinkedIn upload registration + asset URN flow next.

## OAuth Scaffolding Configuration

Connect flow supports token endpoint configuration with dart-defines. When omitted, the app falls back to local mock OAuth tokens for development.

Per platform define keys:
- `SOCIAL_<PLATFORM>_OAUTH_AUTH_URL`
- `SOCIAL_<PLATFORM>_OAUTH_TOKEN_URL`
- `SOCIAL_<PLATFORM>_OAUTH_REFRESH_URL`
- `SOCIAL_<PLATFORM>_OAUTH_REDIRECT_URI` (default: `postscheduler://oauth`)
- `SOCIAL_<PLATFORM>_OAUTH_PROFILE_URL` (optional, used to fetch connected account name/username)
- `SOCIAL_<PLATFORM>_CLIENT_ID`
- `SOCIAL_<PLATFORM>_CLIENT_SECRET` (optional for PKCE flows)

Supported platform names:
- `INSTAGRAM`
- `FACEBOOK`
- `X`
- `THREADS`
- `LINKEDIN`

In-app social login flow:
1. App opens provider auth URL in browser.
2. User approves account login.
3. Provider redirects to app callback URI (`postscheduler://oauth`).
4. App exchanges authorization code for access/refresh tokens.

Security note:
- OAuth in app now uses PKCE (`code_challenge` + `code_verifier`) during authorization-code login.
- For production, prefer PKCE-only provider apps and avoid embedding a client secret in mobile builds.

## Secure Token Storage

OAuth sessions are persisted using `flutter_secure_storage`:
- iOS: Keychain
- Android: EncryptedSharedPreferences/Keystore-backed storage

Behavior:
- Connected platform tokens are restored on app startup.
- Disconnecting a platform removes its stored token session.

## Email/Password Auth Mode

Auth now supports Firebase Auth when Firebase is configured.

Behavior:
- If Firebase is initialized, login/signup/reset use Firebase Auth.
- If Firebase is not initialized, app falls back to secure local-device auth storage.

To enable Firebase Auth fully:
1. Add `google-services.json` under `android/app/`.
2. Add `GoogleService-Info.plist` under `ios/Runner/`.
3. Enable Email/Password and Google providers in Firebase Console.

## Firebase config in Git

Firebase config files are gitignored in this repo. When working locally, copy:
- `google-services.json` to `android/app/`
- `GoogleService-Info.plist` to `ios/Runner/`

Do not commit these files to public repos.

## Fingerprint Gate For Publishing

Publishing now requires biometric authentication (fingerprint/biometric prompt) before OAuth tokens are used.

Behavior:
- A successful biometric unlock grants a short authorization window (2 minutes).
- If biometric auth is canceled or fails, publish attempt fails safely.
- Biometric prompt is required again after the window expires.
- You can enable/disable this in Settings via "Fingerprint for publishing".

## Firebase placeholders

This project is wired for Firebase-style realtime updates in the service layer.
Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to enable
real integrations.
