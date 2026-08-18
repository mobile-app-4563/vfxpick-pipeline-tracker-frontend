import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/access_provider.dart';
import '../../../core/utils/size_config.dart';
import '../../../modules/auth/controller/auth_controller.dart';
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
      await accessProvider.loadAuditLogs();
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

    final totalRoutes = routes.length;
    final totalRoles = roles.length;
    final totalDepts = AppConstants.departments.length;
    final totalAudits = access.auditLogs.length;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        SizeConfig.scaleWidth(context, 12),
        SizeConfig.scaleHeight(context, 12),
        SizeConfig.scaleWidth(context, 12),
        SizeConfig.scaleHeight(context, 24),
      ),
      children: [
        // ── Stunning Header Card ──
        // SizedBox(height: SizeConfig.scaleHeight(context, 16)),

        // ── Roles & Departments ──
        // GlassContainer.responsive(
        //   context: context,
        //   borderRadius: SizeConfig.scaleWidth(context, 14),
        //   padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 16)),
        //   child: Column(
        //     crossAxisAlignment: CrossAxisAlignment.start,
        //     children: [
        //       Row(
        //         children: [
        //           Icon(
        //             Icons.people_rounded,
        //             size: SizeConfig.iconSize(context, 18),
        //             color: AppColors.brandGreen,
        //           ),
        //           SizedBox(width: SizeConfig.scaleWidth(context, 8)),
        //           Text(
        //             'Roles & Departments',
        //             style: TextStyle(
        //               fontSize: SizeConfig.fontSize(context, 16),
        //               fontWeight: FontWeight.w600,
        //             ),
        //           ),
        //         ],
        //       ),
        //       SizedBox(height: SizeConfig.scaleHeight(context, 14)),
        //       Text(
        //         'Roles',
        //         style: TextStyle(
        //           fontSize: SizeConfig.fontSize(context, 13),
        //           fontWeight: FontWeight.w600,
        //           color: Colors.grey.shade400,
        //         ),
        //       ),
        //       SizedBox(height: SizeConfig.scaleHeight(context, 8)),
        //       Wrap(
        //         spacing: SizeConfig.scaleWidth(context, 8),
        //         runSpacing: SizeConfig.scaleHeight(context, 8),
        //         children: roles.map((r) => _rolePill(context, r)).toList(),
        //       ),
        //       SizedBox(height: SizeConfig.scaleHeight(context, 16)),
        //       Text(
        //         'Departments',
        //         style: TextStyle(
        //           fontSize: SizeConfig.fontSize(context, 13),
        //           fontWeight: FontWeight.w600,
        //           color: Colors.grey.shade400,
        //         ),
        //       ),
        //       SizedBox(height: SizeConfig.scaleHeight(context, 8)),
        //       Wrap(
        //         spacing: SizeConfig.scaleWidth(context, 8),
        //         runSpacing: SizeConfig.scaleHeight(context, 8),
        //         children: AppConstants.departments
        //             .map((d) => _deptPill(context, d))
        //             .toList(),
        //       ),
        //     ],
        //   ),
        // ),
        // SizedBox(height: SizeConfig.scaleHeight(context, 16)),

        // ── Access Control Header ──
        SizedBox(
          width: double.infinity,
          child: GlassContainer.responsive(
            context: context,
            borderRadius: SizeConfig.scaleWidth(context, 16),
            padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        SizeConfig.scaleWidth(context, 10),
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(
                          SizeConfig.scaleWidth(context, 12),
                        ),
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: SizeConfig.iconSize(context, 26),
                      ),
                    ),
                    SizedBox(width: SizeConfig.scaleWidth(context, 14)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Access Control',
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(context, 20),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Manage role-based menu and route permissions',
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(context, 13),
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: SizeConfig.scaleHeight(context, 38),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              SizeConfig.scaleWidth(context, 10),
                            ),
                          ),
                        ),
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
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: SizeConfig.scaleHeight(context, 16)),
                // Stats chips
                Wrap(
                  spacing: SizeConfig.scaleWidth(context, 8),
                  runSpacing: SizeConfig.scaleHeight(context, 8),
                  children: [
                    _statChip(
                      context,
                      Icons.badge_rounded,
                      'Roles',
                      '$totalRoles',
                    ),
                    _statChip(
                      context,
                      Icons.business_rounded,
                      'Departments',
                      '$totalDepts',
                    ),
                    _statChip(
                      context,
                      Icons.alt_route_rounded,
                      'Routes',
                      '$totalRoutes',
                    ),
                    _statChip(
                      context,
                      Icons.history_rounded,
                      'Audit Entries',
                      '$totalAudits',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Permission Matrix ──
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: SizeConfig.scaleWidth(context, 4),
                  bottom: SizeConfig.scaleHeight(context, 10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings_rounded,
                      size: SizeConfig.iconSize(context, 18),
                      color: AppColors.brandGreen,
                    ),
                    SizedBox(width: SizeConfig.scaleWidth(context, 8)),
                    Text(
                      'Permission Matrix',
                      style: TextStyle(
                        fontSize: SizeConfig.fontSize(context, 15),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${rows.length} routes × $totalRoles roles',
                      style: TextStyle(
                        fontSize: SizeConfig.fontSize(context, 11),
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.rule_folder_outlined,
                        title: 'No routes configured',
                        description: 'Menu routes are unavailable right now.',
                      )
                    : ListView(
                        children: rows.map((row) {
                          final route = (row['route'] ?? '').toString();
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: SizeConfig.scaleHeight(context, 8),
                            ),
                            child: GlassContainer.responsive(
                              context: context,
                              borderRadius: SizeConfig.scaleWidth(context, 12),
                              padding: EdgeInsets.symmetric(
                                horizontal: SizeConfig.scaleWidth(context, 12),
                                vertical: SizeConfig.scaleHeight(context, 10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(
                                          SizeConfig.scaleWidth(context, 5),
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF8B5CF6,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            SizeConfig.scaleWidth(context, 5),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.alt_route_rounded,
                                          size: SizeConfig.iconSize(
                                            context,
                                            14,
                                          ),
                                          color: const Color(0xFF8B5CF6),
                                        ),
                                      ),
                                      SizedBox(
                                        width: SizeConfig.scaleWidth(
                                          context,
                                          8,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          access.labelForRoute(
                                            route,
                                            role: 'Admin',
                                          ),
                                          style: TextStyle(
                                            fontSize: SizeConfig.fontSize(
                                              context,
                                              13,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: SizeConfig.scaleHeight(context, 8),
                                  ),
                                  Wrap(
                                    spacing: SizeConfig.scaleWidth(context, 6),
                                    runSpacing: SizeConfig.scaleHeight(
                                      context,
                                      6,
                                    ),
                                    children: roles.map((r) {
                                      final has = row[r] == true;
                                      final canEdit =
                                          r != 'Admin' ||
                                          route != '/access-provider';
                                      final roleColor = _roleColor(r);
                                      return Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: SizeConfig.scaleWidth(
                                            context,
                                            6,
                                          ),
                                          vertical: SizeConfig.scaleHeight(
                                            context,
                                            3,
                                          ),
                                        ),
                                        decoration: BoxDecoration(
                                          color: roleColor.withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(
                                            SizeConfig.scaleWidth(context, 6),
                                          ),
                                          border: Border.all(
                                            color: roleColor.withOpacity(0.15),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _roleIcon(r),
                                              size: SizeConfig.iconSize(
                                                context,
                                                11,
                                              ),
                                              color: roleColor,
                                            ),
                                            SizedBox(
                                              width: SizeConfig.scaleWidth(
                                                context,
                                                3,
                                              ),
                                            ),
                                            Text(
                                              r,
                                              style: TextStyle(
                                                fontSize: SizeConfig.fontSize(
                                                  context,
                                                  10,
                                                ),
                                                fontWeight: FontWeight.w500,
                                                color: roleColor,
                                              ),
                                            ),
                                            SizedBox(
                                              width: SizeConfig.scaleWidth(
                                                context,
                                                4,
                                              ),
                                            ),
                                            SizedBox(
                                              // height:
                                              //     SizeConfig.scaleHeight(
                                              //       context,
                                              //       18,
                                              //     ),
                                              child: Switch(
                                                value: has,
                                                activeTrackColor: roleColor
                                                    .withOpacity(0.5),
                                                activeThumbColor: roleColor,
                                                inactiveTrackColor: Colors.grey
                                                    .withOpacity(0.2),
                                                onChanged: canEdit
                                                    ? (enabled) async {
                                                        final ok = await access
                                                            .setMenuAccess(
                                                              role: r,
                                                              route: route,
                                                              allowed: enabled,
                                                            );
                                                        if (!context.mounted ||
                                                            ok) {
                                                          return;
                                                        }
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
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
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: SizeConfig.scaleWidth(context, 4),
                  bottom: SizeConfig.scaleHeight(context, 10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: SizeConfig.iconSize(context, 18),
                      color: AppColors.brandGreen,
                    ),
                    SizedBox(width: SizeConfig.scaleWidth(context, 8)),
                    Expanded(
                      child: Text(
                        'Audit Log',
                        style: TextStyle(
                          fontSize: SizeConfig.fontSize(context, 15),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: SizeConfig.scaleHeight(context, 30),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brandGreen,
                          side: BorderSide(
                            color: AppColors.brandGreen.withOpacity(0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              SizeConfig.scaleWidth(context, 6),
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: SizeConfig.scaleWidth(context, 8),
                          ),
                        ),
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
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text(
                          'Refresh',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: access.isAuditLoading
                    ? const Center(child: CircularProgressIndicator())
                    : access.auditErrorMessage != null
                    ? EmptyStateWidget(
                        icon: Icons.error_outline,
                        title: 'Could not load audit log',
                        description: access.auditErrorMessage!,
                      )
                    : auditRows.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.history,
                        title: 'No audit records',
                        description: 'Permission changes will appear here.',
                      )
                    : ListView(
                        children: auditRows.asMap().entries.map((entry) {
                          final i = entry.key;
                          final row = entry.value;
                          final action = (row['action'] ?? '').toString();
                          final isCreate =
                              action == 'CREATE' || action == 'INSERT';
                          final isUpdate = action == 'UPDATE';
                          final isDelete = action == 'DELETE';
                          final change = (row['change'] ?? '').toString();
                          final isEnabled = change == 'Enabled';
                          final isDisabled = change == 'Disabled';

                          Color actionColor;
                          IconData actionIcon;
                          if (isCreate) {
                            actionColor = const Color(0xFF10B981);
                            actionIcon = Icons.add_circle_outline;
                          } else if (isUpdate) {
                            actionColor = const Color(0xFF3B82F6);
                            actionIcon = Icons.edit_outlined;
                          } else if (isDelete) {
                            actionColor = const Color(0xFFEF4444);
                            actionIcon = Icons.delete_outline;
                          } else {
                            actionColor = Colors.grey;
                            actionIcon = Icons.circle_outlined;
                          }

                          Color changeColor;
                          IconData changeIcon;
                          if (isEnabled) {
                            changeColor = const Color(0xFF10B981);
                            changeIcon = Icons.check_circle_outline;
                          } else if (isDisabled) {
                            changeColor = const Color(0xFFEF4444);
                            changeIcon = Icons.cancel_outlined;
                          } else {
                            changeColor = Colors.grey;
                            changeIcon = Icons.remove_circle_outline;
                          }

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: SizeConfig.scaleHeight(context, 6),
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Timeline dot
                                  SizedBox(
                                    width: SizeConfig.scaleWidth(context, 20),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: SizeConfig.scaleWidth(
                                            context,
                                            8,
                                          ),
                                          height: SizeConfig.scaleWidth(
                                            context,
                                            8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: actionColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        if (i < auditRows.length - 1)
                                          Expanded(
                                            child: Container(
                                              width: 1,
                                              color: actionColor.withOpacity(
                                                0.2,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: SizeConfig.scaleWidth(context, 6),
                                  ),
                                  // Audit card
                                  Expanded(
                                    child: GlassContainer.responsive(
                                      context: context,
                                      borderRadius: SizeConfig.scaleWidth(
                                        context,
                                        8,
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: SizeConfig.scaleWidth(
                                          context,
                                          10,
                                        ),
                                        vertical: SizeConfig.scaleHeight(
                                          context,
                                          8,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal:
                                                      SizeConfig.scaleWidth(
                                                        context,
                                                        4,
                                                      ),
                                                  vertical:
                                                      SizeConfig.scaleHeight(
                                                        context,
                                                        1,
                                                      ),
                                                ),
                                                decoration: BoxDecoration(
                                                  color: actionColor
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        SizeConfig.scaleWidth(
                                                          context,
                                                          3,
                                                        ),
                                                      ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      actionIcon,
                                                      size: SizeConfig.iconSize(
                                                        context,
                                                        10,
                                                      ),
                                                      color: actionColor,
                                                    ),
                                                    SizedBox(
                                                      width:
                                                          SizeConfig.scaleWidth(
                                                            context,
                                                            2,
                                                          ),
                                                    ),
                                                    Text(
                                                      action,
                                                      style: TextStyle(
                                                        fontSize:
                                                            SizeConfig.fontSize(
                                                              context,
                                                              10,
                                                            ),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: actionColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                width: SizeConfig.scaleWidth(
                                                  context,
                                                  6,
                                                ),
                                              ),
                                              Text(
                                                row['changedAt'] ?? '',
                                                style: TextStyle(
                                                  fontSize: SizeConfig.fontSize(
                                                    context,
                                                    10,
                                                  ),
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                            height: SizeConfig.scaleHeight(
                                              context,
                                              6,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.person_outline,
                                                size: SizeConfig.iconSize(
                                                  context,
                                                  12,
                                                ),
                                                color: Colors.grey.shade400,
                                              ),
                                              SizedBox(
                                                width: SizeConfig.scaleWidth(
                                                  context,
                                                  3,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  row['changedByName'] ?? '',
                                                  style: TextStyle(
                                                    fontSize:
                                                        SizeConfig.fontSize(
                                                          context,
                                                          11,
                                                        ),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              SizedBox(
                                                width: SizeConfig.scaleWidth(
                                                  context,
                                                  6,
                                                ),
                                              ),
                                              Icon(
                                                Icons.badge_rounded,
                                                size: SizeConfig.iconSize(
                                                  context,
                                                  12,
                                                ),
                                                color: _roleColor(
                                                  row['role'] ?? '',
                                                ),
                                              ),
                                              SizedBox(
                                                width: SizeConfig.scaleWidth(
                                                  context,
                                                  3,
                                                ),
                                              ),
                                              Text(
                                                row['role'] ?? '',
                                                style: TextStyle(
                                                  fontSize: SizeConfig.fontSize(
                                                    context,
                                                    11,
                                                  ),
                                                  color: _roleColor(
                                                    row['role'] ?? '',
                                                  ),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const Spacer(),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    changeIcon,
                                                    size: SizeConfig.iconSize(
                                                      context,
                                                      12,
                                                    ),
                                                    color: changeColor,
                                                  ),
                                                  SizedBox(
                                                    width:
                                                        SizeConfig.scaleWidth(
                                                          context,
                                                          2,
                                                        ),
                                                  ),
                                                  Text(
                                                    change,
                                                    style: TextStyle(
                                                      fontSize:
                                                          SizeConfig.fontSize(
                                                            context,
                                                            11,
                                                          ),
                                                      color: changeColor,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                            height: SizeConfig.scaleHeight(
                                              context,
                                              2,
                                            ),
                                          ),
                                          Text(
                                            row['routeLabel'] ?? '',
                                            style: TextStyle(
                                              fontSize: SizeConfig.fontSize(
                                                context,
                                                11,
                                              ),
                                              color: Colors.grey.shade500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Helper methods
  // ──────────────────────────────────────────────

  Widget _statChip(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.scaleWidth(context, 10),
        vertical: SizeConfig.scaleHeight(context, 5),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withOpacity(0.08),
        borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 8)),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: SizeConfig.iconSize(context, 14),
            color: const Color(0xFF8B5CF6),
          ),
          SizedBox(width: SizeConfig.scaleWidth(context, 5)),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: SizeConfig.fontSize(context, 12),
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8B5CF6),
            ),
          ),
        ],
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

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'artist':
        return Icons.palette_rounded;
      case 'production':
        return Icons.precision_manufacturing_rounded;
      case 'management':
        return Icons.trending_up_rounded;
      case 'supervisor':
        return Icons.verified_rounded;
      case 'team lead':
        return Icons.auto_awesome_rounded;
      case 'admin':
        return Icons.shield_rounded;
      default:
        return Icons.badge_rounded;
    }
  }

  String _formatDateTime(String value) {
    if (value.isEmpty) return '—';
    final dt = DateTime.tryParse(value);
    if (dt == null) return value;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
