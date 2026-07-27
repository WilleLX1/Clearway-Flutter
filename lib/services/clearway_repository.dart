import '../models/clearway_models.dart';

abstract interface class ClearwayRepository {
  Future<ClearwayMeta> getMeta();

  Future<List<GeocodeResult>> geocode(String query);

  Future<List<ClearwayRoute>> compare({
    required ClearwayPoint origin,
    required ClearwayPoint destination,
    required String time,
    required int weekday,
  });
}

class NoRouteException implements Exception {
  const NoRouteException([
    this.message = 'No route found between the selected points.',
  ]);

  final String message;

  @override
  String toString() => message;
}
