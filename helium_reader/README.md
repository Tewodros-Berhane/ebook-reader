# Helium Reader (Flutter app)

This folder contains the Flutter client for Helium Reader.

For full project setup, architecture, and build instructions, see the repo root `README.md`.

## Quick run

```powershell
../run_helium.ps1 -Device windows -- --dart-define=GOOGLE_CLIENT_ID=... --dart-define=GOOGLE_SERVER_CLIENT_ID=... --dart-define=GOOGLE_CLIENT_SECRET=...
```

## Key runtime defines

Required:

- `GOOGLE_CLIENT_ID`
- `GOOGLE_SERVER_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET` (desktop OAuth)

Optional:

- `GOOGLE_REDIRECT_URI`
- `GOOGLE_DRIVE_FOLDER_ID`
