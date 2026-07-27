import 'package:flutter/material.dart';

import '../../../core/theme/clearway_theme.dart';
import '../../../models/clearway_models.dart';

class RouteCard extends StatelessWidget {
  const RouteCard({
    super.key,
    required this.route,
    required this.baseline,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final ClearwayRoute route;
  final ClearwayRoute? baseline;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final note = _routeNote(route, baseline);
    final fewerSignals =
        baseline != null && route.stats.signals < baseline!.stats.signals;

    return Material(
      color: selected ? ClearwayColors.selected : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? ClearwayColors.routeBlue : Colors.transparent,
                width: 4,
              ),
              bottom: const BorderSide(color: ClearwayColors.divider),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatDuration(route.stats.estimatedTimeS),
                    style: TextStyle(
                      color: selected
                          ? ClearwayColors.routeBlueDark
                          : ClearwayColors.text,
                      fontSize: 18,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatDistance(route.stats.distanceM),
                    style: const TextStyle(
                      fontSize: 13,
                      color: ClearwayColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF80868B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                note.text,
                style: TextStyle(
                  fontSize: 12.5,
                  color: note.good
                      ? ClearwayColors.green
                      : ClearwayColors.textSecondary,
                ),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatChip(
                    label: 'lights',
                    value: route.stats.signals,
                    highlighted: fewerSignals,
                  ),
                  _StatChip(label: 'stops', value: route.stats.stops),
                  _StatChip(label: 'crossings', value: route.stats.crossings),
                  if (route.stats.roundabouts > 0)
                    _StatChip(
                      label: 'roundabouts',
                      value: route.stats.roundabouts,
                    ),
                ],
              ),
              if (route.stats.restrictedSegments > 0) ...[
                const SizedBox(height: 9),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 14,
                      color: ClearwayColors.amber,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Uses ${route.stats.restrictedSegments} time-limited '
                        'segment${route.stats.restrictedSegments == 1 ? '' : 's'}, '
                        'open at your departure time',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ClearwayColors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final int value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: ClearwayColors.divider),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$value ',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: highlighted ? ClearwayColors.green : ClearwayColors.text,
              ),
            ),
            TextSpan(text: label),
          ],
        ),
        style: const TextStyle(
          fontSize: 11.5,
          color: ClearwayColors.textSecondary,
        ),
      ),
    );
  }
}

_RouteNote _routeNote(ClearwayRoute route, ClearwayRoute? baseline) {
  if (baseline == null || route.profile == baseline.profile) {
    return const _RouteNote(
      'Baseline route — real-world delay priced in',
      false,
    );
  }

  final stats = route.stats;
  final base = baseline.stats;
  final signalDifference = base.signals - stats.signals;
  final stopDifference = base.stops - stats.stops;
  final crossingDifference = base.crossings - stats.crossings;
  final distanceDifference = stats.distanceM - base.distanceM;
  final timeDifference = stats.estimatedTimeS - base.estimatedTimeS;
  final parts = <String>[];

  String plural(int value, String noun) =>
      '$value $noun${value == 1 ? '' : 's'}';

  if (signalDifference > 0) {
    parts.add(plural(signalDifference, 'fewer light'));
  } else if (signalDifference < 0) {
    parts.add(plural(-signalDifference, 'more light'));
  } else {
    parts.add('same lights');
  }
  if (stopDifference > 0) {
    parts.add(plural(stopDifference, 'fewer stop'));
  } else if (stopDifference < 0) {
    parts.add(plural(-stopDifference, 'more stop'));
  }
  if (crossingDifference > 0) {
    parts.add(plural(crossingDifference, 'fewer crossing'));
  } else if (crossingDifference < 0) {
    parts.add(plural(-crossingDifference, 'more crossing'));
  }
  parts.add(
    '${distanceDifference >= 0 ? '+' : '−'}${formatDistance(distanceDifference.abs())}',
  );
  parts.add(
    '${timeDifference >= 0 ? '+' : '−'}${timeDifference.abs().round()} s',
  );

  return _RouteNote(
    parts.join(' · '),
    signalDifference + stopDifference + crossingDifference > 0,
  );
}

class _RouteNote {
  const _RouteNote(this.text, this.good);

  final String text;
  final bool good;
}
