import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
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
        constraints: const BoxConstraints(maxWidth: 980),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _filters(controller),
            const SizedBox(height: 16),
            if (controller.isLoading)
              const Expanded(child: LoadingWidget())
            else
              Expanded(
                child: ListView(
                  children: [
                    _summary(controller),
                    const SizedBox(height: 16),
                    _table(controller),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filters(ReportController controller) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 160,
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
            width: 180,
            height: 35,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _pickDate(isStart: true),
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: Text(
                _startDate == null ? 'Start Date' : _fmt(_startDate!),
              ),
            ),
          ),
          SizedBox(
            width: 170,
            child: OutlinedButton.icon(
              onPressed: () => _pickDate(isStart: false),
              icon: const Icon(Icons.event_outlined, size: 18),
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
        ],
      ),
    );
  }

  Widget _summary(ReportController controller) {
    final totalMandays = controller.items.fold<double>(
      0,
      (sum, r) => sum + r.mandays,
    );
    final uniqueShows = controller.items.map((r) => r.show).toSet().length;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Report Summary',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download, size: 18),
                label: const Text('Export XLSX'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _stat('Rows', '${controller.items.length}'),
              _stat('Shows', '$uniqueShows'),
              _stat('Mandays', totalMandays.toStringAsFixed(1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _table(ReportController controller) {
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
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          DynamicDataTable(
            fields: const [
              DynamicTableField(
                key: 'clientNo',
                label: 'Client No',
                width: 120,
              ),
              DynamicTableField(key: 'show', label: 'Show', width: 160),
              DynamicTableField(key: 'shot', label: 'Shot', width: 120),
              DynamicTableField(key: 'date', label: 'Date', width: 120),
              DynamicTableField(
                key: 'mandays',
                label: 'Mandays',
                width: 110,
                numeric: true,
              ),
              DynamicTableField(
                key: 'feedback',
                label: 'Client Feedback',
                width: 220,
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

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.brandGreen,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _apiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
