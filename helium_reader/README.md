# Helium Reader (Flutter Pivot)

Cross-platform EPUB reader for Android + Desktop with Google Drive as storage and `sync.json` progress synchronization.

## What changed

- Legacy Next.js/Electron/Capacitor stack was removed.
- Preserved credentials are now in `../credentials` at repo root.
- New Flutter project lives in `helium_reader/`.

## Credentials preserved

The following were moved to `../credentials`:

- `google-services.json`
- `apps__mobile__android__app__google-services.json`
- `android-client_client_secret_...json`
- `web-client-1_client_secret_...json`
- `web-client-2_client_secret_...json`
- `apps__desktop__.env`
- `apps__desktop__.env.local`
- `apps__mobile__.env.local`

`GoogleService-Info.plist` was not found in the previous repo snapshot.

## Required runtime config

Pass OAuth client IDs via `--dart-define` when running/building:

- `GOOGLE_CLIENT_ID`
- `GOOGLE_SERVER_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET` (required for desktop OAuth when using a Web OAuth client)
- Optional: `GOOGLE_REDIRECT_URI` (default: `http://localhost:4200/oauth2callback`)
- Optional: `GOOGLE_DRIVE_FOLDER_ID` (to scope listing to one folder)

Example:

```bash
flutter run -d windows \
  --dart-define=GOOGLE_CLIENT_ID=YOUR_CLIENT_ID \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_SERVER_CLIENT_ID \
  --dart-define=GOOGLE_CLIENT_SECRET=YOUR_CLIENT_SECRET \
  --dart-define=GOOGLE_REDIRECT_URI=http://localhost:4200/oauth2callback
```

## Android / iOS credential placement

A helper script is included in repo root:

```powershell
./copy_credentials.ps1 -Android
./copy_credentials.ps1 -IOS
```

Targets:

- Android: `helium_reader/android/app/google-services.json`
- iOS: `helium_reader/ios/Runner/GoogleService-Info.plist`

## Implemented architecture

- Auth: `google_sign_in` + `flutter_secure_storage`
  - Silent sign-in bootstrap (`attemptLightweightAuthentication`)
  - Cached token/profile for offline fallback
- Local DB: `sqflite` (`books` + `app_settings` tables)
- Drive API: `googleapis` Drive v3 wrappers
  - EPUB discovery by file extension
  - File download to local library dir
  - `appDataFolder/sync.json` read/write
- Sync engine:
  - Last-write-wins using timestamps
  - Pull newer cloud CFI to local
  - Push dirty local progress to cloud
- Reader: `epub_view`
  - Loads local file path
  - Saves CFI on chapter/page movement
- UI:
  - Dark layout matching provided references
  - Drawer, library grid cards, settings sections
  - Subtle sync progress indicator
- Mobile background sync:
  - `workmanager` periodic task for dirty progress upload
- Desktop window memory:
  - `window_manager` + `shared_preferences`

## Current screens

- Splash (silent auth handshake)
- Login
- Library (grid + drawer)
- Reader
- Settings

## Run commands

```bash
cd helium_reader
flutter pub get
flutter analyze
flutter test
flutter run -d android
flutter run -d windows
```

## Notes

- Reading downloaded books works offline.
- Drive refresh/sync requires a valid Google session token.
- Desktop OAuth now stores refresh tokens and silently refreshes access tokens.
- If refresh fails (revoked token), the app asks for sign-in again.

