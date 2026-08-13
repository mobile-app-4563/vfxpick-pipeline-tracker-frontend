import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/dynamic_data_table.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/review_controller.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  String _department = AppConstants.pipelineDepartments.first;
  List<String> _accessibleDepartments = AppConstants.pipelineDepartments;
  bool _exportingDept = false;
  bool _exportingIndividual = false;
  bool _expandDepartment = false;
  bool _expandIndividual = false;
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
      _reload();
      if (mounted) setState(() {});
    });
  }

  void _reload() {
    final controller = context.read<ReviewController>();
    controller.loadDepartmentReview(
      _department,
      startDate: _startDate != null ? _apiDate(_startDate!) : null,
      endDate: _endDate != null ? _apiDate(_endDate!) : null,
    );
    controller.loadIndividualReview(
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
    _reload();
  }

  Future<void> _exportDept() async {
    final controller = context.read<ReviewController>();
    setState(() => _exportingDept = true);
    try {
      final (fileName, bytes) = await controller.exportDepartmentReview(
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
      if (mounted) setState(() => _exportingDept = false);
    }
  }

  Future<void> _exportIndividual() async {
    final controller = context.read<ReviewController>();
    setState(() => _exportingIndividual = true);
    try {
      final (fileName, bytes) = await controller.exportIndividualReview(
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
      if (mounted) setState(() => _exportingIndividual = false);
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

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReviewController>();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _filters(context, controller),
            const SizedBox(height: 16),
            if (controller.isLoading)
              const Expanded(child: LoadingWidget())
            else
              Expanded(
                child: ListView(
                  children: [
                    _deptReview(controller),
                    const SizedBox(height: 16),
                    _individualReview(controller),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filters(BuildContext context, ReviewController controller) {
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
                  _reload();
                }
              },
            ),
          ),
          SizedBox(
            width: 180,
            height: 40,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              iconAlignment: IconAlignment.start,
              onPressed: () => _pickDate(isStart: true),
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: Text(
                _startDate == null ? 'Start Date' : _fmt(_startDate!),
              ),
            ),
          ),
          SizedBox(
            width: 170,
            height: 40,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              iconAlignment: IconAlignment.start,
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
                _reload();
              },
              child: const Text('Clear Range'),
            ),
        ],
      ),
    );
  }

  Widget _deptReview(ReviewController controller) {
    final r = controller.departmentReview;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => _expandDepartment = !_expandDepartment);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      const Text(
                        'Department Review',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _expandDepartment ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: const Icon(Icons.keyboard_arrow_down, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
              _exportButton(
                busy: _exportingDept,
                onPressed: r == null ? null : _exportDept,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (r == null)
            const Text('No data')
          else ...[
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _stat('Shows', '${r.totalShows}'),
                _stat('Shots', '${r.totalShots}'),
                _stat('Mandays', r.totalMandays.toStringAsFixed(1)),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: _expandDepartment
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const Text(
                          'Mandays Details',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        DynamicDataTable(
                          fields: const [
                            DynamicTableField(
                              key: 'clientNo',
                              label: 'Client No',
                              width: 110,
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'show',
                              label: 'Show',
                              width: 160,
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'shot',
                              label: 'Shot',
                              width: 130,
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'date',
                              label: 'Date',
                              width: 110,
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'mandays',
                              label: 'Mandays',
                              width: 100,
                              numeric: true,
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'artist',
                              label: 'Artist',
                              width: 120,
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'clientFeedback',
                              label: 'Client Feedback',
                              width: 220,
                              filterRequired: false,
                            ),
                          ],
                          rows: r.detailRows
                              .map(
                                (e) => <String, dynamic>{
                                  'clientNo': e.clientNo,
                                  'show': e.show,
                                  'shot': e.shot,
                                  'date': e.date != null ? _fmt(e.date!) : '—',
                                  'mandays': e.mandays.toStringAsFixed(1),
                                  'artist': e.artist,
                                  'clientFeedback': e.clientFeedback,
                                },
                              )
                              .toList(growable: false),
                          empty: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('No detail rows for selected range.'),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _individualReview(ReviewController controller) {
    final r = controller.individualReview;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => _expandIndividual = !_expandIndividual);
                  },
                  child: Row(
                    children: [
                      const Text(
                        'My Review',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _expandIndividual ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: const Icon(Icons.keyboard_arrow_down, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
              _exportButton(
                busy: _exportingIndividual,
                onPressed: r == null ? null : _exportIndividual,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (r == null)
            const Text('No data')
          else ...[
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _stat('Name', r.name),
                _stat('Shots worked', '${r.shotsWorked}'),
                _stat('Mandays', r.mandaysDelivered.toStringAsFixed(1)),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: _expandIndividual
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const Text(
                          'Mandays Details',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        DynamicDataTable(
                          fields: const [
                            DynamicTableField(
                              key: 'clientNo',
                              label: 'Client No',
                              width: 110,
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'show',
                              label: 'Show',
                              width: 160,
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'shot',
                              label: 'Shot',
                              width: 130,
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'date',
                              label: 'Date',
                              width: 110,
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'mandays',
                              label: 'Mandays',
                              width: 100,
                              numeric: true,
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'artistStatus',
                              label: 'Artist Status',
                              width: 130,
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'clientFeedback',
                              label: 'Client Feedback',
                              width: 220,
                              filterRequired: false,
                            ),
                          ],
                          rows: r.detailRows
                              .map(
                                (e) => <String, dynamic>{
                                  'clientNo': e.clientNo,
                                  'show': e.show,
                                  'shot': e.shot,
                                  'date': e.date != null ? _fmt(e.date!) : '—',
                                  'mandays': e.mandays.toStringAsFixed(1),
                                  'artistStatus': e.artistStatus,
                                  'clientFeedback': e.clientFeedback,
                                },
                              )
                              .toList(growable: false),
                          empty: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('No detail rows for selected range.'),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _exportButton({required bool busy, VoidCallback? onPressed}) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandGreen,
        foregroundColor: Colors.white,
      ),
      onPressed: busy ? null : onPressed,
      icon: busy
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
