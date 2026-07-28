import 'package:clearway/features/navigation/navigation_screen.dart';
import 'package:clearway/features/route_planner/route_planner_controller.dart';
import 'package:clearway/models/clearway_models.dart';
import 'package:clearway/navigation/route_progress.dart';
import 'package:clearway/services/clearway_repository.dart';
import 'package:clearway/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLocationService implements LocationService {
  const _FakeLocationService(this.sample);

  final LocationSample sample;

  @override
  Future<LocationSample> current() async => sample;

  @override
  Stream<LocationSample> watch() => Stream.value(sample);
}

class _NavigationRepository implements ClearwayRepository {
  ClearwayPoint? lastOrigin;

  @override
  Future<List<ClearwayRoute>> compare({
    required ClearwayPoint origin,
    required ClearwayPoint destination,
    required String time,
    required int weekday,
  }) async {
    lastOrigin = origin;
    return [
      ClearwayRoute(
        profile: 'clearway',
        stats: const RouteStats(
          distanceM: 100,
          baseTimeS: 10,
          estimatedTimeS: 12,
          signals: 0,
          stops: 0,
          crossings: 0,
          uturns: 0,
          roundabouts: 0,
          potentialStops: 0,
          comfortScore: 100,
          restrictedSegments: 0,
        ),
        coordinates: [origin, destination],
        instructions: [
          RouteInstruction(
            type: ManeuverType.depart,
            point: origin,
            distanceFromStartM: 0,
            roadName: 'Testgatan',
          ),
          RouteInstruction(
            type: ManeuverType.arrive,
            point: destination,
            distanceFromStartM: 100,
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<GeocodeResult>> geocode(String query) async => const [];

  @override
  Future<ClearwayMeta> getMeta() async => const ClearwayMeta(
    center: ClearwayPoint(lat: 56, lon: 12),
    bounds: [11, 55, 13, 57],
    profiles: ['fastest', 'clearway'],
    baselineLabel: 'Fastest',
    googleEnabled: false,
    driveOnRight: true,
  );
}

void main() {
  test('projects a live position onto a route and measures progress', () {
    const route = [
      ClearwayPoint(lat: 56.0000, lon: 12.0000),
      ClearwayPoint(lat: 56.0010, lon: 12.0000),
      ClearwayPoint(lat: 56.0020, lon: 12.0000),
    ];

    final progress = locateOnRoute(
      const ClearwayPoint(lat: 56.0010, lon: 12.0001),
      route,
    );

    expect(progress.segmentIndex, anyOf(0, 1));
    expect(progress.distanceFromRouteM, closeTo(6.2, 0.8));
    expect(progress.fraction, closeTo(0.5, 0.01));
    expect(progress.remainingDistanceM, closeTo(110.5, 2));
  });

  test(
    'Go recalculates the selected route from the current location',
    () async {
      final repository = _NavigationRepository();
      final sample = LocationSample(
        point: const ClearwayPoint(
          lat: 56.049,
          lon: 12.690,
          label: 'Current location',
        ),
        accuracyM: 5,
        heading: 90,
        speedMps: 4,
        timestamp: DateTime(2026),
      );
      final controller = RoutePlannerController(
        repository,
        locationService: _FakeLocationService(sample),
      );
      addTearDown(controller.dispose);
      controller.destination = const ClearwayPoint(lat: 56.05, lon: 12.70);

      final route = await controller.prepareNavigation();

      expect(route, isNotNull);
      expect(controller.origin?.label, 'Current location');
      expect(repository.lastOrigin?.lat, sample.point.lat);
      expect(controller.currentLocation, same(sample));
    },
  );

  testWidgets('navigation mode shows maneuver, progress, and controls', (
    tester,
  ) async {
    final repository = _NavigationRepository();
    final sample = LocationSample(
      point: const ClearwayPoint(lat: 56.049, lon: 12.690),
      accuracyM: 5,
      heading: 90,
      speedMps: 4,
      timestamp: DateTime(2026),
    );
    final controller = RoutePlannerController(
      repository,
      locationService: _FakeLocationService(sample),
    );
    addTearDown(controller.dispose);
    controller.destination = const ClearwayPoint(lat: 56.05, lon: 12.70);
    final route = await controller.prepareNavigation();

    await tester.pumpWidget(
      MaterialApp(
        home: NavigationScreen(
          controller: controller,
          initialRoute: route!,
          destination: controller.destination!,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Head along Testgatan'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);
    expect(find.byTooltip('Recenter'), findsOneWidget);
  });
}
