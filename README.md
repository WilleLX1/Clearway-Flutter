# Clearway Flutter

Clearway is a cross-platform, signal-aware route planner for Android, iOS,
Linux, macOS, Web, and Windows.

Routing runs entirely inside the Flutter application. The Helsingborg road
graph, traffic-control flags, time restrictions, and street-name index are
bundled as an application asset. No Python process or Clearway API server is
needed at runtime.

## Current features

- On-device Fastest and Clearway routing using edge-expanded A*
- Traffic-light, stop-sign, crossing, U-turn, and roundabout costs
- Day and departure-time handling for restricted roads
- Offline street-name search for the bundled Helsingborg region
- Interactive OpenStreetMap, route lines, pins, statistics, and ETA callouts
- Current-location display and high-accuracy foreground location tracking
- On-device turn-by-turn navigation with road-name maneuvers and live ETA
- Follow/recenter controls, route progress, and automatic off-route rerouting
- Responsive docked desktop panel and draggable mobile bottom sheet

The routing engine and street search are offline. The default OpenStreetMap
raster basemap still requires an internet connection.

## Run directly

```powershell
cd C:\projects\IOS\clearway
flutter pub get
flutter run -d chrome
```

Other targets include `windows`, `android`, `ios`, `macos`, and `linux`.

## iOS Simulator

iOS builds require macOS with Xcode and CocoaPods:

```bash
open -a Simulator
flutter devices
flutter run -d <simulator-id>
```

No backend process or API configuration is required.

To test navigation, start the app, choose a destination, select a route, and
press **Go**. Accept the location prompt. In Simulator, choose **Features >
Location > Custom Location** and enter a coordinate inside Helsingborg (for
example latitude `56.04905`, longitude `12.69044`). Change the simulated
location along the route to exercise maneuver advancement and rerouting.

Clearway requests location only while the app is in use. Background navigation
is intentionally not enabled.

## Build an IPA

On macOS, open `ios/Runner.xcworkspace` in Xcode and select a development team
and unique bundle identifier under **Runner > Signing & Capabilities**. Then:

```bash
flutter build ipa --release --build-name 1.0.0 --build-number 1
```

The archive is written to `build/ios/archive/` and the IPA to
`build/ios/ipa/`.

## Refresh the bundled routing graph

The application never executes Python, but the source OSM graph is converted
at development time. From Windows:

```powershell
$env:PYTHONDONTWRITEBYTECODE = "1"
C:\projects\_other\Clearway\.venv\Scripts\python.exe `
  .\tool\export_routing_graph.py
```

This regenerates:

- `assets/routing/helsingborg.graph.json`
- `test/fixtures/routing_goldens.json`

The golden routes are produced by the original Python engine and used to prove
that the Dart engine selects the same snapped nodes, exact edge paths, and
route statistics.

## Verify

```powershell
flutter analyze
flutter test
flutter build web
```

Before distributing the app, configure a production map-tile provider or
self-hosted tile package that meets the expected traffic volume and
attribution requirements.

On Web, live location requires HTTPS or `localhost`, and the browser will show
its own permission prompt. Desktop devices without a GPS may return a
network-derived position with lower accuracy.
