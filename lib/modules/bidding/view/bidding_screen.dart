import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/bidding_controller.dart';

/// Bidding page showing pending bids that need supervisor approval.
class BiddingScreen extends StatefulWidget {
  const BiddingScreen({super.key});

  @override
  State<BiddingScreen> createState() => _BiddingScreenState();
}

class _BiddingScreenState extends State<BiddingScreen> {
  String? _selectedDepartment;
  List<String> _accessibleDepartments = AppConstants.pipelineDepartments;
  bool _isBroadAccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthController>().currentUser;
      _isBroadAccess = AppConstants.broadAccessRoles.contains(user?.role);
      final departments = AppConstants.accessiblePipelineDepartments(
        role: user?.role,
        department: user?.department,
      );
      _accessibleDepartments = departments.isEmpty
          ? AppConstants.pipelineDepartments
          : departments;

      if (!_isBroadAccess && _accessibleDepartments.isNotEmpty) {
        _selectedDepartment = _accessibleDepartments.first;
      }

      context.read<BiddingController>().fetchPendingBids(
        department: _selectedDepartment,
      );
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<BiddingController>(
      builder: (context, controller, child) {
        return SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height,
          child: Center(
            child: Text(
              "Coming Soon!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}
