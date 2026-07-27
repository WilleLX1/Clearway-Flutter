import 'package:flutter/material.dart';

import 'core/theme/clearway_theme.dart';
import 'features/route_planner/route_planner_controller.dart';
import 'features/route_planner/route_planner_screen.dart';

class ClearwayApp extends StatelessWidget {
  const ClearwayApp({super.key, this.controller});

  final RoutePlannerController? controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clearway — signal-aware routing',
      debugShowCheckedModeBanner: false,
      theme: ClearwayTheme.light,
      home: RoutePlannerScreen(controller: controller),
    );
  }
}
