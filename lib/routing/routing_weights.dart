class RoutingWeights {
  const RoutingWeights({
    required this.signal,
    required this.stop,
    required this.crossing,
    required this.uturn,
    required this.roundabout,
    required this.miniRoundabout,
  });

  final double signal;
  final double stop;
  final double crossing;
  final double uturn;
  final double roundabout;
  final double miniRoundabout;

  static const realistic = RoutingWeights(
    signal: 18,
    stop: 6,
    crossing: 3,
    uturn: 25,
    roundabout: 8,
    miniRoundabout: 4,
  );

  static const clearway = RoutingWeights(
    signal: 150,
    stop: 70,
    crossing: 25,
    uturn: 25,
    roundabout: 8,
    miniRoundabout: 4,
  );

  static RoutingWeights forProfile(String profile) =>
      profile == 'fastest' ? realistic : clearway;
}
