import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/access_provider.dart';
import '../../../modules/auth/controller/auth_controller.dart';
import '../../../shared/widgets/dynamic_data_table.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';

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
      final authController = context.read<AuthController>();
      final accessProvider = context.read<AccessProvider>();
      await authController.fetchRegistrationOptions();
      await accessProvider.ensureLoaded();
      if (!mounted) return;
      await accessProvider.ensureAuditLoaded();
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
            for (final r in roles) r: access.hasMenuAccess(r, route),
          },
        )
        .toList(growable: false);

    final fields = <DynamicTableField>[
      DynamicTableField(
        key: 'route',
        label: 'Module Route',
        width: 180,
        filterRequired: false,
        builder: (context, value, row, rowIndex) {
          final route = (value ?? '').toString();
          return Text(
            access.labelForRoute(route, role: 'Admin'),
            style: const TextStyle(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          );
        },
      ),
      ...roles.map(
        (r) => DynamicTableField(
          key: r,
          label: r,
          width: 108,
          filterRequired: false,
          builder: (context, value, row, rowIndex) {
            final route = (row['route'] ?? '').toString();
            final has = value == true;
            final canEdit = r != 'Admin' || route != '/access-provider';
            return Align(
              alignment: Alignment.centerLeft,
              child: Switch(
                value: has,
                onChanged: canEdit
                    ? (enabled) async {
                        final ok = await access.setMenuAccess(
                          role: r,
                          route: route,
                          allowed: enabled,
                        );
                        if (!context.mounted || ok) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              access.errorMessage ??
                                  'Could not save permissions.',
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            );
          },
        ),
      ),
    ];

    final auditFields = <DynamicTableField>[
      const DynamicTableField(
        key: 'changedAt',
        label: 'When',
        width: 170,
        filterRequired: false,
      ),
      const DynamicTableField(
        key: 'changedByName',
        label: 'Changed By',
        width: 160,
        filterRequired: false,
      ),
      const DynamicTableField(
        key: 'action',
        label: 'Action',
        width: 90,
        filterRequired: false,
      ),
      const DynamicTableField(
        key: 'role',
        label: 'Role',
        width: 120,
        filterRequired: false,
      ),
      const DynamicTableField(
        key: 'routeLabel',
        label: 'Module',
        width: 150,
        filterRequired: false,
      ),
      const DynamicTableField(
        key: 'change',
        label: 'Change',
        width: 100,
        filterRequired: false,
      ),
    ];

    final auditRows = access.auditLogs
        .map((row) {
          final changedAt = (row['changedAt'] ?? '').toString();
          final route = (row['route'] ?? '').toString();
          final actor =
              (row['changedByName'] ?? row['changedByUserId'] ?? 'Unknown')
                  .toString();
          final oldAllowed = row['oldAllowed'] == true;
          final newAllowed = row['newAllowed'] == true;
          final change = oldAllowed == newAllowed
              ? 'No change'
              : (newAllowed ? 'Enabled' : 'Disabled');

          return <String, dynamic>{
            'changedAt': _formatDateTime(changedAt),
            'changedByName': actor,
            'action': (row['action'] ?? '').toString().toUpperCase(),
            'role': (row['role'] ?? '').toString(),
            'routeLabel': access.labelForRoute(route, role: 'Admin'),
            'change': change,
          };
        })
        .toList(growable: false);

    return ListView(
      children: [
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Access Provider',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Control menu and route permissions per role.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await access.resetDefaults();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Permissions reset and saved.'
                            : (access.errorMessage ?? 'Reset failed.'),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reset Defaults'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Registered Roles & Departments',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...AppConstants.userRoles.map(
                    (role) => Chip(
                      label: Text(role),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Departments',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...AppConstants.departments.map(
                    (department) => Chip(
                      label: Text(department),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassContainer(
          child: DynamicDataTable(
            fields: fields,
            rows: rows,
            headingRowHeight: 44,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 64,
            columnSpacing: 18,
            empty: const EmptyStateWidget(
              icon: Icons.rule_folder_outlined,
              title: 'No routes configured',
              description: 'Menu routes are unavailable right now.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Audit Log',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                onPressed: access.isAuditLoading
                    ? null
                    : () async {
                        final ok = await access.loadAuditLogs();
                        if (!context.mounted || ok) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              access.errorMessage ??
                                  'Could not load audit logs.',
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassContainer(
          child: DynamicDataTable(
            fields: auditFields,
            rows: auditRows,
            headingRowHeight: 44,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 56,
            columnSpacing: 18,
            empty: access.isAuditLoading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const EmptyStateWidget(
                    icon: Icons.history,
                    title: 'No audit records',
                    description: 'Permission changes will appear here.',
                  ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(String value) {
    if (value.isEmpty) return '—';
    final dt = DateTime.tryParse(value);
    if (dt == null) return value;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
