import 'package:flutter/services.dart';

import '../models/clearway_models.dart';
import '../routing/local_routing_engine.dart';
import '../routing/routing_graph.dart';
import '../search/place_search_index.dart';
import 'clearway_repository.dart';

class LocalClearwayRepository implements ClearwayRepository {
  LocalClearwayRepository({
    this.assetPath = 'assets/routing/helsingborg.graph.json',
    this.searchAssetPath = 'assets/search/helsingborg.places.json',
    AssetBundle? assetBundle,
  }) : _assetBundle = assetBundle ?? rootBundle;

  final String assetPath;
  final String searchAssetPath;
  final AssetBundle _assetBundle;
  LocalRoutingEngine? _engine;
  Future<LocalRoutingEngine>? _loading;
  PlaceSearchIndex? _searchIndex;
  Future<PlaceSearchIndex>? _searchLoading;

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

  Future<PlaceSearchIndex> _loadSearchIndex() {
    final existing = _searchIndex;
    if (existing != null) return Future.value(existing);
    return _searchLoading ??= _loadSearchAsset();
  }

  Future<PlaceSearchIndex> _loadSearchAsset() async {
    final source = await _assetBundle.loadString(searchAssetPath);
    final index = PlaceSearchIndex.fromJsonString(source);
    _searchIndex = index;
    return index;
  }

  @override
  Future<ClearwayMeta> getMeta() async => (await _load()).meta;

  @override
  Future<List<GeocodeResult>> geocode(String query) async {
    final engine = await _load();
    List<GeocodeResult> places;
    try {
      places = (await _loadSearchIndex()).search(query, limit: 6);
    } catch (_) {
      places = const [];
    }
    final streets = engine.graph.searchStreets(query, limit: 8);
    final results = <GeocodeResult>[];
    final labels = <String>{};
    for (final result in [...places, ...streets]) {
      if (labels.add(result.label.toLowerCase())) results.add(result);
      if (results.length == 8) break;
    }
    return results;
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
