import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/clearway_models.dart';
import '../../services/clearway_api.dart';

enum PointKind { origin, destination }

class RoutePlannerController extends ChangeNotifier {
  RoutePlannerController(this._repository) {
    final now = DateTime.now();
    departureTime = TimeOfDay(hour: now.hour, minute: now.minute);
    weekday = now.weekday - 1;
  }

  factory RoutePlannerController.standard() =>
      RoutePlannerController(ClearwayApi());

  final ClearwayRepository _repository;
  Timer? _originSearchTimer;
  Timer? _destinationSearchTimer;
  int _routeRequest = 0;
  int _originSearchRequest = 0;
  int _destinationSearchRequest = 0;
  bool _disposed = false;

  ClearwayMeta? meta;
  ClearwayPoint? origin;
  ClearwayPoint? destination;
  List<ClearwayRoute> routes = const [];
  List<GeocodeResult> originResults = const [];
  List<GeocodeResult> destinationResults = const [];
  String selectedProfile = 'clearway';
  late TimeOfDay departureTime;
  late int weekday;
  bool initializing = true;
  bool findingRoutes = false;
  bool searchingOrigin = false;
  bool searchingDestination = false;
  String hint =
      'Click the map for your starting point, then again for the destination.';
  String status = 'Set a start and destination to compare routes.';

  ClearwayRoute? get baseline {
    for (final route in routes) {
      if (route.profile == 'fastest') return route;
    }
    return routes.firstOrNull;
  }

  ClearwayRoute? get selectedRoute {
    for (final route in routes) {
      if (route.profile == selectedProfile) return route;
    }
    return null;
  }

  Future<void> initialize() async {
    try {
      meta = await _repository.getMeta();
    } catch (_) {
      status =
          'Cannot reach the Clearway server. Start the backend or configure its address.';
    } finally {
      initializing = false;
      _notify();
    }
  }

  Future<void> setPoint(PointKind kind, ClearwayPoint point) async {
    if (kind == PointKind.origin) {
      origin = point;
      originResults = const [];
    } else {
      destination = point;
      destinationResults = const [];
    }
    _notify();
    await computeRoutes();
  }

  Future<void> handleMapTap(ClearwayPoint point) async {
    if (origin == null) {
      hint = 'Now click your destination.';
      await setPoint(PointKind.origin, point);
      return;
    }
    if (destination == null) {
      hint = 'Click a route or an ETA to switch between them.';
      await setPoint(PointKind.destination, point);
      return;
    }

    destination = null;
    routes = const [];
    status = 'Set a destination to compare routes.';
    hint = 'Now click your destination.';
    await setPoint(PointKind.origin, point);
  }

  void search(PointKind kind, String query) {
    final trimmed = query.trim();
    if (kind == PointKind.origin) {
      _originSearchTimer?.cancel();
      if (trimmed.length < 3) {
        originResults = const [];
        searchingOrigin = false;
        _notify();
        return;
      }
      final request = ++_originSearchRequest;
      searchingOrigin = true;
      _notify();
      _originSearchTimer = Timer(
        const Duration(milliseconds: 300),
        () => _performSearch(kind, trimmed, request),
      );
    } else {
      _destinationSearchTimer?.cancel();
      if (trimmed.length < 3) {
        destinationResults = const [];
        searchingDestination = false;
        _notify();
        return;
      }
      final request = ++_destinationSearchRequest;
      searchingDestination = true;
      _notify();
      _destinationSearchTimer = Timer(
        const Duration(milliseconds: 300),
        () => _performSearch(kind, trimmed, request),
      );
    }
  }

  Future<void> _performSearch(PointKind kind, String query, int request) async {
    try {
      final results = await _repository.geocode(query);
      if (kind == PointKind.origin && request == _originSearchRequest) {
        originResults = results;
      } else if (kind == PointKind.destination &&
          request == _destinationSearchRequest) {
        destinationResults = results;
      }
    } catch (_) {
      if (kind == PointKind.origin && request == _originSearchRequest) {
        originResults = const [];
      } else if (kind == PointKind.destination &&
          request == _destinationSearchRequest) {
        destinationResults = const [];
      }
    } finally {
      if (kind == PointKind.origin && request == _originSearchRequest) {
        searchingOrigin = false;
      } else if (kind == PointKind.destination &&
          request == _destinationSearchRequest) {
        searchingDestination = false;
      }
      _notify();
    }
  }

  Future<void> computeRoutes() async {
    final routeOrigin = origin;
    final routeDestination = destination;
    if (routeOrigin == null || routeDestination == null) return;

    final request = ++_routeRequest;
    findingRoutes = true;
    status = 'Finding routes…';
    _notify();

    try {
      final result = await _repository.compare(
        origin: routeOrigin,
        destination: routeDestination,
        time:
            '${departureTime.hour.toString().padLeft(2, '0')}:${departureTime.minute.toString().padLeft(2, '0')}',
        weekday: weekday,
      );
      if (request != _routeRequest) return;

      routes = result;
      if (!routes.any((route) => route.profile == selectedProfile) &&
          routes.isNotEmpty) {
        selectedProfile = routes.first.profile;
      }
      hint = 'Click a route or an ETA on the map to switch between them.';
      _updateStatus();
    } catch (_) {
      if (request != _routeRequest) return;
      routes = const [];
      status =
          'No route found — try points closer to roads inside the supported region.';
    } finally {
      if (request == _routeRequest) {
        findingRoutes = false;
        _notify();
      }
    }
  }

  void selectProfile(String profile) {
    selectedProfile = profile;
    _updateStatus();
    _notify();
  }

  void setDepartureTime(TimeOfDay value) {
    departureTime = value;
    _notify();
    unawaited(computeRoutes());
  }

  void setWeekday(int value) {
    weekday = value;
    _notify();
    unawaited(computeRoutes());
  }

  void swap() {
    if (origin == null && destination == null) return;
    final oldOrigin = origin;
    origin = destination;
    destination = oldOrigin;
    routes = const [];
    _notify();
    unawaited(computeRoutes());
  }

  void clear() {
    _routeRequest++;
    origin = null;
    destination = null;
    routes = const [];
    originResults = const [];
    destinationResults = const [];
    hint =
        'Click the map for your starting point, then again for the destination.';
    status = 'Set a start and destination to compare routes.';
    findingRoutes = false;
    _notify();
  }

  void _updateStatus() {
    final selected = selectedRoute;
    final fastest = baseline;
    if (selected == null || fastest == null) return;

    final improvements = <String>[];
    final signalDifference = fastest.stats.signals - selected.stats.signals;
    final stopDifference = fastest.stats.stops - selected.stats.stops;
    final crossingDifference =
        fastest.stats.crossings - selected.stats.crossings;
    if (signalDifference > 0) improvements.add('$signalDifference signals');
    if (stopDifference > 0) improvements.add('$stopDifference stops');
    if (crossingDifference > 0) {
      improvements.add('$crossingDifference crossings');
    }

    status = improvements.isEmpty
        ? '${routes.length} routes compared.'
        : 'This route avoids ${improvements.join(', ')} vs. fastest.';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _originSearchTimer?.cancel();
    _destinationSearchTimer?.cancel();
    if (_repository is ClearwayApi) {
      _repository.close();
    }
    super.dispose();
  }
}
