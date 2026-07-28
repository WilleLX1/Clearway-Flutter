import 'package:geolocator/geolocator.dart';

import '../models/clearway_models.dart';

class LocationSample {
  const LocationSample({
    required this.point,
    required this.accuracyM,
    required this.heading,
    required this.speedMps,
    required this.timestamp,
  });

  factory LocationSample.fromPosition(Position position) => LocationSample(
    point: ClearwayPoint(
      lat: position.latitude,
      lon: position.longitude,
      label: 'Current location',
    ),
    accuracyM: position.accuracy,
    heading: position.heading,
    speedMps: position.speed,
    timestamp: position.timestamp,
  );

  final ClearwayPoint point;
  final double accuracyM;
  final double heading;
  final double speedMps;
  final DateTime timestamp;
}

abstract class LocationService {
  Future<LocationSample> current();

  Stream<LocationSample> watch();
}

class LocationFailure implements Exception {
  const LocationFailure(this.message, {this.permanentlyDenied = false});

  final String message;
  final bool permanentlyDenied;

  @override
  String toString() => message;
}

class GeolocatorLocationService implements LocationService {
  static const _currentSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 3,
    timeLimit: Duration(seconds: 20),
  );
  static const _streamSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 3,
  );

  Future<void> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
        'Location services are turned off. Enable them and try again.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationFailure(
        'Location permission was denied. Clearway needs it for navigation.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        'Location permission is blocked. Enable it in system settings.',
        permanentlyDenied: true,
      );
    }
  }

  @override
  Future<LocationSample> current() async {
    await _ensurePermission();
    final position = await Geolocator.getCurrentPosition(
      locationSettings: _currentSettings,
    );
    return LocationSample.fromPosition(position);
  }

  @override
  Stream<LocationSample> watch() async* {
    await _ensurePermission();
    yield* Geolocator.getPositionStream(
      locationSettings: _streamSettings,
    ).map(LocationSample.fromPosition);
  }
}
