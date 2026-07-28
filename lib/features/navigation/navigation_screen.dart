import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/clearway_theme.dart';
import '../../models/clearway_models.dart';
import '../../navigation/route_progress.dart';
import '../route_planner/route_planner_controller.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    super.key,
    required this.controller,
    required this.initialRoute,
    required this.destination,
  });

  final RoutePlannerController controller;
  final ClearwayRoute initialRoute;
  final ClearwayPoint destination;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final _mapController = MapController();
  late ClearwayRoute _route;
  RouteProgress? _progress;
  bool _mapReady = false;
  bool _following = true;
  bool _rerouting = false;
  int _offRouteSamples = 0;
  DateTime? _lastReroute;

  LatLng _latLng(ClearwayPoint point) => LatLng(point.lat, point.lon);

  @override
  void initState() {
    super.initState();
    _route = widget.initialRoute;
    widget.controller.addListener(_onLocationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onLocationChanged());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onLocationChanged);
    super.dispose();
  }

  void _onLocationChanged() {
    final sample = widget.controller.currentLocation;
    if (sample == null || _route.coordinates.isEmpty || !mounted) return;
    final progress = locateOnRoute(sample.point, _route.coordinates);
    _progress = progress;
    if (_mapReady && _following) {
      _mapController.move(_latLng(sample.point), 17);
    }
    if (progress.distanceFromRouteM > 45 &&
        sample.accuracyM <= 50 &&
        progress.remainingDistanceM > 30) {
      _offRouteSamples++;
    } else {
      _offRouteSamples = 0;
    }
    if (_offRouteSamples >= 3) unawaited(_reroute(sample.point));
    setState(() {});
  }

  Future<void> _reroute(ClearwayPoint point) async {
    final now = DateTime.now();
    if (_rerouting ||
        (_lastReroute != null &&
            now.difference(_lastReroute!) < const Duration(seconds: 12))) {
      return;
    }
    _rerouting = true;
    _lastReroute = now;
    _offRouteSamples = 0;
    if (mounted) setState(() {});
    final route = await widget.controller.rerouteFrom(point);
    if (route != null && mounted) {
      _route = route;
      final sample = widget.controller.currentLocation;
      _progress = sample == null
          ? null
          : locateOnRoute(sample.point, route.coordinates);
    }
    _rerouting = false;
    if (mounted) setState(() {});
  }

  void _recenter() {
    final location = widget.controller.currentLocation?.point;
    if (location == null) return;
    _following = true;
    _mapController.move(_latLng(location), 17);
    setState(() {});
  }

  RouteInstruction get _instruction {
    final instructions = _route.instructions;
    if (instructions.isEmpty) {
      return RouteInstruction(
        type: ManeuverType.arrive,
        point: widget.destination,
        distanceFromStartM: _route.stats.distanceM,
      );
    }
    final travelled = (_progress?.fraction ?? 0) * _route.stats.distanceM;
    if ((_progress?.remainingDistanceM ?? double.infinity) < 22) {
      return instructions.last;
    }
    if (travelled < 20 && instructions.first.type == ManeuverType.depart) {
      return instructions.first;
    }
    return instructions.firstWhere(
      (step) => step.distanceFromStartM > travelled + 8,
      orElse: () => instructions.last,
    );
  }

  double get _distanceToInstruction {
    final travelled = (_progress?.fraction ?? 0) * _route.stats.distanceM;
    return math.max(0, _instruction.distanceFromStartM - travelled);
  }

  double get _remainingDistance => (_progress?.fraction == null)
      ? _route.stats.distanceM
      : _route.stats.distanceM * (1 - _progress!.fraction);

  double get _remainingTime {
    if (_route.stats.distanceM <= 0) return 0;
    return _route.stats.estimatedTimeS *
        (_remainingDistance / _route.stats.distanceM).clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final sample = widget.controller.currentLocation;
    final current = sample?.point ?? _route.coordinates.first;
    final progress = _progress;
    final traveledPoints = progress == null
        ? const <ClearwayPoint>[]
        : _route.coordinates
              .take(progress.segmentIndex + 1)
              .followedBy([progress.nearestPoint])
              .toList(growable: false);
    final remainingPoints = progress == null
        ? _route.coordinates
        : [
            progress.nearestPoint,
            ..._route.coordinates.skip(progress.segmentIndex + 1),
          ];

    return Scaffold(
      backgroundColor: const Color(0xFF17202A),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _latLng(current),
              initialZoom: 17,
              minZoom: 3,
              maxZoom: 19,
              onMapReady: () {
                _mapReady = true;
                _recenter();
              },
              onPositionChanged: (_, hasGesture) {
                if (hasGesture && _following) {
                  setState(() => _following = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.clearway.clearway',
                maxZoom: 19,
              ),
              if (sample != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _latLng(sample.point),
                      radius: math.max(sample.accuracyM, 6),
                      useRadiusInMeter: true,
                      color: ClearwayColors.blue.withValues(alpha: 0.12),
                      borderColor: ClearwayColors.blue.withValues(alpha: 0.3),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
              PolylineLayer(
                polylines: [
                  if (traveledPoints.length > 1)
                    Polyline(
                      points: traveledPoints.map(_latLng).toList(),
                      strokeWidth: 7,
                      color: const Color(0xFF94A1AD),
                    ),
                  if (remainingPoints.length > 1)
                    Polyline(
                      points: remainingPoints.map(_latLng).toList(),
                      strokeWidth: 8,
                      borderStrokeWidth: 2,
                      borderColor: ClearwayColors.routeBlueDark,
                      color: ClearwayColors.routeBlue,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _latLng(widget.destination),
                    width: 42,
                    height: 46,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_on,
                      size: 42,
                      color: ClearwayColors.red,
                    ),
                  ),
                  if (sample != null)
                    Marker(
                      point: _latLng(sample.point),
                      width: 52,
                      height: 52,
                      child: _NavigationMarker(heading: sample.heading),
                    ),
                ],
              ),
              const _MapAttribution(),
            ],
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Align(
              alignment: Alignment.topCenter,
              child: _InstructionBanner(
                instruction: _instruction,
                distanceM: _distanceToInstruction,
                rerouting: _rerouting,
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 170,
            child: FloatingActionButton(
              heroTag: 'navigation-recenter',
              tooltip: 'Recenter',
              onPressed: _recenter,
              backgroundColor: Colors.white,
              foregroundColor: _following
                  ? ClearwayColors.blue
                  : ClearwayColors.text,
              child: Icon(_following ? Icons.navigation : Icons.my_location),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _TripProgressPanel(
              remainingTimeS: _remainingTime,
              remainingDistanceM: _remainingDistance,
              onEnd: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionBanner extends StatelessWidget {
  const _InstructionBanner({
    required this.instruction,
    required this.distanceM,
    required this.rerouting,
  });

  final RouteInstruction instruction;
  final double distanceM;
  final bool rerouting;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Material(
        elevation: 8,
        color: const Color(0xFF076B65),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            children: [
              Icon(
                _maneuverIcon(instruction.type),
                color: Colors.white,
                size: 52,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rerouting
                          ? 'Finding a new route…'
                          : instruction.type == ManeuverType.arrive
                          ? 'Destination'
                          : formatDistance(distanceM),
                      style: const TextStyle(
                        color: Color(0xFFD2F5EF),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      instruction.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        height: 1.12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripProgressPanel extends StatelessWidget {
  const _TripProgressPanel({
    required this.remainingTimeS,
    required this.remainingDistanceM,
    required this.onEnd,
  });

  final double remainingTimeS;
  final double remainingDistanceM;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final arrival = DateTime.now().add(
      Duration(seconds: remainingTimeS.round()),
    );
    final arrivalText = TimeOfDay.fromDateTime(arrival).format(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Material(
          elevation: 10,
          color: const Color(0xFF151618),
          borderRadius: BorderRadius.circular(26),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 14, 15),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatDuration(remainingTimeS),
                        style: const TextStyle(
                          color: Color(0xFF69DB8B),
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${formatDistance(remainingDistanceM)} · $arrivalText',
                        style: const TextStyle(
                          color: Color(0xFFBEC4C9),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: onEnd,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEA4335),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 17,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('End'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationMarker extends StatelessWidget {
  const _NavigationMarker({required this.heading});

  final double heading;

  @override
  Widget build(BuildContext context) {
    final validHeading = heading.isFinite && heading >= 0 ? heading : 0.0;
    return Transform.rotate(
      angle: validHeading * math.pi / 180,
      child: const Icon(
        Icons.navigation,
        size: 44,
        color: ClearwayColors.blue,
        shadows: [
          Shadow(color: Colors.white, blurRadius: 4),
          Shadow(color: Color(0x66000000), blurRadius: 7),
        ],
      ),
    );
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      right: 5,
      bottom: 142,
      child: ColoredBox(
        color: Color(0xCCFFFFFF),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            '© OpenStreetMap contributors',
            style: TextStyle(fontSize: 9, color: ClearwayColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

IconData _maneuverIcon(ManeuverType type) => switch (type) {
  ManeuverType.depart => Icons.straight,
  ManeuverType.continueStraight => Icons.straight,
  ManeuverType.slightLeft => Icons.turn_slight_left,
  ManeuverType.turnLeft => Icons.turn_left,
  ManeuverType.sharpLeft => Icons.turn_sharp_left,
  ManeuverType.slightRight => Icons.turn_slight_right,
  ManeuverType.turnRight => Icons.turn_right,
  ManeuverType.sharpRight => Icons.turn_sharp_right,
  ManeuverType.uTurn => Icons.u_turn_left,
  ManeuverType.enterRoundabout => Icons.roundabout_right,
  ManeuverType.exitRoundabout => Icons.turn_right,
  ManeuverType.arrive => Icons.flag,
};
