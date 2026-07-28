import 'dart:math' as math;

import '../models/clearway_models.dart';

class RouteProgress {
  const RouteProgress({
    required this.nearestPoint,
    required this.distanceFromRouteM,
    required this.distanceAlongRouteM,
    required this.totalDistanceM,
    required this.segmentIndex,
  });

  final ClearwayPoint nearestPoint;
  final double distanceFromRouteM;
  final double distanceAlongRouteM;
  final double totalDistanceM;
  final int segmentIndex;

  double get remainingDistanceM =>
      math.max(0, totalDistanceM - distanceAlongRouteM);

  double get fraction => totalDistanceM <= 0
      ? 1
      : (distanceAlongRouteM / totalDistanceM).clamp(0, 1);
}

RouteProgress locateOnRoute(ClearwayPoint location, List<ClearwayPoint> route) {
  if (route.isEmpty) {
    return RouteProgress(
      nearestPoint: location,
      distanceFromRouteM: double.infinity,
      distanceAlongRouteM: 0,
      totalDistanceM: 0,
      segmentIndex: 0,
    );
  }
  if (route.length == 1) {
    final distance = _metresBetween(location, route.first);
    return RouteProgress(
      nearestPoint: route.first,
      distanceFromRouteM: distance,
      distanceAlongRouteM: 0,
      totalDistanceM: 0,
      segmentIndex: 0,
    );
  }

  final referenceLat = location.lat * math.pi / 180;
  final metresPerLon = 111320 * math.cos(referenceLat);
  const metresPerLat = 110540.0;
  double x(ClearwayPoint point) => (point.lon - location.lon) * metresPerLon;
  double y(ClearwayPoint point) => (point.lat - location.lat) * metresPerLat;

  var bestDistance = double.infinity;
  var bestAlong = 0.0;
  var totalBefore = 0.0;
  var bestSegment = 0;
  var bestPoint = route.first;
  final segmentLengths = <double>[];

  for (var index = 0; index + 1 < route.length; index++) {
    final a = route[index];
    final b = route[index + 1];
    final ax = x(a);
    final ay = y(a);
    final bx = x(b);
    final by = y(b);
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    final fraction = lengthSquared == 0
        ? 0.0
        : (-(ax * dx + ay * dy) / lengthSquared).clamp(0.0, 1.0);
    final nearestX = ax + dx * fraction;
    final nearestY = ay + dy * fraction;
    final distance = math.sqrt(nearestX * nearestX + nearestY * nearestY);
    final segmentLength = math.sqrt(lengthSquared);
    segmentLengths.add(segmentLength);
    if (distance < bestDistance) {
      bestDistance = distance;
      bestAlong = totalBefore + segmentLength * fraction;
      bestSegment = index;
      bestPoint = ClearwayPoint(
        lat: a.lat + (b.lat - a.lat) * fraction,
        lon: a.lon + (b.lon - a.lon) * fraction,
      );
    }
    totalBefore += segmentLength;
  }

  return RouteProgress(
    nearestPoint: bestPoint,
    distanceFromRouteM: bestDistance,
    distanceAlongRouteM: bestAlong,
    totalDistanceM: segmentLengths.fold(0, (sum, value) => sum + value),
    segmentIndex: bestSegment,
  );
}

double _metresBetween(ClearwayPoint a, ClearwayPoint b) {
  final lat = (a.lat + b.lat) / 2 * math.pi / 180;
  final dx = (a.lon - b.lon) * 111320 * math.cos(lat);
  final dy = (a.lat - b.lat) * 110540;
  return math.sqrt(dx * dx + dy * dy);
}
