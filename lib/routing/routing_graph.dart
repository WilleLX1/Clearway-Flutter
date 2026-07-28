import 'dart:convert';

import '../models/clearway_models.dart';
import 'routing_geo.dart';

class RoutingNode {
  const RoutingNode({
    required this.lon,
    required this.lat,
    required this.flags,
    required this.restrictedComponent,
  });

  final double lon;
  final double lat;
  final int flags;
  final int restrictedComponent;

  bool get isSignal => flags & 1 != 0;
  bool get isStop => flags & 2 != 0;
  bool get isCrossing => flags & 4 != 0;
  bool get isMiniRoundabout => flags & 8 != 0;
}

class RoutingEdge {
  const RoutingEdge({
    required this.tail,
    required this.head,
    required this.travelTime,
    required this.length,
    required this.isRoundabout,
    required this.departureBearing,
    required this.arrivalBearing,
    required this.ruleIndex,
    required this.coordinates,
    required this.roadName,
  });

  final int tail;
  final int head;
  final double travelTime;
  final double length;
  final bool isRoundabout;
  final double departureBearing;
  final double arrivalBearing;
  final int ruleIndex;
  final List<ClearwayPoint> coordinates;
  final String roadName;
}

class AccessWindow {
  const AccessWindow({
    required this.dayMask,
    required this.startMinute,
    required this.endMinute,
  });

  final int dayMask;
  final int startMinute;
  final int endMinute;

  bool contains(int weekday, int minute) {
    if (dayMask & (1 << weekday) == 0) return false;
    return startMinute <= endMinute
        ? startMinute <= minute && minute < endMinute
        : minute >= startMinute || minute < endMinute;
  }
}

class AccessRule {
  const AccessRule({required this.openOnly, required this.windows});

  final bool openOnly;
  final List<AccessWindow> windows;

  bool isClosedAt(int weekday, int minute) {
    final inside = windows.any((window) => window.contains(weekday, minute));
    return openOnly ? !inside : inside;
  }
}

class LocalStreet {
  const LocalStreet({required this.name, required this.lat, required this.lon});

  final String name;
  final double lat;
  final double lon;

  GeocodeResult toResult() =>
      GeocodeResult(label: '$name, Helsingborg', lat: lat, lon: lon);
}

class RoutingGraph {
  RoutingGraph({
    required this.region,
    required this.maxSpeedMps,
    required this.bounds,
    required this.nodes,
    required this.edges,
    required this.rules,
    required this.streets,
  }) : outEdges = List.generate(nodes.length, (_) => <int>[]) {
    for (var edgeId = 0; edgeId < edges.length; edgeId++) {
      outEdges[edges[edgeId].tail].add(edgeId);
    }
  }

  factory RoutingGraph.fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    if (json['version'] != 1) {
      throw FormatException(
        'Unsupported routing graph version ${json['version']}.',
      );
    }

    final nodes = (json['nodes'] as List<dynamic>)
        .map((raw) {
          final values = raw as List<dynamic>;
          return RoutingNode(
            lon: (values[0] as num).toDouble(),
            lat: (values[1] as num).toDouble(),
            flags: values[2] as int,
            restrictedComponent: values[3] as int,
          );
        })
        .toList(growable: false);

    final rules = (json['rules'] as List<dynamic>)
        .map((raw) {
          final values = raw as List<dynamic>;
          return AccessRule(
            openOnly: values[0] == 1,
            windows: (values[1] as List<dynamic>)
                .map((rawWindow) {
                  final window = rawWindow as List<dynamic>;
                  return AccessWindow(
                    dayMask: window[0] as int,
                    startMinute: window[1] as int,
                    endMinute: window[2] as int,
                  );
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false);

    final edges = (json['edges'] as List<dynamic>)
        .map((raw) {
          final values = raw as List<dynamic>;
          final flatCoordinates = values[8] as List<dynamic>;
          final coordinates = <ClearwayPoint>[];
          for (var index = 0; index < flatCoordinates.length; index += 2) {
            coordinates.add(
              ClearwayPoint(
                lon: (flatCoordinates[index] as num).toDouble(),
                lat: (flatCoordinates[index + 1] as num).toDouble(),
              ),
            );
          }
          return RoutingEdge(
            tail: values[0] as int,
            head: values[1] as int,
            travelTime: (values[2] as num).toDouble(),
            length: (values[3] as num).toDouble(),
            isRoundabout: values[4] == 1,
            departureBearing: (values[5] as num).toDouble(),
            arrivalBearing: (values[6] as num).toDouble(),
            ruleIndex: values[7] as int,
            coordinates: coordinates,
            roadName: values.length > 9 ? values[9] as String : '',
          );
        })
        .toList(growable: false);

    final streets = (json['places'] as List<dynamic>)
        .map((raw) {
          final values = raw as List<dynamic>;
          return LocalStreet(
            name: values[0] as String,
            lat: (values[1] as num).toDouble(),
            lon: (values[2] as num).toDouble(),
          );
        })
        .toList(growable: false);

    return RoutingGraph(
      region: json['region'] as String,
      maxSpeedMps: (json['max_speed_mps'] as num).toDouble(),
      bounds: (json['bounds'] as List<dynamic>)
          .map((value) => (value as num).toDouble())
          .toList(growable: false),
      nodes: nodes,
      edges: edges,
      rules: rules,
      streets: streets,
    );
  }

  final String region;
  final double maxSpeedMps;
  final List<double> bounds;
  final List<RoutingNode> nodes;
  final List<RoutingEdge> edges;
  final List<AccessRule> rules;
  final List<LocalStreet> streets;
  final List<List<int>> outEdges;

  int nearestNode(double lon, double lat) {
    var nearest = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      final distance = haversineMetres(lon, lat, node.lon, node.lat);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = index;
      }
    }
    return nearest;
  }

  List<GeocodeResult> searchStreets(String query, {int limit = 6}) {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return const [];
    final matches = <({int score, LocalStreet street})>[];
    for (final street in streets) {
      final name = street.name.toLowerCase();
      final containsAt = name.indexOf(normalized);
      if (containsAt < 0) continue;
      final wordStart =
          containsAt == 0 ||
          (containsAt > 0 && name.codeUnitAt(containsAt - 1) == 32);
      matches.add((
        score: containsAt == 0 ? 0 : (wordStart ? 1 : 2),
        street: street,
      ));
    }
    matches.sort((a, b) {
      final score = a.score.compareTo(b.score);
      if (score != 0) return score;
      final length = a.street.name.length.compareTo(b.street.name.length);
      if (length != 0) return length;
      return a.street.name.compareTo(b.street.name);
    });
    return matches
        .take(limit)
        .map((match) => match.street.toResult())
        .toList(growable: false);
  }
}
