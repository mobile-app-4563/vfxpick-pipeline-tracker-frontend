import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/access_provider.dart';
import '../../../core/utils/size_config.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../auth/controller/auth_controller.dart';

class AccessProviderScreen extends StatefulWidget {
  const AccessProviderScreen({super.key});

  @override
  State<AccessProviderScreen> createState() => _AccessProviderScreenState();
}

class _AccessProviderScreenState extends State<AccessProviderScreen> {
  bool _loadScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _loadScheduled) return;
      _loadScheduled = true;
      final auth = context.read<AuthController>();
      final access = context.read<AccessProvider>();
      await auth.fetchRegistrationOptions();
      await access.ensureLoaded();
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
    final routes = AccessProvider.orderedMenuRoutes;
    final rows = routes
        .map(
          (route) => <String, dynamic>{
            'route': route,
            for (final item in roles) item: access.hasMenuAccess(item, route),
          },
        )
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 12)),
      child: GlassContainer(
        padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _matrixHeader(context, access, routes.length, roles.length),
            SizedBox(height: SizeConfig.scaleHeight(context, 12)),
            Expanded(
              child: rows.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.rule_folder_outlined,
                      title: 'No routes configured',
                      description: 'Menu routes are unavailable right now.',
                    )
                  : _permissionTable(context, access, roles, rows),
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
                // Text(
                //   '$routeCount menus x $roleCount roles',
                //   style: TextStyle(
                //     fontSize: SizeConfig.fontSize(context, 12),
                //     color: Theme.of(context).textTheme.bodySmall?.color,
                //   ),
                // ),
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
            PopupMenuButton<String>(
              tooltip: 'Delete options',
              enabled: !access.isSavingSettings,
              onSelected: (value) => _setDeleteOption(access, value),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'enable',
                  child: Text('Enable delete for all'),
                ),
                PopupMenuItem(
                  value: 'disable',
                  child: Text('Disable delete for all'),
                ),
              ],
              icon: Icon(
                access.deleteEnabled
                    ? Icons.delete_sweep_outlined
                    : Icons.delete_forever_outlined,
                color: access.deleteEnabled ? AppColors.brandGreen : Colors.red,
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
                  label: Text('Menu'),
                ),
                ...roles.map((item) => DataColumn(label: Text(item))),
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

  Future<void> _setDeleteOption(AccessProvider access, String value) async {
    final ok = await access.setDeleteEnabled(value == 'enable');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? value == 'enable'
                    ? 'Delete options enabled for all users.'
                    : 'Delete options disabled for all users.'
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
}
