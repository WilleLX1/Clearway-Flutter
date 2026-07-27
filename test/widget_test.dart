import 'package:clearway/app.dart';
import 'package:clearway/features/route_planner/route_planner_controller.dart';
import 'package:clearway/models/clearway_models.dart';
import 'package:clearway/services/clearway_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements ClearwayRepository {
  @override
  Future<ClearwayMeta> getMeta() async => const ClearwayMeta(
    center: ClearwayPoint(lat: 56.0465, lon: 12.6945),
    bounds: [12.6, 56.0, 12.8, 56.1],
    profiles: ['fastest', 'clearway'],
    baselineLabel: 'Fastest',
    googleEnabled: false,
    driveOnRight: true,
  );

  @override
  Future<List<GeocodeResult>> geocode(String query) async => const [];

  @override
  Future<List<ClearwayRoute>> compare({
    required ClearwayPoint origin,
    required ClearwayPoint destination,
    required String time,
    required int weekday,
  }) async => const [];
}

void main() {
  testWidgets('shows the Clearway route planner', (tester) async {
    final controller = RoutePlannerController(_FakeRepository());
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(ClearwayApp(controller: controller));
    await tester.pump();

    expect(find.text('Clearway'), findsNWidgets(2));
    expect(
      find.text('Set a start and destination to compare routes.'),
      findsOneWidget,
    );
  });

  test('formats route distance and duration like the original client', () {
    expect(formatDistance(8900), '8.9 km');
    expect(formatDistance(850), '850 m');
    expect(formatDuration(18 * 60), '18 min');
    expect(formatDuration(75 * 60), '1 h 15 min');
  });
}
