import 'package:flutter/material.dart';

import '../../../core/theme/clearway_theme.dart';
import '../../../models/clearway_models.dart';
import '../route_planner_controller.dart';
import 'route_card.dart';

class PlannerPanel extends StatelessWidget {
  const PlannerPanel({
    super.key,
    required this.controller,
    required this.originText,
    required this.destinationText,
    required this.desktop,
    this.scrollController,
  });

  final RoutePlannerController controller;
  final TextEditingController originText;
  final TextEditingController destinationText;
  final bool desktop;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    if (desktop) {
      return Material(
        elevation: 8,
        color: Colors.white,
        child: SafeArea(
          right: false,
          child: Column(
            children: [
              _PanelHeader(
                controller: controller,
                originText: originText,
                destinationText: destinationText,
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: _routeContent(),
                ),
              ),
              _StatusFooter(status: controller.status),
            ],
          ),
        ),
      );
    }

    return Material(
      elevation: 12,
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          const _SheetGrip(),
          _PanelHeader(
            controller: controller,
            originText: originText,
            destinationText: destinationText,
          ),
          ..._routeContent(),
          _StatusFooter(status: controller.status),
        ],
      ),
    );
  }

  List<Widget> _routeContent() => [
    for (final route in controller.routes)
      RouteCard(
        route: route,
        baseline: controller.baseline,
        selected: route.profile == controller.selectedProfile,
        label: route.profile == 'fastest'
            ? (controller.meta?.baselineLabel ?? 'Fastest')
            : 'Clearway',
        onTap: () => controller.selectProfile(route.profile),
      ),
    Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        controller.hint,
        style: const TextStyle(
          color: ClearwayColors.textSecondary,
          fontSize: 12.5,
        ),
      ),
    ),
  ];
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.controller,
    required this.originText,
    required this.destinationText,
  });

  final RoutePlannerController controller;
  final TextEditingController originText;
  final TextEditingController destinationText;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ClearwayColors.divider)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: ClearwayColors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'Clearway',
                      style: TextStyle(
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Clear route',
                      onPressed: controller.clear,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _ProfileTabs(controller: controller),
                const SizedBox(height: 14),
                _TripFields(
                  controller: controller,
                  originText: originText,
                  destinationText: destinationText,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _DeparturePill(controller: controller),
                ),
              ],
            ),
          ),
          if (controller.findingRoutes || controller.initializing)
            const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}

class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({required this.controller});

  final RoutePlannerController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ProfileTab(
            icon: Icons.bolt,
            label: controller.meta?.baselineLabel ?? 'Fastest',
            selected: controller.selectedProfile == 'fastest',
            onTap: () => controller.selectProfile('fastest'),
          ),
        ),
        Expanded(
          child: _ProfileTab(
            icon: Icons.traffic,
            label: 'Clearway',
            selected: controller.selectedProfile == 'clearway',
            onTap: () => controller.selectProfile('clearway'),
          ),
        ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ClearwayColors.blue : ClearwayColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 11, 6, 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? ClearwayColors.blue : ClearwayColors.divider,
              width: selected ? 3 : 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripFields extends StatelessWidget {
  const _TripFields({
    required this.controller,
    required this.originText,
    required this.destinationText,
  });

  final RoutePlannerController controller;
  final TextEditingController originText;
  final TextEditingController destinationText;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 90,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 19,
                bottom: 19,
                child: CustomPaint(
                  painter: _DottedLinePainter(),
                  size: const Size(2, 52),
                ),
              ),
              Positioned(
                top: 15,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF80868B),
                      width: 2.5,
                    ),
                    color: Colors.white,
                  ),
                ),
              ),
              const Positioned(
                bottom: 7,
                child: Icon(
                  Icons.location_on,
                  size: 22,
                  color: ClearwayColors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              _AddressField(
                controller: originText,
                hint: 'Choose starting point, or click on the map',
                searching: controller.searchingOrigin,
                results: controller.originResults,
                onChanged: (value) =>
                    controller.search(PointKind.origin, value),
                onSelected: (result) =>
                    controller.setPoint(PointKind.origin, result.toPoint()),
              ),
              const SizedBox(height: 8),
              _AddressField(
                controller: destinationText,
                hint: 'Choose destination, or click on the map',
                searching: controller.searchingDestination,
                results: controller.destinationResults,
                onChanged: (value) =>
                    controller.search(PointKind.destination, value),
                onSelected: (result) => controller.setPoint(
                  PointKind.destination,
                  result.toPoint(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 40,
          height: 88,
          child: IconButton(
            tooltip: 'Reverse starting point and destination',
            onPressed: controller.swap,
            icon: const Icon(Icons.swap_vert),
          ),
        ),
      ],
    );
  }
}

class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.controller,
    required this.hint,
    required this.searching,
    required this.results,
    required this.onChanged,
    required this.onSelected,
  });

  final TextEditingController controller;
  final String hint;
  final bool searching;
  final List<GeocodeResult> results;
  final ValueChanged<String> onChanged;
  final ValueChanged<GeocodeResult> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            suffixIcon: searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (results.isNotEmpty)
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 5),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final result = results[index];
                  final comma = result.label.indexOf(',');
                  final primary = comma > 0
                      ? result.label.substring(0, comma)
                      : result.label;
                  final secondary = comma > 0
                      ? result.label.substring(comma + 1).trim()
                      : '';
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.location_on_outlined,
                      size: 19,
                      color: Color(0xFF80868B),
                    ),
                    title: Text(
                      primary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: secondary.isEmpty
                        ? null
                        : Text(
                            secondary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: () => onSelected(result),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _DeparturePill extends StatelessWidget {
  const _DeparturePill({required this.controller});

  final RoutePlannerController controller;

  static const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ClearwayColors.fill,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule,
              size: 18,
              color: ClearwayColors.textSecondary,
            ),
            const SizedBox(width: 7),
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: controller.weekday,
                isDense: true,
                borderRadius: BorderRadius.circular(8),
                items: [
                  for (var index = 0; index < days.length; index++)
                    DropdownMenuItem(value: index, child: Text(days[index])),
                ],
                onChanged: (value) {
                  if (value != null) controller.setWeekday(value);
                },
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: ClearwayColors.text,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
              ),
              onPressed: () async {
                final result = await showTimePicker(
                  context: context,
                  initialTime: controller.departureTime,
                );
                if (result != null) controller.setDepartureTime(result);
              },
              child: Text(controller.departureTime.format(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusFooter extends StatelessWidget {
  const _StatusFooter({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ClearwayColors.divider)),
      ),
      child: Text(
        status,
        style: const TextStyle(
          fontSize: 12,
          color: ClearwayColors.textSecondary,
        ),
      ),
    );
  }
}

class _SheetGrip extends StatelessWidget {
  const _SheetGrip();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 32,
        height: 4,
        margin: const EdgeInsets.only(top: 8, bottom: 2),
        decoration: BoxDecoration(
          color: ClearwayColors.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ClearwayColors.divider
      ..strokeWidth = 2;
    for (double y = 0; y < size.height; y += 5) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
