import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/access_provider.dart';
import '../../../core/utils/size_config.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/sortable_header.dart';
import '../../auth/controller/auth_controller.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccessProvider>().loadAuditLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthController>().currentUser?.role ?? '';
    final access = context.watch<AccessProvider>();

    if (!access.isAdminRole(role)) {
      return const Center(
        child: EmptyStateWidget(
          icon: Icons.lock_outline,
          title: 'Access denied',
          description: 'Only Admin can view audit logs.',
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 12)),
      child: GlassContainer(
        padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _auditHeader(context, access),
            SizedBox(height: SizeConfig.scaleHeight(context, 12)),
            Expanded(
              child: access.isAuditLoading && !access.auditLoaded
                  ? const Center(child: CircularProgressIndicator())
                  : access.auditErrorMessage != null && !access.auditLoaded
                  ? EmptyStateWidget(
                      icon: Icons.error_outline,
                      title: 'Unable to load audit logs',
                      description: access.auditErrorMessage!,
                    )
                  : _AuditLogTable(logs: access.auditLogs),
            ),
          ],
        ),
      ),
    );
  }

  Widget _auditHeader(BuildContext context, AccessProvider access) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 9)),
          decoration: BoxDecoration(
            color: AppColors.brandGreen.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.security_outlined,
            color: AppColors.brandGreen,
            size: SizeConfig.iconSize(context, 22),
          ),
        ),
        SizedBox(width: SizeConfig.scaleWidth(context, 10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Audit Logs',
                style: TextStyle(
                  fontSize: SizeConfig.fontSize(context, 18),
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${access.auditLogs.length} activity logs across all modules',
                style: TextStyle(
                  fontSize: SizeConfig.fontSize(context, 12),
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh audit logs',
          onPressed: access.isAuditLoading
              ? null
              : () => access.loadAuditLogs(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _AuditLogTable extends StatefulWidget {
  final List<Map<String, dynamic>> logs;

  const _AuditLogTable({required this.logs});

  @override
  State<_AuditLogTable> createState() => _AuditLogTableState();
}

class _AuditLogTableState extends State<_AuditLogTable> {
  int? _sortColumnIndex;
  bool _sortAscending = true;

  void _toggleSort(int index) {
    setState(() {
      if (_sortColumnIndex == index) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = index;
        _sortAscending = true;
      }
    });
  }

  dynamic _sortValue(int index, Map<String, dynamic> row) {
    switch (index) {
      case 0:
        return row['module'] ?? 'Access Provider';
      case 1:
        return row['entityType'] ?? row['route'] ?? '-';
      case 2:
        return row['action'] ?? '-';
      case 3:
        return row['role'] ?? '-';
      case 4:
        return row['changedByUsername'] ?? row['changedByUserId'] ?? '-';
      case 5:
        return row['newAllowed'] is bool ? row['newAllowed'] : '-';
      case 6:
        if (row['details'] is Map) {
          return (row['details'] as Map).entries
              .map((entry) => '${entry.key}: ${entry.value}')
              .join(', ');
        }
        return '-';
      case 7:
      default:
        return row['changedAt'] ?? '';
    }
  }

  List<Map<String, dynamic>> get _sortedLogs {
    final index = _sortColumnIndex;
    if (index == null) return widget.logs;
    final sorted = [...widget.logs];
    sorted.sort((a, b) {
      final cmp = compareCellValues(_sortValue(index, a), _sortValue(index, b));
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final sortedLogs = _sortedLogs;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: RefreshIndicator(
            onRefresh: () => context.read<AccessProvider>().loadAuditLogs(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  AppColors.brandGreen.withValues(alpha: 0.12),
                ),
                dataRowMinHeight: 56,
                dataRowMaxHeight: 64,
                columnSpacing: SizeConfig.scaleWidth(context, 28),
                border: TableBorder(
                  borderRadius: BorderRadius.all(Radius.circular(0)),
                  horizontalInside: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
                columns: [
                  DataColumn(
                    label: SortableHeader(
                      label: 'Module',
                      isSorted: _sortColumnIndex == 0,
                      sortAscending: _sortAscending,
                      onTap: () => _toggleSort(0),
                    ),
                  ),
                  DataColumn(
                    label: SortableHeader(
                      label: 'Entity',
                      isSorted: _sortColumnIndex == 1,
                      sortAscending: _sortAscending,
                      onTap: () => _toggleSort(1),
                    ),
                  ),
                  DataColumn(
                    label: SortableHeader(
                      label: 'Action',
                      isSorted: _sortColumnIndex == 2,
                      sortAscending: _sortAscending,
                      onTap: () => _toggleSort(2),
                    ),
                  ),
                  DataColumn(
                    label: SortableHeader(
                      label: 'Role',
                      isSorted: _sortColumnIndex == 3,
                      sortAscending: _sortAscending,
                      onTap: () => _toggleSort(3),
                    ),
                  ),
                  DataColumn(
                    label: SortableHeader(
                      label: 'Username',
                      isSorted: _sortColumnIndex == 4,
                      sortAscending: _sortAscending,
                      onTap: () => _toggleSort(4),
                    ),
                  ),
                  DataColumn(
                    label: SortableHeader(
                      label: 'Change',
                      isSorted: _sortColumnIndex == 5,
                      sortAscending: _sortAscending,
                      onTap: () => _toggleSort(5),
                    ),
                  ),
                  DataColumn(
                    label: SortableHeader(
                      label: 'Details',
                      isSorted: _sortColumnIndex == 6,
                      sortAscending: _sortAscending,
                      onTap: () => _toggleSort(6),
                    ),
                  ),
                  DataColumn(
                    label: SortableHeader(
                      label: 'Changed At',
                      isSorted: _sortColumnIndex == 7,
                      sortAscending: _sortAscending,
                      onTap: () => _toggleSort(7),
                    ),
                  ),
                ],
                rows: sortedLogs
                    .map((row) {
                      final hasPermissionChange = row['oldAllowed'] is bool;
                      final enabled = row['newAllowed'] == true;
                      final username =
                          (row['changedByUsername'] ??
                                  row['changedByUserId'] ??
                                  '-')
                              .toString();
                      final details = row['details'] is Map
                          ? (row['details'] as Map).entries
                                .map((entry) => '${entry.key}: ${entry.value}')
                                .join(', ')
                          : '-';
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              (row['module'] ?? 'Access Provider').toString(),
                            ),
                          ),
                          DataCell(
                            Text(
                              (row['entityType'] ?? row['route'] ?? '-')
                                  .toString(),
                            ),
                          ),
                          DataCell(
                            Text(
                              (row['action'] ?? '-').toString().toUpperCase(),
                            ),
                          ),
                          DataCell(Text((row['role'] ?? '-').toString())),
                          DataCell(Text(username)),
                          DataCell(
                            Text(
                              hasPermissionChange
                                  ? (enabled ? 'Enabled' : 'Disabled')
                                  : '-',
                            ),
                          ),
                          DataCell(Text(details)),
                          DataCell(
                            Text(
                              _formatDateTime(
                                (row['changedAt'] ?? '').toString(),
                              ),
                            ),
                          ),
                        ],
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(String raw) {
  if (raw.isEmpty) return 'Unknown time';
  final parsed = DateTime.tryParse(raw)?.toLocal();
  if (parsed == null) return raw;
  final date =
      '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')}';
  final time =
      '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}
