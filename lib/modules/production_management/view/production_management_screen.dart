import 'package:flutter/material.dart';

import '../../projects/view/projects_screen.dart';

class ProductionManagementScreen extends StatelessWidget {
  const ProductionManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProjectsScreen(
      moduleLabel: 'Production Management',
      exportFilePrefix: 'production_management',
    );
  }
}
