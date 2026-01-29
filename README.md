# Lumina Reader

Local-first EPUB reader for Desktop (Electron) and Mobile (Capacitor/Android) that syncs with Google Drive.

## Prerequisites
- Node.js + pnpm
- Java JDK (for Android builds)
- Android Studio (for running the Android app)

## Environment Variables
Create `.env.local` files for each app (templates included as `.env.example`):

### Desktop (`apps/desktop/.env.local`)
- `NEXT_PUBLIC_DESKTOP_CLIENT_ID` – Google OAuth Web Client ID (loopback).
- `NEXT_PUBLIC_DESKTOP_REDIRECT_URI` – Must match the redirect URI in Google Cloud (`http://localhost:4200/oauth2callback`).
- `LUMINA_DESKTOP_CLIENT_SECRET` – Web client secret (used only by Electron main process).
- `NEXT_PUBLIC_GOOGLE_PICKER_API_KEY` – API key for Google Picker (optional but required for folder picker).
- `NEXT_PUBLIC_GOOGLE_PICKER_APP_ID` – Google app ID (optional; use GCP project number).

### Mobile (`apps/mobile/.env.local`)
- `NEXT_PUBLIC_ANDROID_CLIENT_ID` – Android OAuth client ID.
- `NEXT_PUBLIC_MOBILE_WEB_CLIENT_ID` – Web client ID used by GoogleAuth (for serverClientId).
- `LUMINA_MOBILE_WEB_CLIENT_ID` – Same as above, used by Capacitor config at build time.
- `NEXT_PUBLIC_GOOGLE_PICKER_API_KEY` – API key for Google Picker (optional).
- `NEXT_PUBLIC_GOOGLE_PICKER_APP_ID` – Google app ID / project number (optional).

## Google Cloud Setup (minimum)
1) Enable **Google Drive API**.
2) OAuth consent screen: add scopes
   - `https://www.googleapis.com/auth/drive.readonly`
   - `https://www.googleapis.com/auth/drive.appdata`
3) Create OAuth clients:
   - Web client (loopback) for Desktop
   - Android client (package name + SHA-1) for Mobile
   - Web client (serverClientId) for Mobile

## Firebase / google-services.json
1) Add the same Google Cloud project to Firebase.
2) Add an Android app with package name `com.example.reader` (or your chosen package).
3) Download `google-services.json` and place it at:
   - `apps/mobile/android/app/google-services.json`

## Running

### Desktop (Next + Electron)
```
pnpm --filter desktop dev
```

### Mobile (Web build + Android sync)
```
pnpm --filter mobile build
npx cap sync android
```

Then open `apps/mobile/android` in Android Studio and run.

## Notes
- `google-services.json` and `.env.local` are ignored by git.
- Folder picker uses Google Picker API; set the API key in Settings or via env.
