import 'package:flutter/material.dart';

import 'route_planner_controller.dart';
import 'widgets/planner_panel.dart';
import 'widgets/route_map_view.dart';

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key, this.controller});

  final RoutePlannerController? controller;

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  late final RoutePlannerController _controller;
  late final bool _ownsController;
  final _originText = TextEditingController();
  final _destinationText = TextEditingController();
  String? _lastOriginLabel;
  String? _lastDestinationLabel;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? RoutePlannerController.standard();
    _controller.addListener(_onControllerChanged);
    _syncTextFields();
    if (_controller.initializing) {
      _controller.initialize();
    }
  }

  void _onControllerChanged() {
    _syncTextFields();
    if (mounted) setState(() {});
  }

  void _syncTextFields() {
    final originLabel = _controller.origin?.displayLabel;
    final destinationLabel = _controller.destination?.displayLabel;
    if (originLabel != _lastOriginLabel) {
      _lastOriginLabel = originLabel;
      _originText.text = originLabel ?? '';
    }
    if (destinationLabel != _lastDestinationLabel) {
      _lastDestinationLabel = destinationLabel;
      _destinationText.text = destinationLabel ?? '';
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    _originText.dispose();
    _destinationText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth > 720;
          final map = RouteMapView(
            controller: _controller,
            mobileSheetVisible: !desktop,
          );

          if (desktop) {
            return Row(
              children: [
                SizedBox(
                  width: constraints.maxWidth <= 900 ? 360 : 408,
                  child: PlannerPanel(
                    controller: _controller,
                    originText: _originText,
                    destinationText: _destinationText,
                    desktop: true,
                  ),
                ),
                Expanded(child: map),
              ],
            );
          }

          return Stack(
            children: [
              Positioned.fill(child: map),
              DraggableScrollableSheet(
                initialChildSize: 0.56,
                minChildSize: 0.20,
                maxChildSize: 0.88,
                snap: true,
                snapSizes: const [0.20, 0.56, 0.88],
                builder: (context, scrollController) => PlannerPanel(
                  controller: _controller,
                  originText: _originText,
                  destinationText: _destinationText,
                  desktop: false,
                  scrollController: scrollController,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
