import 'dart:convert';
import 'dart:io';

import 'package:clearway/models/clearway_models.dart';
import 'package:clearway/routing/local_routing_engine.dart';
import 'package:clearway/routing/routing_graph.dart';
import 'package:clearway/routing/routing_weights.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LocalRoutingEngine engine;
  late List<dynamic> cases;

  setUpAll(() async {
    final graphSource = await File(
      'assets/routing/helsingborg.graph.json',
    ).readAsString();
    engine = LocalRoutingEngine(RoutingGraph.fromJsonString(graphSource));
    final goldenSource = await File(
      'test/fixtures/routing_goldens.json',
    ).readAsString();
    cases =
        (jsonDecode(goldenSource) as Map<String, dynamic>)['cases']
            as List<dynamic>;
  });

  test('loads the complete portable Helsingborg graph', () {
    expect(engine.graph.nodes, hasLength(6548));
    expect(engine.graph.edges, hasLength(14136));
    expect(engine.graph.streets.length, greaterThan(1500));
    expect(engine.graph.rules, hasLength(1));
    expect(
      engine.graph.edges.where((edge) => edge.roadName.isNotEmpty).length,
      greaterThan(1000),
    );
  });

  test('local street search works without a geocoding server', () {
    final results = engine.graph.searchStreets('strandgatan');

    expect(results, isNotEmpty);
    expect(results.first.label.toLowerCase(), contains('strandgatan'));
  });

  test(
    'access rules handle weekdays, overnight windows, and open-only mode',
    () {
      const weekdayClosure = AccessRule(
        openOnly: false,
        windows: [
          AccessWindow(dayMask: 0x1F, startMinute: 420, endMinute: 540),
        ],
      );
      const overnightClosure = AccessRule(
        openOnly: false,
        windows: [
          AccessWindow(dayMask: 0x7F, startMinute: 1320, endMinute: 360),
        ],
      );
      const openOnly = AccessRule(
        openOnly: true,
        windows: [
          AccessWindow(dayMask: 0x7F, startMinute: 540, endMinute: 1020),
        ],
      );

      expect(weekdayClosure.isClosedAt(0, 480), isTrue);
      expect(weekdayClosure.isClosedAt(5, 480), isFalse);
      expect(overnightClosure.isClosedAt(2, 60), isTrue);
      expect(overnightClosure.isClosedAt(2, 720), isFalse);
      expect(openOnly.isClosedAt(2, 480), isTrue);
      expect(openOnly.isClosedAt(2, 720), isFalse);
    },
  );

  test('Dart routing matches Python golden edge paths and statistics', () {
    for (final rawCase in cases) {
      final routeCase = rawCase as Map<String, dynamic>;
      final originValues = routeCase['origin'] as List<dynamic>;
      final destinationValues = routeCase['destination'] as List<dynamic>;
      final origin = ClearwayPoint(
        lat: (originValues[0] as num).toDouble(),
        lon: (originValues[1] as num).toDouble(),
      );
      final destination = ClearwayPoint(
        lat: (destinationValues[0] as num).toDouble(),
        lon: (destinationValues[1] as num).toDouble(),
      );
      final expectedRoutes = routeCase['routes'] as Map<String, dynamic>;

      for (final profile in const ['fastest', 'clearway']) {
        final expected = expectedRoutes[profile] as Map<String, dynamic>;
        final originNode = engine.graph.nearestNode(origin.lon, origin.lat);
        final destinationNode = engine.graph.nearestNode(
          destination.lon,
          destination.lat,
        );
        expect(
          originNode,
          expected['origin_node'],
          reason: '${routeCase['name']} $profile origin snap',
        );
        expect(
          destinationNode,
          expected['destination_node'],
          reason: '${routeCase['name']} $profile destination snap',
        );

        final path = engine.routeEdges(
          originNode: originNode,
          destinationNode: destinationNode,
          weights: RoutingWeights.forProfile(profile),
          weekday: routeCase['weekday'] as int,
          minute: routeCase['minute'] as int,
        );
        expect(
          path,
          expected['path'],
          reason: '${routeCase['name']} $profile edge path',
        );

        final route = engine.route(
          origin: origin,
          destination: destination,
          profile: profile,
          weekday: routeCase['weekday'] as int,
          minute: routeCase['minute'] as int,
        );
        expect(route, isNotNull);
        expect(route!.instructions.first.type, ManeuverType.depart);
        expect(route.instructions.last.type, ManeuverType.arrive);
        expect(
          route.instructions.any(
            (instruction) => instruction.roadName.isNotEmpty,
          ),
          isTrue,
        );
        _expectStats(
          route.stats,
          expected['stats'] as Map<String, dynamic>,
          '${routeCase['name']} $profile',
        );
      }
    }
  });
}

void _expectStats(
  RouteStats actual,
  Map<String, dynamic> expected,
  String reason,
) {
  expect(actual.distanceM, expected['distance_m'], reason: '$reason distance');
  expect(
    actual.baseTimeS,
    expected['base_time_s'],
    reason: '$reason base time',
  );
  expect(
    actual.estimatedTimeS,
    expected['est_time_s'],
    reason: '$reason estimated time',
  );
  expect(actual.signals, expected['signals'], reason: '$reason signals');
  expect(actual.stops, expected['stops'], reason: '$reason stops');
  expect(actual.crossings, expected['crossings'], reason: '$reason crossings');
  expect(actual.uturns, expected['uturns'], reason: '$reason uturns');
  expect(
    actual.roundabouts,
    expected['roundabouts'],
    reason: '$reason roundabouts',
  );
  expect(
    actual.potentialStops,
    expected['potential_stops'],
    reason: '$reason potential stops',
  );
  expect(
    actual.comfortScore,
    expected['comfort_score'],
    reason: '$reason comfort',
  );
  expect(
    actual.restrictedSegments,
    expected['restricted_segments'],
    reason: '$reason restrictions',
  );
}
