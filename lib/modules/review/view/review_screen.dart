import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/size_config.dart';
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
  bool _showCellBorders = true;
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
        constraints: BoxConstraints(
          maxWidth: SizeConfig.scaleWidth(context, 720),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _filters(context, controller),
            SizedBox(height: SizeConfig.scaleHeight(context, 16)),
            if (controller.isLoading)
              const Expanded(child: LoadingWidget())
            else
              Expanded(
                child: ListView(
                  children: [
                    _deptReview(context, controller),
                    SizedBox(height: SizeConfig.scaleHeight(context, 16)),
                    _individualReview(context, controller),
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
                  _reload();
                }
              },
            ),
          ),
          SizedBox(
            width: SizeConfig.scaleWidth(context, 180),
            height: SizeConfig.scaleHeight(context, 40),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    SizeConfig.scaleWidth(context, 8),
                  ),
                ),
              ),
              iconAlignment: IconAlignment.start,
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
            height: SizeConfig.scaleHeight(context, 40),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    SizeConfig.scaleWidth(context, 8),
                  ),
                ),
              ),
              iconAlignment: IconAlignment.start,
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
                _reload();
              },
              child: const Text('Clear Range'),
            ),
        ],
      ),
    );
  }

  Widget _deptReview(BuildContext context, ReviewController controller) {
    final r = controller.departmentReview;
    return GlassContainer(
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 16)),
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
                  borderRadius: BorderRadius.circular(
                    SizeConfig.scaleWidth(context, 8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Department Review',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: SizeConfig.fontSize(context, 16),
                        ),
                      ),
                      SizedBox(width: SizeConfig.scaleWidth(context, 8)),
                      AnimatedRotation(
                        turns: _expandDepartment ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: SizeConfig.iconSize(context, 20),
                        ),
                      ),
                    ],
                  ),
                ),
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
              _exportButton(
                context,
                busy: _exportingDept,
                onPressed: r == null ? null : _exportDept,
              ),
            ],
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 12)),
          if (r == null)
            const Text('No data')
          else ...[
            Wrap(
              spacing: SizeConfig.scaleWidth(context, 24),
              runSpacing: SizeConfig.scaleHeight(context, 12),
              children: [
                _stat(context, 'Shows', '${r.totalShows}'),
                _stat(context, 'Shots', '${r.totalShots}'),
                _stat(context, 'Mandays', r.totalMandays.toStringAsFixed(1)),
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
                        SizedBox(height: SizeConfig.scaleHeight(context, 12)),
                        const Text(
                          'Mandays Details',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                        DynamicDataTable(
                          showCellBorders: _showCellBorders,
                          fields: [
                            DynamicTableField(
                              key: 'clientNo',
                              label: 'Client No',
                              width: SizeConfig.scaleWidth(context, 110),
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'show',
                              label: 'Show',
                              width: SizeConfig.scaleWidth(context, 160),
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'shot',
                              label: 'Shot',
                              width: SizeConfig.scaleWidth(context, 130),
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'date',
                              label: 'Date',
                              width: SizeConfig.scaleWidth(context, 110),
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'mandays',
                              label: 'Mandays',
                              width: SizeConfig.scaleWidth(context, 100),
                              numeric: true,
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'artist',
                              label: 'Artist',
                              width: SizeConfig.scaleWidth(context, 120),
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'clientFeedback',
                              label: 'Client Feedback',
                              width: SizeConfig.scaleWidth(context, 220),
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
                          empty: Padding(
                            padding: EdgeInsets.all(
                              SizeConfig.scaleWidth(context, 12),
                            ),
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

  Widget _individualReview(BuildContext context, ReviewController controller) {
    final r = controller.individualReview;
    return GlassContainer(
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 16)),
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
                      Text(
                        'My Review',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: SizeConfig.fontSize(context, 16),
                        ),
                      ),
                      SizedBox(width: SizeConfig.scaleWidth(context, 8)),
                      AnimatedRotation(
                        turns: _expandIndividual ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: SizeConfig.iconSize(context, 20),
                        ),
                      ),
                    ],
                  ),
                ),
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
              _exportButton(
                context,
                busy: _exportingIndividual,
                onPressed: r == null ? null : _exportIndividual,
              ),
            ],
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 12)),
          if (r == null)
            const Text('No data')
          else ...[
            Wrap(
              spacing: SizeConfig.scaleWidth(context, 24),
              runSpacing: SizeConfig.scaleHeight(context, 12),
              children: [
                _stat(context, 'Name', r.name),
                _stat(context, 'Shots worked', '${r.shotsWorked}'),
                _stat(
                  context,
                  'Mandays',
                  r.mandaysDelivered.toStringAsFixed(1),
                ),
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
                        SizedBox(height: SizeConfig.scaleHeight(context, 12)),
                        const Text(
                          'Mandays Details',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                        DynamicDataTable(
                          showCellBorders: _showCellBorders,
                          fields: [
                            DynamicTableField(
                              key: 'clientNo',
                              label: 'Client No',
                              width: SizeConfig.scaleWidth(context, 110),
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'show',
                              label: 'Show',
                              width: SizeConfig.scaleWidth(context, 160),
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'shot',
                              label: 'Shot',
                              width: SizeConfig.scaleWidth(context, 130),
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'date',
                              label: 'Date',
                              width: SizeConfig.scaleWidth(context, 110),
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'mandays',
                              label: 'Mandays',
                              width: SizeConfig.scaleWidth(context, 100),
                              numeric: true,
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'artistStatus',
                              label: 'Artist Status',
                              width: SizeConfig.scaleWidth(context, 130),
                              filterRequired: false,
                            ),
                            DynamicTableField(
                              key: 'clientFeedback',
                              label: 'Client Feedback',
                              width: SizeConfig.scaleWidth(context, 220),
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
                          empty: Padding(
                            padding: EdgeInsets.all(
                              SizeConfig.scaleWidth(context, 12),
                            ),
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

  Widget _exportButton(
    BuildContext context, {
    required bool busy,
    VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandGreen,
        foregroundColor: Colors.white,
      ),
      onPressed: busy ? null : onPressed,
      icon: busy
          ? SizedBox(
              width: SizeConfig.scaleWidth(context, 16),
              height: SizeConfig.scaleHeight(context, 16),
              child: CircularProgressIndicator(
                strokeWidth: SizeConfig.scaleWidth(context, 2),
                color: Colors.white,
              ),
            )
          : Icon(Icons.download, size: SizeConfig.iconSize(context, 18)),
      label: const Text('Export XLSX'),
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
