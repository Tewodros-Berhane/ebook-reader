# Helium Reader (Flutter Pivot)

Cross-platform EPUB reader for Android + Desktop with Google Drive for file storage and MySQL for cross-device progress sync.

## What changed

- Legacy Next.js/Electron/Capacitor stack was removed.
- Preserved credentials are in `../credentials`.
- Flutter app lives in `helium_reader/`.
- Progress sync now uses MySQL (`book_progress` table), not `sync.json`.

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
- `connection-string.txt` (MySQL connection URI)

`GoogleService-Info.plist` may still need to be added manually if you build iOS.

## Required runtime config

Pass OAuth and MySQL values via `--dart-define`:

- `GOOGLE_CLIENT_ID`
- `GOOGLE_SERVER_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET` (desktop OAuth with Web OAuth client)
- `MYSQL_CONNECTION_URI` (required for progress sync)
- Optional: `GOOGLE_REDIRECT_URI` (default: `http://localhost:4200/oauth2callback`)
- Optional: `GOOGLE_DRIVE_FOLDER_ID`

Example:

```bash
flutter run -d windows \
  --dart-define=GOOGLE_CLIENT_ID=YOUR_CLIENT_ID \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_SERVER_CLIENT_ID \
  --dart-define=GOOGLE_CLIENT_SECRET=YOUR_CLIENT_SECRET \
  --dart-define=MYSQL_CONNECTION_URI=mysql://user:pass@host:4000/dbname
```

PowerShell helper from repo root (reads `credentials/connection-string.txt` automatically):

```powershell
./run_with_mysql.ps1 -Device windows -- --dart-define=GOOGLE_CLIENT_ID=... --dart-define=GOOGLE_SERVER_CLIENT_ID=... --dart-define=GOOGLE_CLIENT_SECRET=...
```

## Android / iOS credential placement

Use the helper script in repo root:

```powershell
./copy_credentials.ps1 -Android
./copy_credentials.ps1 -IOS
```

Targets:

- Android: `helium_reader/android/app/google-services.json`
- iOS: `helium_reader/ios/Runner/GoogleService-Info.plist`

## MySQL schema

Primary table: `book_progress`

- `user_email` + `drive_file_id` unique key
- `cfi` for exact restore when available
- `chapter` + `percent` fallback when CFI is unavailable
- `updated_at_ms` for last-write-wins conflict resolution
- `device_name` for audit/debug

Schema file:

- `helium_reader/database/mysql_schema.sql`

The app auto-creates this table on first successful DB connection.

## Implemented architecture

- Auth: `google_sign_in` + `flutter_secure_storage`
- Local DB: `sqflite` (`books`, `app_settings`)
- Drive API: EPUB discovery + download
- Sync engine:
  - local dirty progress -> MySQL upsert
  - MySQL newer progress -> local apply
  - conflict resolution by timestamp
  - per-book sync states: `Synced`, `Pending`, `Failed`
- Reader: `epub_view` (CFI + chapter/percent fallback tracking)
- Mobile background sync: `workmanager`
- Desktop window persistence: `window_manager`

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

- Downloaded books remain readable offline.
- Sync requires network and valid MySQL connection config.
- Google Drive is still used for book files and metadata; MySQL is only for reading progress.
