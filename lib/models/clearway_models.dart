class ClearwayPoint {
  const ClearwayPoint({required this.lat, required this.lon, this.label});

  factory ClearwayPoint.fromJson(Map<String, dynamic> json) => ClearwayPoint(
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
    label: json['label'] as String?,
  );

  final double lat;
  final double lon;
  final String? label;

  Map<String, double> toJson() => {'lat': lat, 'lon': lon};

  String get displayLabel =>
      label ?? '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
}

class ClearwayMeta {
  const ClearwayMeta({
    required this.center,
    required this.bounds,
    required this.profiles,
    required this.baselineLabel,
    required this.googleEnabled,
    required this.driveOnRight,
  });

  factory ClearwayMeta.fromJson(Map<String, dynamic> json) => ClearwayMeta(
    center: ClearwayPoint.fromJson(json['center'] as Map<String, dynamic>),
    bounds: (json['bounds'] as List<dynamic>)
        .map((value) => (value as num).toDouble())
        .toList(growable: false),
    profiles: (json['profiles'] as List<dynamic>).cast<String>(),
    baselineLabel: json['baseline_label'] as String,
    googleEnabled: json['google_enabled'] as bool,
    driveOnRight: json['drive_on_right'] as bool,
  );

  final ClearwayPoint center;
  final List<double> bounds;
  final List<String> profiles;
  final String baselineLabel;
  final bool googleEnabled;
  final bool driveOnRight;
}

class GeocodeResult {
  const GeocodeResult({
    required this.label,
    required this.lat,
    required this.lon,
  });

  factory GeocodeResult.fromJson(Map<String, dynamic> json) => GeocodeResult(
    label: json['label'] as String,
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
  );

  final String label;
  final double lat;
  final double lon;

  ClearwayPoint toPoint() => ClearwayPoint(lat: lat, lon: lon, label: label);
}

class RouteStats {
  const RouteStats({
    required this.distanceM,
    required this.baseTimeS,
    required this.estimatedTimeS,
    required this.signals,
    required this.stops,
    required this.crossings,
    required this.uturns,
    required this.roundabouts,
    required this.potentialStops,
    required this.comfortScore,
    required this.restrictedSegments,
  });

  factory RouteStats.fromJson(Map<String, dynamic> json) => RouteStats(
    distanceM: (json['distance_m'] as num).toDouble(),
    baseTimeS: (json['base_time_s'] as num).toDouble(),
    estimatedTimeS: (json['est_time_s'] as num).toDouble(),
    signals: json['signals'] as int,
    stops: json['stops'] as int,
    crossings: json['crossings'] as int,
    uturns: json['uturns'] as int,
    roundabouts: json['roundabouts'] as int,
    potentialStops: json['potential_stops'] as int,
    comfortScore: json['comfort_score'] as int,
    restrictedSegments: (json['restricted_segments'] as int?) ?? 0,
  );

  final double distanceM;
  final double baseTimeS;
  final double estimatedTimeS;
  final int signals;
  final int stops;
  final int crossings;
  final int uturns;
  final int roundabouts;
  final int potentialStops;
  final int comfortScore;
  final int restrictedSegments;
}

class ClearwayRoute {
  const ClearwayRoute({
    required this.profile,
    required this.stats,
    required this.coordinates,
    this.instructions = const [],
  });

  factory ClearwayRoute.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    return ClearwayRoute(
      profile: json['profile'] as String,
      stats: RouteStats.fromJson(json['stats'] as Map<String, dynamic>),
      coordinates: (geometry['coordinates'] as List<dynamic>)
          .map((coordinate) {
            final values = coordinate as List<dynamic>;
            return ClearwayPoint(
              lon: (values[0] as num).toDouble(),
              lat: (values[1] as num).toDouble(),
            );
          })
          .toList(growable: false),
    );
  }

  final String profile;
  final RouteStats stats;
  final List<ClearwayPoint> coordinates;
  final List<RouteInstruction> instructions;
}

enum ManeuverType {
  depart,
  continueStraight,
  slightLeft,
  turnLeft,
  sharpLeft,
  slightRight,
  turnRight,
  sharpRight,
  uTurn,
  enterRoundabout,
  exitRoundabout,
  arrive,
}

class RouteInstruction {
  const RouteInstruction({
    required this.type,
    required this.point,
    required this.distanceFromStartM,
    this.roadName = '',
    this.exitNumber,
  });

  final ManeuverType type;
  final ClearwayPoint point;
  final double distanceFromStartM;
  final String roadName;
  final int? exitNumber;

  String get title {
    final road = roadName.trim();
    final suffix = road.isEmpty ? '' : ' onto $road';
    return switch (type) {
      ManeuverType.depart =>
        road.isEmpty ? 'Start driving' : 'Head along $road',
      ManeuverType.continueStraight =>
        road.isEmpty ? 'Continue straight' : 'Continue on $road',
      ManeuverType.slightLeft => 'Keep slightly left$suffix',
      ManeuverType.turnLeft => 'Turn left$suffix',
      ManeuverType.sharpLeft => 'Make a sharp left$suffix',
      ManeuverType.slightRight => 'Keep slightly right$suffix',
      ManeuverType.turnRight => 'Turn right$suffix',
      ManeuverType.sharpRight => 'Make a sharp right$suffix',
      ManeuverType.uTurn => 'Make a U-turn$suffix',
      ManeuverType.enterRoundabout =>
        exitNumber == null
            ? 'Enter the roundabout'
            : 'At the roundabout, take exit $exitNumber$suffix',
      ManeuverType.exitRoundabout =>
        road.isEmpty ? 'Exit the roundabout' : 'Exit onto $road',
      ManeuverType.arrive => 'You have arrived',
    };
  }
}

String formatDistance(double metres) {
  if (metres >= 1000) {
    final kilometres = (metres / 1000).toStringAsFixed(1);
    return '${kilometres.endsWith('.0') ? kilometres.substring(0, kilometres.length - 2) : kilometres} km';
  }
  return '${metres.round()} m';
}

String formatDuration(double seconds) {
  final minutes = (seconds / 60).round().clamp(1, 1 << 30);
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '$hours h' : '$hours h $remainder min';
}
