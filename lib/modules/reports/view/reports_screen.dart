import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/size_config.dart';
import '../../../shared/widgets/dynamic_data_table.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/reports_controller.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _department = AppConstants.pipelineDepartments.first;
  List<String> _accessibleDepartments = AppConstants.pipelineDepartments;
  bool _exporting = false;
  bool _showCellBorders = true;
  String _clientNoFilter = '';
  String _showFilter = '';
  String _shotFilter = '';
  String _dateFilter = '';
  String _mandaysFilter = '';
  String _feedbackFilter = '';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthController>().currentUser;
      final query = GoRouterState.of(context).uri.queryParameters;
      final dashboardDept = query['department'];
      final departments = AppConstants.accessiblePipelineDepartments(
        role: user?.role,
        department: user?.department,
      );
      _accessibleDepartments = departments.isEmpty
          ? AppConstants.pipelineDepartments
          : departments;

      if (dashboardDept != null &&
          _accessibleDepartments.contains(dashboardDept)) {
        _department = dashboardDept;
      } else {
        _department = _accessibleDepartments.first;
      }
      _reload(context.read<ReportController>());
      if (mounted) setState(() {});
    });
  }

  void _reload(ReportController controller) {
    controller.loadReport(
      _department,
      startDate: _startDate != null ? _apiDate(_startDate!) : null,
      endDate: _endDate != null ? _apiDate(_endDate!) : null,
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    if (!mounted) return;
    final controller = context.read<ReportController>();
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = _startDate;
        }
      } else {
        _endDate = picked;
        if (_startDate != null && _endDate!.isBefore(_startDate!)) {
          _startDate = _endDate;
        }
      }
    });
    _reload(controller);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReportController>();
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: SizeConfig.scaleWidth(context, 980),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _filters(context, controller),
            SizedBox(height: SizeConfig.scaleHeight(context, 16)),
            if (controller.isLoading)
              const Expanded(child: LoadingWidget())
            else
              Expanded(
                child: ListView(
                  children: [
                    _summary(context, controller),
                    SizedBox(height: SizeConfig.scaleHeight(context, 16)),
                    if (controller.items.isNotEmpty) ...[
                      _mandaysChart(context, controller),
                      SizedBox(height: SizeConfig.scaleHeight(context, 16)),
                    ],
                    _table(context, controller),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filters(BuildContext context, ReportController controller) {
    return GlassContainer(
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 12)),
      child: Wrap(
        spacing: SizeConfig.scaleWidth(context, 12),
        runSpacing: SizeConfig.scaleHeight(context, 12),
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: SizeConfig.scaleWidth(context, 160),
            child: DropdownButtonFormField<String>(
              initialValue: _department,
              decoration: const InputDecoration(labelText: 'Department'),
              items: _accessibleDepartments
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _department = v);
                  _reload(controller);
                }
              },
            ),
          ),
          SizedBox(
            width: SizeConfig.scaleWidth(context, 180),
            height: SizeConfig.scaleHeight(context, 35),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    SizeConfig.scaleWidth(context, 8),
                  ),
                ),
              ),
              onPressed: () => _pickDate(isStart: true),
              icon: Icon(
                Icons.date_range_outlined,
                size: SizeConfig.iconSize(context, 18),
              ),
              label: Text(
                _startDate == null ? 'Start Date' : _fmt(_startDate!),
              ),
            ),
          ),
          SizedBox(
            width: SizeConfig.scaleWidth(context, 170),
            child: OutlinedButton.icon(
              onPressed: () => _pickDate(isStart: false),
              icon: Icon(
                Icons.event_outlined,
                size: SizeConfig.iconSize(context, 18),
              ),
              label: Text(_endDate == null ? 'End Date' : _fmt(_endDate!)),
            ),
          ),
          if (_startDate != null || _endDate != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                });
                _reload(controller);
              },
              child: const Text('Clear Range'),
            ),
          FilterChip(
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
        ],
      ),
    );
  }

  Widget _summary(BuildContext context, ReportController controller) {
    final totalMandays = controller.items.fold<double>(
      0,
      (sum, r) => sum + r.mandays,
    );
    final uniqueShows = controller.items.map((r) => r.show).toSet().length;
    return GlassContainer(
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Report Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: SizeConfig.fontSize(context, 16),
                  ),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? SizedBox(
                        width: SizeConfig.scaleWidth(context, 16),
                        height: SizeConfig.scaleHeight(context, 16),
                        child: CircularProgressIndicator(
                          strokeWidth: SizeConfig.scaleWidth(context, 2),
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        Icons.download,
                        size: SizeConfig.iconSize(context, 18),
                      ),
                label: const Text('Export XLSX'),
              ),
            ],
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 12)),
          Wrap(
            spacing: SizeConfig.scaleWidth(context, 24),
            runSpacing: SizeConfig.scaleHeight(context, 10),
            children: [
              _stat(context, 'Rows', '${controller.items.length}'),
              _stat(context, 'Shows', '$uniqueShows'),
              _stat(context, 'Mandays', totalMandays.toStringAsFixed(1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _table(BuildContext context, ReportController controller) {
    if (controller.items.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.analytics_outlined,
        title: 'No report data',
        description: 'No shots were delivered for the selected period.',
      );
    }

    bool contains(dynamic value, String query) {
      if (query.trim().isEmpty) return true;
      return (value ?? '').toString().toLowerCase().contains(
        query.trim().toLowerCase(),
      );
    }

    final rows = controller.items
        .map(
          (item) => <String, dynamic>{
            'clientNo': item.clientNo,
            'show': item.show,
            'shot': item.shotId,
            'date': item.date != null ? _fmt(item.date!) : '—',
            'mandays': item.mandays.toStringAsFixed(1),
            'feedback': item.clientFeedback ?? '—',
          },
        )
        .toList(growable: false);

    final filteredRows = rows
        .where((row) {
          return contains(row['clientNo'], _clientNoFilter) &&
              contains(row['show'], _showFilter) &&
              contains(row['shot'], _shotFilter) &&
              contains(row['date'], _dateFilter) &&
              contains(row['mandays'], _mandaysFilter) &&
              contains(row['feedback'], _feedbackFilter);
        })
        .toList(growable: false);

    return GlassContainer(
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: SizeConfig.scaleHeight(context, 10)),
          DynamicDataTable(
            showDesktopFilterButton: true,
            showCellBorders: _showCellBorders,
            fields: [
              DynamicTableField(
                key: 'clientNo',
                label: 'Client No',
                width: SizeConfig.scaleWidth(context, 120),
              ),
              DynamicTableField(
                key: 'show',
                label: 'Show',
                width: SizeConfig.scaleWidth(context, 160),
              ),
              DynamicTableField(
                key: 'shot',
                label: 'Shot',
                width: SizeConfig.scaleWidth(context, 120),
              ),
              DynamicTableField(
                key: 'date',
                label: 'Date',
                width: SizeConfig.scaleWidth(context, 120),
              ),
              DynamicTableField(
                key: 'mandays',
                label: 'Mandays',
                width: SizeConfig.scaleWidth(context, 110),
                numeric: true,
              ),
              DynamicTableField(
                key: 'feedback',
                label: 'Client Feedback',
                width: SizeConfig.scaleWidth(context, 220),
              ),
            ],
            rows: filteredRows,
            onFilterChanged: (fieldKey, value) {
              final filter = (value ?? '').toString();
              setState(() {
                switch (fieldKey) {
                  case 'clientNo':
                    _clientNoFilter = filter;
                  case 'show':
                    _showFilter = filter;
                  case 'shot':
                    _shotFilter = filter;
                  case 'date':
                    _dateFilter = filter;
                  case 'mandays':
                    _mandaysFilter = filter;
                  case 'feedback':
                    _feedbackFilter = filter;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    final controller = context.read<ReportController>();
    setState(() => _exporting = true);
    try {
      final (fileName, bytes) = await controller.exportReport(
        _department,
        startDate: _startDate != null ? _apiDate(_startDate!) : null,
        endDate: _endDate != null ? _apiDate(_endDate!) : null,
      );
      await _downloadXlsx(fileName, bytes);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Downloaded: $fileName')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _downloadXlsx(String fileName, Uint8List bytes) {
    final dot = fileName.lastIndexOf('.');
    final name = dot > 0 ? fileName.substring(0, dot) : fileName;
    return FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  Widget _mandaysChart(BuildContext context, ReportController controller) {
    // Aggregate mandays per day, bucketed by progress.
    final byDate = <DateTime, Map<String, double>>{};
    for (final item in controller.items) {
      final d = item.date;
      if (d == null) continue;
      final day = DateTime(d.year, d.month, d.day);
      final key = item.progress == 'Completed'
          ? 'Completed'
          : item.progress == 'In Progress'
          ? 'In Progress'
          : 'Remaining';
      final bucket = byDate.putIfAbsent(
        day,
        () => {'Completed': 0.0, 'In Progress': 0.0, 'Remaining': 0.0},
      );
      bucket[key] = (bucket[key] ?? 0.0) + item.mandays;
    }
    if (byDate.isEmpty) return const SizedBox.shrink();

    final dates = byDate.keys.toList()..sort();
    const completedColor = AppColors.brandGreen;
    final inProgressColor = Colors.amber.shade700;
    final remainingColor = Colors.blueGrey.shade400;

    double maxY = 0;
    for (final bucket in byDate.values) {
      final total =
          (bucket['Completed'] ?? 0) +
          (bucket['In Progress'] ?? 0) +
          (bucket['Remaining'] ?? 0);
      if (total > maxY) maxY = total;
    }
    final maxYCeil = maxY <= 0 ? 1.0 : (maxY + 1).ceilToDouble();
    final labelStep = (dates.length / 8).ceil().clamp(1, dates.length);

    Widget legendDot(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: SizeConfig.fontSize(context, 12)),
          ),
        ],
      );
    }

    return GlassContainer(
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart,
                color: AppColors.brandGreen,
                size: SizeConfig.iconSize(context, 18),
              ),
              SizedBox(width: SizeConfig.scaleWidth(context, 8)),
              Text(
                'Mandays — Completed / In Progress / Remaining',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: SizeConfig.fontSize(context, 14),
                ),
              ),
            ],
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 12)),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              legendDot(completedColor, 'Completed'),
              legendDot(inProgressColor, 'In Progress'),
              legendDot(remainingColor, 'Remaining'),
            ],
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 12)),
          SizedBox(
            height: SizeConfig.scaleHeight(context, 260),
            width: double.infinity,
            child: BarChart(
              BarChartData(
                maxY: maxYCeil,
                alignment: BarChartAlignment.spaceAround,
                barGroups: [
                  for (var i = 0; i < dates.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: byDate[dates[i]]!['Completed']!,
                          color: completedColor,
                          width: 12,
                        ),
                        BarChartRodData(
                          toY: byDate[dates[i]]!['In Progress']!,
                          color: inProgressColor,
                          width: 12,
                        ),
                        BarChartRodData(
                          toY: byDate[dates[i]]!['Remaining']!,
                          color: remainingColor,
                          width: 12,
                        ),
                      ],
                    ),
                ],
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: SizeConfig.fontSize(context, 11),
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: labelStep.toDouble(),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 ||
                            idx >= dates.length ||
                            idx % labelStep != 0) {
                          return const SizedBox.shrink();
                        }
                        final d = dates[idx];
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(context, 11),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final d = dates[group.x];
                      const labels = ['Completed', 'In Progress', 'Remaining'];
                      return BarTooltipItem(
                        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}\n${labels[rodIndex]}: ${rod.toY.toStringAsFixed(1)} md',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppColors.brandGreen,
            fontWeight: FontWeight.bold,
            fontSize: SizeConfig.fontSize(context, 20),
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: SizeConfig.fontSize(context, 12)),
        ),
      ],
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _apiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
