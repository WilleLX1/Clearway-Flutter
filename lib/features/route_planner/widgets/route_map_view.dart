import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/clearway_theme.dart';
import '../../../models/clearway_models.dart';
import '../route_planner_controller.dart';

class RouteMapView extends StatefulWidget {
  const RouteMapView({
    super.key,
    required this.controller,
    required this.mobileSheetVisible,
  });

  final RoutePlannerController controller;
  final bool mobileSheetVisible;

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  final _mapController = MapController();
  bool _mapReady = false;
  int _lastRouteSignature = 0;

  LatLng _latLng(ClearwayPoint point) => LatLng(point.lat, point.lon);

  @override
  void didUpdateWidget(covariant RouteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final signature = Object.hashAll(
      widget.controller.routes.map(
        (route) => Object.hash(
          route.profile,
          route.coordinates.length,
          route.coordinates.firstOrNull?.lat,
          route.coordinates.lastOrNull?.lon,
        ),
      ),
    );
    if (signature != _lastRouteSignature &&
        widget.controller.routes.isNotEmpty) {
      _lastRouteSignature = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoutes());
    } else if (oldWidget.controller.meta == null &&
        widget.controller.meta != null &&
        widget.controller.routes.isEmpty &&
        widget.controller.origin == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_mapReady && mounted) {
          _mapController.move(_latLng(widget.controller.meta!.center), 12.5);
        }
      });
    }
  }

  void _fitRoutes() {
    if (!_mapReady || !mounted) return;
    final coordinates = widget.controller.routes
        .expand((route) => route.coordinates)
        .map(_latLng)
        .toList(growable: false);
    if (coordinates.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: coordinates,
        padding: EdgeInsets.fromLTRB(
          70,
          80,
          70,
          widget.mobileSheetVisible
              ? MediaQuery.sizeOf(context).height * 0.58
              : 80,
        ),
        maxZoom: 15,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planner = widget.controller;
    final center =
        planner.meta?.center ?? const ClearwayPoint(lat: 56.0465, lon: 12.6945);
    final selectedRoutes = planner.routes.where(
      (route) => route.profile == planner.selectedProfile,
    );
    final alternateRoutes = planner.routes.where(
      (route) => route.profile != planner.selectedProfile,
    );

    final polylines = <Polyline>[
      ...alternateRoutes.map(
        (route) => Polyline(
          points: route.coordinates.map(_latLng).toList(growable: false),
          color: ClearwayColors.alternateRoute,
          borderColor: ClearwayColors.alternateRouteBorder,
          strokeWidth: 6,
          borderStrokeWidth: 2,
        ),
      ),
      ...selectedRoutes.map(
        (route) => Polyline(
          points: route.coordinates.map(_latLng).toList(growable: false),
          color: ClearwayColors.routeBlue,
          borderColor: ClearwayColors.routeBlueDark,
          strokeWidth: 7,
          borderStrokeWidth: 2.5,
        ),
      ),
    ];

    return ColoredBox(
      color: ClearwayColors.mapBackground,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _latLng(center),
          initialZoom: 12.5,
          minZoom: 3,
          maxZoom: 19,
          onMapReady: () {
            _mapReady = true;
            if (planner.routes.isNotEmpty) _fitRoutes();
          },
          onTap: (_, point) => planner.handleMapTap(
            ClearwayPoint(lat: point.latitude, lon: point.longitude),
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.clearway.clearway',
            maxZoom: 19,
          ),
          if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
          if (planner.currentLocation != null)
            CircleLayer(
              circles: [
                CircleMarker(
                  point: _latLng(planner.currentLocation!.point),
                  radius: planner.currentLocation!.accuracyM.clamp(6, 100),
                  useRadiusInMeter: true,
                  color: ClearwayColors.blue.withValues(alpha: 0.10),
                  borderColor: ClearwayColors.blue.withValues(alpha: 0.25),
                  borderStrokeWidth: 1,
                ),
              ],
            ),
          MarkerLayer(markers: _markers(planner)),
          _MapControls(
            mapController: _mapController,
            locating: planner.locating,
            onLocate: () async {
              final sample = await planner.locate();
              if (!context.mounted) return;
              if (sample != null) {
                _mapController.move(_latLng(sample.point), 16);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      planner.locationError ??
                          'Could not determine your location.',
                    ),
                  ),
                );
              }
            },
          ),
          const _Attribution(),
        ],
      ),
    );
  }

  List<Marker> _markers(RoutePlannerController planner) {
    final markers = <Marker>[];
    final origin = planner.origin;
    final destination = planner.destination;
    final current = planner.currentLocation;
    if (current != null) {
      markers.add(
        Marker(
          point: _latLng(current.point),
          width: 32,
          height: 32,
          child: const _CurrentLocationMarker(),
        ),
      );
    }
    if (origin != null) {
      markers.add(
        Marker(
          point: _latLng(origin),
          width: 24,
          height: 24,
          child: const _OriginMarker(),
        ),
      );
    }
    if (destination != null) {
      markers.add(
        Marker(
          point: _latLng(destination),
          width: 42,
          height: 46,
          alignment: Alignment.topCenter,
          child: const Icon(
            Icons.location_on,
            size: 40,
            color: ClearwayColors.red,
            shadows: [
              Shadow(
                color: Color(0x55000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      );
    }

    for (var index = 0; index < planner.routes.length; index++) {
      final route = planner.routes[index];
      if (route.coordinates.isEmpty) continue;
      final selected = route.profile == planner.selectedProfile;
      final point =
          route.coordinates[(route.coordinates.length *
                  (index == 0 ? 0.45 : 0.7))
              .floor()
              .clamp(0, route.coordinates.length - 1)];
      markers.add(
        Marker(
          point: _latLng(point),
          width: 122,
          height: 44,
          alignment: Alignment.bottomCenter,
          child: _EtaBubble(
            route: route,
            selected: selected,
            onTap: () => planner.selectProfile(route.profile),
          ),
        ),
      );
    }
    return markers;
  }
}

class _OriginMarker extends StatelessWidget {
  const _OriginMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 15,
        height: 15,
        decoration: BoxDecoration(
          color: const Color(0xFF3C4043),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: ClearwayColors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 5)],
        ),
      ),
    );
  }
}

class _EtaBubble extends StatelessWidget {
  const _EtaBubble({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  final ClearwayRoute route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        elevation: 3,
        color: selected ? ClearwayColors.blue : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatDuration(route.stats.estimatedTimeS),
                  style: TextStyle(
                    color: selected ? Colors.white : ClearwayColors.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  formatDistance(route.stats.distanceM),
                  style: TextStyle(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.85)
                        : ClearwayColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.mapController,
    required this.onLocate,
    required this.locating,
  });

  final MapController mapController;
  final VoidCallback onLocate;
  final bool locating;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      top: 16,
      child: Column(
        children: [
          Material(
            elevation: 3,
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                IconButton(
                  tooltip: 'Zoom in',
                  onPressed: () => mapController.move(
                    mapController.camera.center,
                    mapController.camera.zoom + 1,
                  ),
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 40, child: Divider(height: 1)),
                IconButton(
                  tooltip: 'Zoom out',
                  onPressed: () => mapController.move(
                    mapController.camera.center,
                    mapController.camera.zoom - 1,
                  ),
                  icon: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Material(
            elevation: 3,
            color: Colors.white,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Show my location',
              onPressed: locating ? null : onLocate,
              icon: locating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 5,
      bottom: 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            '© OpenStreetMap contributors',
            style: TextStyle(
              fontSize: 9.5,
              color: ClearwayColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
