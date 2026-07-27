import 'package:flutter/services.dart';

import '../models/clearway_models.dart';
import '../routing/local_routing_engine.dart';
import '../routing/routing_graph.dart';
import 'clearway_repository.dart';

class LocalClearwayRepository implements ClearwayRepository {
  LocalClearwayRepository({
    this.assetPath = 'assets/routing/helsingborg.graph.json',
    AssetBundle? assetBundle,
  }) : _assetBundle = assetBundle ?? rootBundle;

  final String assetPath;
  final AssetBundle _assetBundle;
  LocalRoutingEngine? _engine;
  Future<LocalRoutingEngine>? _loading;

  Future<LocalRoutingEngine> _load() {
    final existing = _engine;
    if (existing != null) return Future.value(existing);
    return _loading ??= _loadAsset();
  }

  Future<LocalRoutingEngine> _loadAsset() async {
    final source = await _assetBundle.loadString(assetPath);
    final engine = LocalRoutingEngine(RoutingGraph.fromJsonString(source));
    _engine = engine;
    return engine;
  }

  @override
  Future<ClearwayMeta> getMeta() async => (await _load()).meta;

  @override
  Future<List<GeocodeResult>> geocode(String query) async {
    final engine = await _load();
    return engine.graph.searchStreets(query);
  }

  @override
  Future<List<ClearwayRoute>> compare({
    required ClearwayPoint origin,
    required ClearwayPoint destination,
    required String time,
    required int weekday,
  }) async {
    final engine = await _load();
    final parts = time.split(':');
    final minute = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    final routes = <ClearwayRoute>[];
    for (final profile in const ['fastest', 'clearway']) {
      final route = engine.route(
        origin: origin,
        destination: destination,
        profile: profile,
        weekday: weekday,
        minute: minute,
      );
      if (route != null) routes.add(route);
    }
    if (routes.isEmpty) {
      throw const NoRouteException();
    }
    return routes;
  }
}
