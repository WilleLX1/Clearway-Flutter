import 'dart:math' as math;

import '../models/clearway_models.dart';
import 'routing_geo.dart';
import 'routing_graph.dart';
import 'routing_weights.dart';

class LocalRoutingEngine {
  const LocalRoutingEngine(this.graph);

  final RoutingGraph graph;

  ClearwayMeta get meta {
    final west = graph.bounds[0];
    final south = graph.bounds[1];
    final east = graph.bounds[2];
    final north = graph.bounds[3];
    return ClearwayMeta(
      center: ClearwayPoint(lat: (south + north) / 2, lon: (west + east) / 2),
      bounds: graph.bounds,
      profiles: const ['fastest', 'clearway'],
      baselineLabel: 'Fastest',
      googleEnabled: false,
      driveOnRight: true,
    );
  }

  ClearwayRoute? route({
    required ClearwayPoint origin,
    required ClearwayPoint destination,
    required String profile,
    required int weekday,
    required int minute,
  }) {
    final originNode = graph.nearestNode(origin.lon, origin.lat);
    final destinationNode = graph.nearestNode(destination.lon, destination.lat);
    final path = routeEdges(
      originNode: originNode,
      destinationNode: destinationNode,
      weights: RoutingWeights.forProfile(profile),
      weekday: weekday,
      minute: minute,
    );
    if (path == null) return null;
    return _summarize(profile, path);
  }

  List<int>? routeEdges({
    required int originNode,
    required int destinationNode,
    required RoutingWeights weights,
    required int weekday,
    required int minute,
  }) {
    if (originNode == destinationNode) return const [];

    final exemptComponents = <int>{
      graph.nodes[originNode].restrictedComponent,
      graph.nodes[destinationNode].restrictedComponent,
    }..remove(-1);

    bool blocked(int edgeId) {
      final edge = graph.edges[edgeId];
      if (edge.ruleIndex < 0) return false;
      if (exemptComponents.contains(
        graph.nodes[edge.tail].restrictedComponent,
      )) {
        return false;
      }
      return graph.rules[edge.ruleIndex].isClosedAt(weekday, minute);
    }

    final destination = graph.nodes[destinationNode];
    final inverseSpeed = 1 / graph.maxSpeedMps;
    double heuristic(int nodeIndex) {
      final node = graph.nodes[nodeIndex];
      return haversineMetres(
            node.lon,
            node.lat,
            destination.lon,
            destination.lat,
          ) *
          inverseSpeed;
    }

    final best = List<double>.filled(graph.edges.length, double.infinity);
    final parent = List<int>.filled(graph.edges.length, -2);
    final queue = _MinHeap();

    for (final edgeId in graph.outEdges[originNode]) {
      if (blocked(edgeId)) continue;
      final edge = graph.edges[edgeId];
      var cost = edge.travelTime;
      if (edge.isRoundabout) cost += weights.roundabout;
      best[edgeId] = cost;
      parent[edgeId] = -1;
      queue.add(
        _QueueEntry(
          estimatedTotal: cost + heuristic(edge.head),
          cost: cost,
          edgeId: edgeId,
        ),
      );
    }

    var goalEdge = -1;
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current.cost > best[current.edgeId]) continue;
      final incoming = graph.edges[current.edgeId];
      final viaNode = incoming.head;
      if (viaNode == destinationNode) {
        goalEdge = current.edgeId;
        break;
      }

      final nodePenalty = _nodePenalty(graph.nodes[viaNode], weights);
      for (final nextEdgeId in graph.outEdges[viaNode]) {
        if (blocked(nextEdgeId)) continue;
        final outgoing = graph.edges[nextEdgeId];
        var transition =
            nodePenalty + _turnPenalty(incoming, outgoing, weights);
        if (outgoing.isRoundabout && !incoming.isRoundabout) {
          transition += weights.roundabout;
        }
        final nextCost = current.cost + transition + outgoing.travelTime;
        if (nextCost < best[nextEdgeId]) {
          best[nextEdgeId] = nextCost;
          parent[nextEdgeId] = current.edgeId;
          queue.add(
            _QueueEntry(
              estimatedTotal: nextCost + heuristic(outgoing.head),
              cost: nextCost,
              edgeId: nextEdgeId,
            ),
          );
        }
      }
    }

    if (goalEdge < 0) return null;
    final path = <int>[];
    for (var edgeId = goalEdge; edgeId >= 0; edgeId = parent[edgeId]) {
      path.add(edgeId);
    }
    return path.reversed.toList(growable: false);
  }

  double _nodePenalty(RoutingNode node, RoutingWeights weights) {
    var penalty = 0.0;
    if (node.isSignal) penalty += weights.signal;
    if (node.isStop) penalty += weights.stop;
    if (node.isCrossing) penalty += weights.crossing;
    if (node.isMiniRoundabout) penalty += weights.miniRoundabout;
    return penalty;
  }

  double _turnPenalty(
    RoutingEdge incoming,
    RoutingEdge outgoing,
    RoutingWeights weights,
  ) {
    return classifyTurn(incoming.arrivalBearing, outgoing.departureBearing) ==
            TurnKind.uturn
        ? weights.uturn
        : 0;
  }

  ClearwayRoute _summarize(String profile, List<int> edgeIds) {
    var distance = 0.0;
    var baseTime = 0.0;
    var signals = 0;
    var stops = 0;
    var crossings = 0;
    var restrictedSegments = 0;
    var wasRestricted = false;

    for (var index = 0; index < edgeIds.length; index++) {
      final edge = graph.edges[edgeIds[index]];
      distance += edge.length;
      baseTime += edge.travelTime;
      if (index < edgeIds.length - 1) {
        final node = graph.nodes[edge.head];
        if (node.isSignal) signals++;
        if (node.isStop) stops++;
        if (node.isCrossing) crossings++;
      }
      final restricted = edge.ruleIndex >= 0;
      if (restricted && !wasRestricted) restrictedSegments++;
      wasRestricted = restricted;
    }

    var uturns = 0;
    var roundabouts = 0;
    for (var index = 0; index + 1 < edgeIds.length; index++) {
      final incoming = graph.edges[edgeIds[index]];
      final outgoing = graph.edges[edgeIds[index + 1]];
      if (classifyTurn(incoming.arrivalBearing, outgoing.departureBearing) ==
          TurnKind.uturn) {
        uturns++;
      }
      if (outgoing.isRoundabout && !incoming.isRoundabout) {
        roundabouts++;
      }
    }
    if (edgeIds.isNotEmpty && graph.edges[edgeIds.first].isRoundabout) {
      roundabouts++;
    }

    final delays = RoutingWeights.realistic;
    final estimatedTime =
        baseTime +
        signals * delays.signal +
        stops * delays.stop +
        crossings * delays.crossing +
        uturns * delays.uturn +
        roundabouts * delays.roundabout;
    final comfort = math.max(
      0,
      100 -
          (signals * 6 +
              stops * 4 +
              crossings * 2 +
              uturns * 10 +
              roundabouts * 2),
    );

    final coordinates = <ClearwayPoint>[];
    for (var index = 0; index < edgeIds.length; index++) {
      final points = graph.edges[edgeIds[index]].coordinates;
      coordinates.addAll(index == 0 ? points : points.skip(1));
    }

    return ClearwayRoute(
      profile: profile,
      stats: RouteStats(
        distanceM: _roundOne(distance),
        baseTimeS: _roundOne(baseTime),
        estimatedTimeS: _roundOne(estimatedTime),
        signals: signals,
        stops: stops,
        crossings: crossings,
        uturns: uturns,
        roundabouts: roundabouts,
        potentialStops: signals + stops,
        comfortScore: comfort,
        restrictedSegments: restrictedSegments,
      ),
      coordinates: coordinates,
      instructions: _instructions(edgeIds, distance),
    );
  }

  List<RouteInstruction> _instructions(
    List<int> edgeIds,
    double totalDistance,
  ) {
    if (edgeIds.isEmpty) return const [];
    final result = <RouteInstruction>[];
    final first = graph.edges[edgeIds.first];
    result.add(
      RouteInstruction(
        type: ManeuverType.depart,
        point: first.coordinates.first,
        distanceFromStartM: 0,
        roadName: first.roadName,
      ),
    );

    var travelled = 0.0;
    for (var index = 0; index + 1 < edgeIds.length; index++) {
      final incoming = graph.edges[edgeIds[index]];
      final outgoing = graph.edges[edgeIds[index + 1]];
      travelled += incoming.length;
      final maneuver = _maneuverFor(incoming, outgoing);
      if (maneuver == null) continue;
      result.add(
        RouteInstruction(
          type: maneuver,
          point: outgoing.coordinates.first,
          distanceFromStartM: travelled,
          roadName: outgoing.roadName,
        ),
      );
    }

    final last = graph.edges[edgeIds.last];
    result.add(
      RouteInstruction(
        type: ManeuverType.arrive,
        point: last.coordinates.last,
        distanceFromStartM: totalDistance,
        roadName: last.roadName,
      ),
    );
    return result;
  }

  ManeuverType? _maneuverFor(RoutingEdge incoming, RoutingEdge outgoing) {
    if (outgoing.isRoundabout && !incoming.isRoundabout) {
      return ManeuverType.enterRoundabout;
    }
    if (!outgoing.isRoundabout && incoming.isRoundabout) {
      return ManeuverType.exitRoundabout;
    }
    if (incoming.isRoundabout && outgoing.isRoundabout) return null;

    final delta = turnDelta(incoming.arrivalBearing, outgoing.departureBearing);
    final absolute = delta.abs();
    if (absolute >= 155) return ManeuverType.uTurn;
    if (absolute <= 35) {
      final from = incoming.roadName.trim().toLowerCase();
      final to = outgoing.roadName.trim().toLowerCase();
      return from.isNotEmpty && to.isNotEmpty && from != to
          ? ManeuverType.continueStraight
          : null;
    }
    if (delta < 0) {
      if (absolute < 70) return ManeuverType.slightLeft;
      if (absolute <= 125) return ManeuverType.turnLeft;
      return ManeuverType.sharpLeft;
    }
    if (absolute < 70) return ManeuverType.slightRight;
    if (absolute <= 125) return ManeuverType.turnRight;
    return ManeuverType.sharpRight;
  }

  double _roundOne(double value) => (value * 10).round() / 10;
}

class _QueueEntry {
  const _QueueEntry({
    required this.estimatedTotal,
    required this.cost,
    required this.edgeId,
  });

  final double estimatedTotal;
  final double cost;
  final int edgeId;

  int compareTo(_QueueEntry other) {
    final estimated = estimatedTotal.compareTo(other.estimatedTotal);
    if (estimated != 0) return estimated;
    final routeCost = cost.compareTo(other.cost);
    if (routeCost != 0) return routeCost;
    return edgeId.compareTo(other.edgeId);
  }
}

class _MinHeap {
  final _values = <_QueueEntry>[];

  bool get isNotEmpty => _values.isNotEmpty;

  void add(_QueueEntry value) {
    _values.add(value);
    var index = _values.length - 1;
    while (index > 0) {
      final parent = (index - 1) >> 1;
      if (_values[parent].compareTo(value) <= 0) break;
      _values[index] = _values[parent];
      index = parent;
    }
    _values[index] = value;
  }

  _QueueEntry removeFirst() {
    final first = _values.first;
    final last = _values.removeLast();
    if (_values.isEmpty) return first;

    var index = 0;
    while (true) {
      final left = index * 2 + 1;
      if (left >= _values.length) break;
      final right = left + 1;
      var child = left;
      if (right < _values.length &&
          _values[right].compareTo(_values[left]) < 0) {
        child = right;
      }
      if (_values[child].compareTo(last) >= 0) break;
      _values[index] = _values[child];
      index = child;
    }
    _values[index] = last;
    return first;
  }
}
