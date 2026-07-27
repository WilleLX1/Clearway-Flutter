# Clearway Flutter

The cross-platform Clearway client for Android, iOS, Linux, macOS, Web, and
Windows. It consumes the existing Clearway FastAPI backend and compares a
realistic fastest route with a route that strongly avoids signals, stop signs,
and crossings.

## Current features

- Interactive OpenStreetMap with route lines, pins, zoom controls, and ETA
  callouts
- Map-click and address-search origin/destination selection
- Fastest vs. Clearway route cards with distance, ETA, and road-control counts
- Day and departure-time routing for time-limited roads
- Responsive docked desktop panel and draggable mobile bottom sheet
- One typed API client and adaptive UI across every Flutter target

## Run locally

Start the existing backend first:

```powershell
cd C:\projects\_other\Clearway\backend
$env:CLEARWAY_NOMINATIM_URL = "https://nominatim.openstreetmap.org"
..\.venv\Scripts\python -m uvicorn app.main:app --port 8000
```

Then run the Flutter client:

```powershell
cd C:\projects\IOS\clearway
flutter pub get
flutter run -d windows
```

Other useful targets are `chrome`, `android`, `ios`, `macos`, and `linux`.

The development defaults are:

- Windows, iOS simulator, macOS, Linux, and Web:
  `http://127.0.0.1:8000`
- Android emulator: `http://10.0.2.2:8000`

For a physical device or deployed backend, provide its reachable HTTPS origin:

```powershell
flutter run -d <device> `
  --dart-define=CLEARWAY_API_BASE=https://clearway-api.example.com
```

The backend must allow the Flutter Web origin through CORS. Android debug and
profile builds permit local HTTP for development; production builds should use
HTTPS.

## Verify

```powershell
flutter analyze
flutter test
flutter build web
flutter build windows
```

The default raster map uses OpenStreetMap's public tile endpoint for
development. Before distributing the app, configure a production tile provider
or self-hosted tile service that meets the expected traffic volume and
attribution requirements.
