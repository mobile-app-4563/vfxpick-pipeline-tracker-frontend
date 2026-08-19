import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/utils/size_config.dart';
import '../../../shared/widgets/dynamic_data_table.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../controller/dashboard_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _departmentFilter = '';
  String _clientFilter = '';
  String _showFilter = '';
  String _shotsFilter = '';
  String _mandaysFilter = '';
  String _dueFilter = '';
  bool _showCellBorders = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardController>().loadSummary();
      context.read<DashboardController>().loadHomeSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();

    if (controller.isLoading && controller.departments.isEmpty) {
      return const LoadingWidget(message: 'Loading dashboard...');
    }
    if (controller.error != null && controller.departments.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.error_outline,
        title: 'Could not load dashboard',
        description: controller.error!,
        actionLabel: 'Retry',
        onActionPressed: controller.loadSummary,
      );
    }
    if (controller.departments.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.dashboard_outlined,
        title: 'No data yet',
        description: 'There is nothing to show on the dashboard right now.',
      );
    }

    final flatRows = <Map<String, dynamic>>[];
    for (final dept in controller.departments) {
      for (final row in dept.rows) {
        flatRows.add({
          'department': dept.department,
          'client': row.clientName,
          'show': row.showName,
          'shots': row.shotCount,
          'mandays': row.mandays.toStringAsFixed(1),
          'due': row.dueDate != null ? _fmt(row.dueDate!) : '—',
          'row': row,
        });
      }
    }

    final filteredRows = flatRows
        .where((row) {
          bool contains(String key, String query) {
            if (query.trim().isEmpty) return true;
            return (row[key] ?? '').toString().toLowerCase().contains(
              query.trim().toLowerCase(),
            );
          }

          return contains('department', _departmentFilter) &&
              contains('client', _clientFilter) &&
              contains('show', _showFilter) &&
              contains('shots', _shotsFilter) &&
              contains('mandays', _mandaysFilter) &&
              contains('due', _dueFilter);
        })
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          controller.loadSummary(),
          controller.loadHomeSummary(),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _homeSummarySection(context, controller),
          Padding(
            padding: EdgeInsets.only(
              bottom: SizeConfig.scaleHeight(context, 10),
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilterChip(
                selected: _showCellBorders,
                onSelected: (value) => setState(() => _showCellBorders = value),
                avatar: Icon(
                  Icons.border_all,
                  size: SizeConfig.iconSize(context, 18),
                  color: _showCellBorders ? AppColors.brandGreen : null,
                ),
                label: const Text('Cell Borders'),
                showCheckmark: true,
                selectedColor: AppColors.brandGreen.withValues(alpha: 0.12),
                checkmarkColor: AppColors.brandGreen,
                side: BorderSide(
                  color: _showCellBorders
                      ? AppColors.brandGreen
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
          GlassContainer(
            child: DynamicDataTable(
              dataRowMinHeight: MediaQuery.of(context).size.height * 46 / 768,
              dataRowMaxHeight: MediaQuery.of(context).size.height * 60 / 768,
              showCellBorders: _showCellBorders,
              fields: [
                DynamicTableField(
                  key: 'department',
                  label: 'Department',
                  width: SizeConfig.scaleWidth(context, 140),
                ),
                DynamicTableField(
                  key: 'client',
                  label: 'Client',
                  width: SizeConfig.scaleWidth(context, 120),
                ),
                DynamicTableField(
                  key: 'show',
                  label: 'Show',
                  width: SizeConfig.scaleWidth(context, 170),
                ),
                DynamicTableField(
                  key: 'shots',
                  label: 'Shots',
                  width: SizeConfig.scaleWidth(context, 110),
                ),
                DynamicTableField(
                  key: 'mandays',
                  label: 'Mandays',
                  width: SizeConfig.scaleWidth(context, 130),
                ),
                DynamicTableField(
                  key: 'due',
                  label: 'Due Date',
                  width: SizeConfig.scaleWidth(context, 130),
                ),
                DynamicTableField(
                  key: 'actions',
                  label: 'Actions',
                  filterRequired: false,
                  width: SizeConfig.scaleWidth(context, 220),
                  builder: (context, value, row, rowIndex) {
                    final info = row['row'] as DashboardRow;
                    final department = (row['department'] ?? '').toString();
                    return Row(
                      children: [
                        IconButton(
                          tooltip: 'Open Projects',
                          icon: Icon(
                            Icons.folder_open_outlined,
                            size: SizeConfig.iconSize(context, 18),
                          ),
                          onPressed: () => _openConcernPage('/projects', {
                            'department': department,
                            'clientId': info.clientId,
                            'showId': info.showId,
                          }),
                        ),
                        IconButton(
                          tooltip: 'Open Tasks',
                          icon: Icon(
                            Icons.task_alt_outlined,
                            size: SizeConfig.iconSize(context, 18),
                          ),
                          onPressed: () => _openConcernPage('/tasks', {
                            'department': department,
                            'showId': info.showId,
                          }),
                        ),
                        IconButton(
                          tooltip: 'Open Review',
                          icon: Icon(
                            Icons.rate_review_outlined,
                            size: SizeConfig.iconSize(context, 18),
                          ),
                          onPressed: () => _openConcernPage('/review', {
                            'department': department,
                          }),
                        ),
                        IconButton(
                          tooltip: 'Open Reports',
                          icon: Icon(
                            Icons.analytics_outlined,
                            size: SizeConfig.iconSize(context, 18),
                          ),
                          onPressed: () => _openConcernPage('/reports', {
                            'department': department,
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ],
              rows: filteredRows,
              onFilterChanged: (fieldKey, value) {
                setState(() {
                  final v = value is String ? value : value.toString();
                  switch (fieldKey) {
                    case 'department':
                      _departmentFilter = v;
                      break;
                    case 'client':
                      _clientFilter = v;
                      break;
                    case 'show':
                      _showFilter = v;
                      break;
                    case 'shots':
                      _shotsFilter = v;
                      break;
                    case 'mandays':
                      _mandaysFilter = v;
                      break;
                    case 'due':
                      _dueFilter = v;
                      break;
                    default:
                      break;
                  }
                });
              },
              empty: const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No matching rows for current filters.'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _filterField(
  //   String label,
  //   double width,
  //   void Function(String) onChanged,
  // ) {
  //   return SizedBox(
  //     width: width,
  //     child: TextField(
  //       onChanged: (v) => setState(() => onChanged(v)),
  //       decoration: InputDecoration(
  //         isDense: true,
  //         labelText: label,
  //         border: const OutlineInputBorder(),
  //       ),
  //     ),
  //   );
  // }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ─── Home summary: today/tomorrow pickouts + active shows ────────────────
  Widget _homeSummarySection(
    BuildContext context,
    DashboardController controller,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.grey.shade700;

    Widget countCard(String label, int count, IconData icon) {
      return Expanded(
        child: GlassContainer(
          padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 14)),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppColors.brandGreen,
                size: SizeConfig.iconSize(context, 30),
              ),
              SizedBox(width: SizeConfig.scaleWidth(context, 12)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      color: AppColors.brandGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: SizeConfig.fontSize(context, 26),
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: SizeConfig.fontSize(context, 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final shows = controller.activeShows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            countCard(
              'Today\'s Pickouts',
              controller.todayPickouts,
              Icons.today_outlined,
            ),
            SizedBox(width: SizeConfig.scaleWidth(context, 12)),
            countCard(
              'Tomorrow\'s Pickouts',
              controller.tomorrowPickouts,
              Icons.event_outlined,
            ),
          ],
        ),
        SizedBox(height: SizeConfig.scaleHeight(context, 12)),
        GlassContainer(
          padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.movie_filter_outlined,
                    color: AppColors.brandGreen,
                    size: SizeConfig.iconSize(context, 20),
                  ),
                  SizedBox(width: SizeConfig.scaleWidth(context, 8)),
                  Text(
                    'Active Shows',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: SizeConfig.fontSize(context, 15),
                    ),
                  ),
                  const Spacer(),
                  if (controller.homeSummaryLoading)
                    SizedBox(
                      width: SizeConfig.scaleWidth(context, 14),
                      height: SizeConfig.scaleHeight(context, 14),
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (controller.homeSummaryError != null)
                    Icon(
                      Icons.error_outline,
                      size: SizeConfig.iconSize(context, 16),
                      color: Theme.of(context).colorScheme.error,
                    ),
                ],
              ),
              SizedBox(height: SizeConfig.scaleHeight(context, 8)),
              if (shows.isEmpty)
                Text(
                  controller.homeSummaryError != null
                      ? 'Could not load active shows.'
                      : 'No active shows yet.',
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(context, 13),
                    color: muted,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: SizeConfig.scaleHeight(context, 260),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: shows.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    itemBuilder: (context, index) {
                      final show = shows[index];
                      final etaRaw = (show['eta'] ?? '').toString();
                      final etaDate = DateTime.tryParse(etaRaw);
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: SizeConfig.scaleHeight(context, 6),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                (show['client'] ?? '—').toString(),
                                style: TextStyle(
                                  fontSize: SizeConfig.fontSize(context, 13),
                                  color: muted,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                (show['show'] ?? '—').toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: SizeConfig.fontSize(context, 13),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: SizeConfig.scaleWidth(context, 90),
                              child: Text(
                                etaDate != null ? _fmt(etaDate) : '—',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: AppColors.brandGreen,
                                  fontWeight: FontWeight.w600,
                                  fontSize: SizeConfig.fontSize(context, 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _openConcernPage(String path, Map<String, String> queryParams) {
    final cleaned = <String, String>{};
    queryParams.forEach((key, value) {
      if (value.trim().isNotEmpty) {
        cleaned[key] = value;
      }
    });
    final uri = Uri(
      path: path,
      queryParameters: cleaned.isEmpty ? null : cleaned,
    );
    context.go(uri.toString());
  }
}
