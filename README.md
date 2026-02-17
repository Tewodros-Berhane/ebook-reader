# Helium Reader

Helium Reader is a cross-platform EPUB reader (Windows + Android) with offline-first reading and Google Drive sync.

## What this app does

- Lists EPUB files from your Google Drive
- Downloads books locally for offline reading
- Saves reading progress continuously while you read
- Syncs progress across devices using a hidden `sync.json` file in Drive `appDataFolder`

No hosted backend is required.

## Core features

- **Offline-first**: already-downloaded books open without internet
- **Persistent login**: silent sign-in on startup when session is still valid
- **Cross-device progress**: Windows and Android read/write the same `sync.json`
- **Conflict handling**: newer progress wins, with regression guards to avoid accidental rewinds
- **Folder scoping**: optionally choose one Drive folder to scope EPUB discovery

## How sync works

1. App stores local progress in SQLite (`isDirty`, timestamp, locator data)
2. On sync, app fetches `sync.json` from Drive appDataFolder
3. App merges local + cloud entries by `fileId`
4. Dirty local records are uploaded, cloud-newer records are pulled locally
5. Uploaded records are marked clean

Each book entry in `sync.json` stores:

- `cfi`
- `chapter` / `percent` fallback
- `locator` (structured position)
- `ts` (timestamp)

## Repository layout

- `helium_reader/` ? Flutter app
- `credentials/` ? local credential files (gitignored)
- `copy_credentials.ps1` ? copy Google config files into Flutter project
- `run_helium.ps1` ? run helper script
- `build_release.ps1` ? build APK + Windows installer

## Prerequisites

- Flutter SDK (stable)
- Android SDK + Android Studio (for Android builds)
- Visual Studio with Desktop C++ workload (for Windows builds)
- Inno Setup 6 (for Windows installer generation)

## Credentials setup

Keep secrets in `credentials/` (already ignored by git):

- OAuth client IDs/secrets (desktop/web/android)
- `google-services.json` for Android

Copy Android credential file into the Flutter app:

```powershell
./copy_credentials.ps1 -Android
```

## Run the app

From repo root:

```powershell
./run_helium.ps1 -Device windows -- --dart-define=GOOGLE_CLIENT_ID=... --dart-define=GOOGLE_SERVER_CLIENT_ID=... --dart-define=GOOGLE_CLIENT_SECRET=...
```

Android example:

```powershell
./run_helium.ps1 -Device android -- --dart-define=GOOGLE_CLIENT_ID=... --dart-define=GOOGLE_SERVER_CLIENT_ID=...
```

Legacy alias still works:

```powershell
./run_with_mysql.ps1 ...
```

## Build installable outputs

```powershell
./build_release.ps1
```

Outputs:

- `helium_reader/build/app/outputs/flutter-apk/app-release.apk`
- `helium_reader/build/windows/x64/runner/Release/helium_reader.exe`
- `helium_reader/build/installer/HeliumReaderSetup.exe`

## Debugging

Run with verbose logs:

```powershell
./run_helium.ps1 -Device windows -- -v --dart-define=GOOGLE_CLIENT_ID=... --dart-define=GOOGLE_SERVER_CLIENT_ID=... --dart-define=GOOGLE_CLIENT_SECRET=...
```

Sync logs are prefixed with `helium.sync`.

## Security notes

- Do not commit files from `credentials/`
- Do not hardcode OAuth secrets in source
- Use `--dart-define` for local/dev runtime values
