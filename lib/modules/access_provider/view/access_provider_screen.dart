import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/access_provider.dart';
import '../../../core/utils/size_config.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/sortable_header.dart';
import '../../auth/controller/auth_controller.dart';

class AccessProviderScreen extends StatefulWidget {
  const AccessProviderScreen({super.key});

  @override
  State<AccessProviderScreen> createState() => _AccessProviderScreenState();
}

class _AccessProviderScreenState extends State<AccessProviderScreen> {
  bool _loadScheduled = false;

  // Permission-matrix column sorting (0 = Menu, 1..n = roles,
  // n+1..n+m = departments).
  int? _permissionSortIndex;
  bool _permissionSortAscending = true;

  String _deptKey(String department) =>
      'dept:${department.trim().toUpperCase()}';

  void _togglePermissionSort(int index) {
    setState(() {
      if (_permissionSortIndex == index) {
        _permissionSortAscending = !_permissionSortAscending;
      } else {
        _permissionSortIndex = index;
        _permissionSortAscending = true;
      }
    });
  }

  List<Map<String, dynamic>> _sortedPermissionRows(
    List<Map<String, dynamic>> rows,
    List<String> roles,
    List<String> departments,
    AccessProvider access,
  ) {
    final index = _permissionSortIndex;
    if (index == null) return rows;
    final sorted = [...rows];
    sorted.sort((a, b) {
      int cmp;
      if (index == 0) {
        final la = access.labelForRoute(a['route'].toString(), role: 'Admin');
        final lb = access.labelForRoute(b['route'].toString(), role: 'Admin');
        cmp = compareCellValues(la, lb);
      } else if (index <= roles.length) {
        final role = roles[index - 1];
        cmp = compareCellValues(a[role] == true, b[role] == true);
      } else {
        final dept = departments[index - 1 - roles.length];
        final key = _deptKey(dept);
        cmp = compareCellValues(a[key] == true, b[key] == true);
      }
      return _permissionSortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _loadScheduled) return;
      _loadScheduled = true;
      final auth = context.read<AuthController>();
      final access = context.read<AccessProvider>();
      await auth.fetchRegistrationOptions();
      // Fresh load every time so brand-new roles/departments appear without
      // requiring a full app reload (ensureLoaded caches after first load).
      await access.loadPermissions();
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final access = context.watch<AccessProvider>();
    final role = auth.currentUser?.role ?? '';

    if (!access.isAdminRole(role)) {
      return const Center(
        child: EmptyStateWidget(
          icon: Icons.lock_outline,
          title: 'Access denied',
          description: 'Only Admin can manage menu permissions.',
        ),
      );
    }

    final roles = access.roles;
    final departments = List<String>.from(AppConstants.departments);
    final routes = AccessProvider.orderedMenuRoutes;
    final rows = routes
        .map(
          (route) => <String, dynamic>{
            'route': route,
            for (final item in roles) item: access.hasMenuAccess(item, route),
            for (final dept in departments)
              _deptKey(dept): access.hasDepartmentMenuAccess(dept, route),
          },
        )
        .toList(growable: false);
    final sortedRows = _sortedPermissionRows(rows, roles, departments, access);

    return Padding(
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 12)),
      child: GlassContainer(
        padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _matrixHeader(
              context,
              access,
              routes.length,
              roles.length,
              departments.length,
            ),
            SizedBox(height: SizeConfig.scaleHeight(context, 12)),
            Expanded(
              child: rows.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.rule_folder_outlined,
                      title: 'No routes configured',
                      description: 'Menu routes are unavailable right now.',
                    )
                  : _permissionTable(
                      context,
                      access,
                      roles,
                      departments,
                      sortedRows,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _matrixHeader(
    BuildContext context,
    AccessProvider access,
    int routeCount,
    int roleCount,
    int departmentCount,
  ) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: SizeConfig.scaleWidth(context, 12),
      runSpacing: SizeConfig.scaleHeight(context, 10),
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 9)),
              decoration: BoxDecoration(
                color: AppColors.brandGreen.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.admin_panel_settings_outlined,
                color: AppColors.brandGreen,
                size: SizeConfig.iconSize(context, 22),
              ),
            ),
            SizedBox(width: SizeConfig.scaleWidth(context, 10)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Permission Matrix',
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(context, 18),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$routeCount menus x $roleCount roles + '
                  '$departmentCount departments',
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(context, 12),
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Reset permissions',
              onPressed: access.isSaving ? null : _resetPermissions,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'Delete options by department',
              onPressed: access.isSavingSettings
                  ? null
                  : () => _showDeleteOptionsDialog(context, access),
              icon: Icon(
                _allDepartmentsDeleteEnabled(access)
                    ? Icons.delete_sweep_outlined
                    : Icons.delete_forever_outlined,
                color: _allDepartmentsDeleteEnabled(access)
                    ? AppColors.brandGreen
                    : Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _permissionTable(
    BuildContext context,
    AccessProvider access,
    List<String> roles,
    List<String> departments,
    List<Map<String, dynamic>> rows,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                AppColors.brandGreen.withValues(alpha: 0.12),
              ),
              dataRowMinHeight: 56,

              border: TableBorder(
                borderRadius: BorderRadius.all(Radius.circular(0)),
                horizontalInside: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
              dataRowMaxHeight: 64,
              columnSpacing: SizeConfig.scaleWidth(context, 28),
              columns: [
                DataColumn(
                  columnWidth: FixedColumnWidth(
                    SizeConfig.scaleWidth(context, 723),
                  ),
                  label: SortableHeader(
                    label: 'Menu',
                    isSorted: _permissionSortIndex == 0,
                    sortAscending: _permissionSortAscending,
                    onTap: () => _togglePermissionSort(0),
                  ),
                ),
                ...roles.map(
                  (item) => DataColumn(
                    label: SortableHeader(
                      label: item,
                      isSorted: _permissionSortIndex == roles.indexOf(item) + 1,
                      sortAscending: _permissionSortAscending,
                      onTap: () =>
                          _togglePermissionSort(roles.indexOf(item) + 1),
                    ),
                  ),
                ),
                ...departments.map(
                  (dept) => DataColumn(
                    label: SortableHeader(
                      label: dept,
                      isSorted:
                          _permissionSortIndex ==
                          roles.length + departments.indexOf(dept) + 1,
                      sortAscending: _permissionSortAscending,
                      onTap: () => _togglePermissionSort(
                        roles.length + departments.indexOf(dept) + 1,
                      ),
                    ),
                  ),
                ),
              ],
              rows: rows
                  .map((row) {
                    final route = row['route'].toString();
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            access.labelForRoute(route, role: 'Admin'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        ...roles.map((item) {
                          final canEdit = item != 'Admin';
                          final color = _roleColor(item);
                          return DataCell(
                            Switch(
                              value: row[item] == true,
                              onChanged: canEdit
                                  ? (enabled) => _updateMenuAccess(
                                      context,
                                      access,
                                      item,
                                      route,
                                      enabled,
                                    )
                                  : null,
                              activeThumbColor: color,
                              activeTrackColor: color.withValues(alpha: 0.45),
                            ),
                          );
                        }),
                        ...departments.map((dept) {
                          final color = _departmentColor(dept);
                          return DataCell(
                            Switch(
                              value: row[_deptKey(dept)] == true,
                              onChanged: (enabled) =>
                                  _updateDepartmentMenuAccess(
                                    context,
                                    access,
                                    dept,
                                    route,
                                    enabled,
                                  ),
                              activeThumbColor: color,
                              activeTrackColor: color.withValues(alpha: 0.45),
                            ),
                          );
                        }),
                      ],
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resetPermissions() async {
    final access = context.read<AccessProvider>();
    final ok = await access.resetDefaults();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Permissions reset and saved.'
              : (access.errorMessage ?? 'Reset failed.'),
        ),
      ),
    );
  }

  Future<void> _showDeleteOptionsDialog(
    BuildContext context,
    AccessProvider access,
  ) async {
    final departments = List<String>.from(AppConstants.departments);
    if (departments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No departments available yet.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.delete_sweep_outlined, color: AppColors.brandGreen),
                const SizedBox(width: 10),
                const Expanded(child: Text('Delete Options by Department')),
              ],
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Enable or disable delete actions for each department. '
                      'Users see delete buttons only when their department '
                      'is enabled.',
                      style: TextStyle(
                        fontSize: SizeConfig.fontSize(context, 13),
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final dept in departments)
                          SwitchListTile(
                            dense: true,
                            title: Text(
                              dept,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              access.deleteEnabledForDepartment(dept)
                                  ? 'Delete enabled'
                                  : 'Delete disabled',
                            ),
                            activeThumbColor: AppColors.brandGreen,
                            activeTrackColor: AppColors.brandGreen.withValues(
                              alpha: 0.45,
                            ),
                            value: access.deleteEnabledForDepartment(dept),
                            onChanged: (enabled) async {
                              await _setDepartmentDeleteOption(
                                dialogContext,
                                access,
                                dept,
                                enabled,
                              );
                              if (dialogContext.mounted) {
                                setDialogState(() {});
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _allDepartmentsDeleteEnabled(AccessProvider access) {
    final departments = AppConstants.departments;
    if (departments.isEmpty) return access.deleteEnabled;
    return departments.every((dept) => access.deleteEnabledForDepartment(dept));
  }

  Future<void> _setDepartmentDeleteOption(
    BuildContext context,
    AccessProvider access,
    String department,
    bool enabled,
  ) async {
    final ok = await access.setDeleteEnabled(enabled, department: department);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '$department delete ${enabled ? 'enabled' : 'disabled'}'
              : (access.errorMessage ?? 'Could not update delete options.'),
        ),
      ),
    );
  }

  Future<void> _updateMenuAccess(
    BuildContext context,
    AccessProvider access,
    String role,
    String route,
    bool enabled,
  ) async {
    final ok = await access.setMenuAccess(
      role: role,
      route: route,
      allowed: enabled,
    );
    if (!context.mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(access.errorMessage ?? 'Could not save permissions.'),
      ),
    );
  }

  Future<void> _updateDepartmentMenuAccess(
    BuildContext context,
    AccessProvider access,
    String department,
    String route,
    bool enabled,
  ) async {
    final ok = await access.setDepartmentMenuAccess(
      department: department,
      route: route,
      allowed: enabled,
    );
    if (!context.mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          access.errorMessage ?? 'Could not save department permissions.',
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'artist':
        return const Color(0xFF3B82F6);
      case 'coordinator':
        return const Color(0xFF8B5CF6);
      case 'supervisor':
        return const Color(0xFFF59E0B);
      case 'team lead':
        return const Color(0xFF06B6D4);
      case 'admin':
        return const Color(0xFFEF4444);
      case 'manager':
        return const Color(0xFF10B981);
      case 'production':
        return const Color(0xFFF97316);
      case 'management':
        return const Color(0xFFEC4899);
      default:
        return AppColors.brandGreen;
    }
  }

  Color _departmentColor(String department) {
    // Departments get a distinct tint so the department columns read as a
    // separate group from the role columns.
    switch (department.toLowerCase()) {
      case 'roto':
        return const Color(0xFF22C55E);
      case 'paint':
        return const Color(0xFFEF4444);
      case 'mm':
        return const Color(0xFFF59E0B);
      case 'comp':
        return const Color(0xFF3B82F6);
      case 'production':
        return const Color(0xFFF97316);
      case 'management':
        return const Color(0xFFEC4899);
      default:
        return AppColors.brandGreen;
    }
  }
}
