POST SCHEDULER Backend API Contract

Version: 1.0
Status: Production-ready draft

Purpose
- Define exact API contracts for OAuth, token refresh, profile lookup, and publishing.
- Match the Flutter app request/response formats currently used.
- Enable secure live deployment with backend-managed provider credentials.

Base URL
- Production: https://api.yourdomain.com
- Staging: https://staging-api.yourdomain.com

Supported platforms
- instagram
- facebook
- x
- threads
- linkedin

General rules
- Content type:
  - OAuth token exchange: application/x-www-form-urlencoded
  - Refresh and publish: application/json
- Authorization:
  - OAuth endpoints: no bearer required (public mobile flow)
  - Publish endpoints: Authorization: Bearer <provider_access_token> for current app compatibility
- Time format:
  - ISO-8601 UTC (example: 2026-03-14T12:45:00Z)
- Standard error body:
  - {
      "error": {
        "code": "string",
        "message": "human readable",
        "details": {}
      }
    }

1) OAuth Authorize

Endpoint
- GET /oauth/{platform}/authorize

Description
- Builds provider authorize URL and redirects user to provider login.
- Mobile app opens this URL in browser/web-auth flow.

Query params (required unless stated)
- response_type: code
- client_id: string
- redirect_uri: string (example: postscheduler://oauth)
- scope: string (space-separated)
- state: string
- code_challenge: string
- code_challenge_method: S256

Behavior
- 302 redirect to provider authorize URL.
- On provider completion, redirect to redirect_uri with code and state.

Success response
- HTTP 302 (Location header points to provider)

Error response
- HTTP 400/500 with standard error body.

2) OAuth Token Exchange

Endpoint
- POST /oauth/{platform}/token

Headers
- Content-Type: application/x-www-form-urlencoded

Form fields
- grant_type: authorization_code
- code: string
- redirect_uri: string
- client_id: string
- code_verifier: string
- client_secret: string (optional for PKCE-only apps)

Success response (200)
- {
    "access_token": "string",
    "refresh_token": "string",
    "token_type": "Bearer",
    "expires_in": 3600,
    "scope": "optional"
  }

Error response
- 400, 401, 403, 500 with standard error body.

3) OAuth Refresh

Endpoint
- POST /oauth/{platform}/refresh

Headers
- Content-Type: application/json

Request body
- {
    "grant_type": "refresh_token",
    "refresh_token": "string",
    "client_id": "string",
    "client_secret": "optional"
  }

Success response (200)
- {
    "access_token": "string",
    "refresh_token": "string",
    "token_type": "Bearer",
    "expires_in": 3600
  }

Error response
- 400, 401, 403, 500 with standard error body.

4) OAuth Profile

Endpoint
- GET /oauth/{platform}/profile

Headers
- Authorization: Bearer <access_token>

Description
- Returns account identity for connection confirmation and UI handle.

Success response (200)
- {
    "id": "string",
    "username": "optional",
    "name": "optional",
    "handle": "optional",
    "raw": {}
  }

Error response
- 401, 403, 500 with standard error body.

5) Publish

Endpoint
- POST /publish/{platform}

Headers
- Authorization: Bearer <access_token>
- Content-Type: application/json

Common request shape
- {
    "scheduledAt": "2026-03-14T12:45:00Z",
    "postType": "text|photo|video|story",
    "mediaUrls": ["https://..."],
    "caption": "optional",

    "message": "for facebook",
    "text": "for x/threads",
    "commentary": "for linkedin",

    "mediaUrl": "optional first media",
    "isStory": false,
    "story": false,
    "closeFriends": false,
    "visibility": "PUBLIC"
  }

Notes
- Keep compatibility with current app payload builder.
- Backend should normalize provider-specific fields internally.

Success response (200 or 201)
- {
    "success": true,
    "providerPostId": "string",
    "note": "Uploaded to platform",
    "publishedAt": "2026-03-14T12:45:05Z"
  }

Error response
- 400, 401, 403, 409, 429, 500 with standard error body.

6) Optional Type-Specific Publish Endpoints

For backward compatibility with current app defines, backend may expose:
- POST /publish/{platform}/text
- POST /publish/{platform}/photo
- POST /publish/{platform}/video
- POST /publish/{platform}/story

If implemented, each should accept the same common request shape and apply strict postType validation.

7) Security requirements

Required
- Enforce HTTPS only.
- Validate state and PKCE verifier/challenge.
- Rate-limit OAuth and publish endpoints.
- Encrypt provider refresh tokens at rest.
- Do not return provider client_secret to mobile.
- Audit log every connect/refresh/publish event.

Recommended
- Add idempotency-key header support for publish retries.
- Add per-user quota and abuse protection.
- Add webhook ingestion where providers support status callbacks.

8) Environment variables (backend)

Per platform
- OAUTH_CLIENT_ID
- OAUTH_CLIENT_SECRET (if required)
- OAUTH_AUTHORIZE_URL
- OAUTH_TOKEN_URL
- OAUTH_REFRESH_URL
- OAUTH_SCOPES

Platform API keys
- INSTAGRAM_GRAPH_BASE_URL
- FACEBOOK_GRAPH_BASE_URL
- LINKEDIN_API_BASE_URL

9) Flutter mapping to backend URLs

Set these app runtime values to your backend:
- SOCIAL_<PLATFORM>_OAUTH_AUTH_URL = https://api.yourdomain.com/oauth/<platform>/authorize
- SOCIAL_<PLATFORM>_OAUTH_TOKEN_URL = https://api.yourdomain.com/oauth/<platform>/token
- SOCIAL_<PLATFORM>_OAUTH_REFRESH_URL = https://api.yourdomain.com/oauth/<platform>/refresh
- SOCIAL_<PLATFORM>_OAUTH_PROFILE_URL = https://api.yourdomain.com/oauth/<platform>/profile
- SOCIAL_<PLATFORM>_PUBLISH_URL = https://api.yourdomain.com/publish/<platform>

Keep
- SOCIAL_<PLATFORM>_OAUTH_REDIRECT_URI = postscheduler://oauth

10) Acceptance checklist

- OAuth connect opens provider login and returns to app deep link.
- Token exchange returns access and refresh token.
- Profile endpoint returns identity fields for connected badge/handle.
- Publish endpoint accepts app payload and creates real provider post.
- Refresh endpoint updates expired access tokens.
- All endpoints return structured error payloads on failure.
