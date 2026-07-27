import 'dart:math' as math;

const _earthRadiusM = 6371000.0;
const _straightMax = 35.0;
const _uturnMin = 155.0;

double haversineMetres(double lon1, double lat1, double lon2, double lat2) {
  final p1 = lat1 * math.pi / 180;
  final p2 = lat2 * math.pi / 180;
  final dPhi = (lat2 - lat1) * math.pi / 180;
  final dLambda = (lon2 - lon1) * math.pi / 180;
  final a =
      math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(p1) *
          math.cos(p2) *
          math.sin(dLambda / 2) *
          math.sin(dLambda / 2);
  return 2 * _earthRadiusM * math.asin(math.sqrt(a));
}

double turnDelta(double incomingBearing, double outgoingBearing) {
  var delta = (outgoingBearing - incomingBearing + 180) % 360 - 180;
  if (delta == -180) delta = 180;
  return delta;
}

TurnKind classifyTurn(double incomingBearing, double outgoingBearing) {
  final delta = turnDelta(incomingBearing, outgoingBearing);
  final absolute = delta.abs();
  if (absolute >= _uturnMin) return TurnKind.uturn;
  if (absolute <= _straightMax) return TurnKind.straight;
  return delta < 0 ? TurnKind.left : TurnKind.right;
}

enum TurnKind { straight, left, right, uturn }
