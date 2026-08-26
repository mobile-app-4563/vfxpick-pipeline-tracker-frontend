import 'package:flutter/foundation.dart';

import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vfxpick_pipeline/shared/widgets/custom_text_field.dart';
import 'package:vfxpick_pipeline/shared/widgets/dynamic_data_table.dart';
import 'package:vfxpick_pipeline/shared/widgets/filter_icon.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/excel_date_utils.dart';
import '../../../core/utils/size_config.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/models/shot_model.dart';
import '../../../core/services/team_service.dart';
import '../../../shared/widgets/custom_dropdown.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/shot_chat_dialog.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/tasks_controller.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final List<Map<String, String>> _importDraftRows = [];
  bool _isArtist = false;
  bool _isBroadAccess = false;
  bool _isAdmin = false;
  List<String> _accessibleDepartments = AppConstants.pipelineDepartments;
  bool _isExporting = false;
  bool _showCellBorders = true;
  int _previewPage = 0;
  final GlobalKey<_DepartmentViewState> _departmentViewKey =
      GlobalKey<_DepartmentViewState>();

  // ── Page-change feedback: brief "Parsing…" overlay while the preview grid
  //    switches pages, so heavy table rebuilds are never silent. ──
  bool _isPreviewGridChanging = false;

  // ── Import-preview cache: projected preview Maps are rebuilt ONLY when the
  //    draft rows change — never on unrelated builds (large pastes used to
  //    re-materialize thousands of Maps on the UI thread every setState). ──
  List<Map<String, dynamic>>? _cachedImportPreviewRows;
  int _cachedImportPreviewLength = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = context.read<AuthController>().currentUser;
      final query = GoRouterState.of(context).uri.queryParameters;
      final dashboardDept = query['department'];
      _isArtist = user?.role == AppConstants.roleArtist;
      _isBroadAccess = AppConstants.broadAccessRoles.contains(user?.role);
      _isAdmin = user?.role == AppConstants.roleAdmin;
      final departments = AppConstants.accessiblePipelineDepartments(
        role: user?.role,
        department: user?.department,
      );
      _accessibleDepartments = departments.isEmpty
          ? AppConstants.pipelineDepartments
          : departments;
      final controller = context.read<TaskController>();
      await controller.init(departments: _accessibleDepartments);
      if (_isArtist) {
        await controller.loadArtistShots();
      } else {
        final roleDept = _accessibleDepartments.contains(user?.department)
            ? user?.department
            : null;
        final dept = _isBroadAccess
            ? (dashboardDept != null &&
                      _accessibleDepartments.contains(dashboardDept)
                  ? dashboardDept
                  : roleDept)
            : roleDept;
        if (dept != null) {
          controller.selectDepartment(dept);
        }
        await controller.loadShots();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TaskController>();
    if (_isArtist) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _actionBar(controller),
          SizedBox(height: SizeConfig.scaleHeight(context, 12)),
          Expanded(
            child: _ArtistPortal(
              controller: controller,
              showCellBorders: _showCellBorders,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _importActions(context, controller),
        if (_importDraftRows.isNotEmpty) ...[
          SizedBox(height: SizeConfig.scaleHeight(context, 12)),
          _importPreviewTable(),
        ],
        SizedBox(height: SizeConfig.scaleHeight(context, 12)),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => controller.loadDepartmentShots(
              department: controller.selectedDepartment,
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                bottom: SizeConfig.scaleHeight(context, 24),
              ),
              children: [
                _DepartmentView(
                  key: _departmentViewKey,
                  controller: controller,
                  showCellBorders: _showCellBorders,
                  onFiltersChanged: () => setState(() {}),
                ),
                if (_isAdmin) ...[
                  SizedBox(height: SizeConfig.scaleHeight(context, 24)),
                  _ProductionView(
                    controller: controller,
                    showCellBorders: _showCellBorders,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionBar(TaskController controller) {
    return GlassContainer(
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 12)),
      child: Wrap(
        spacing: SizeConfig.scaleWidth(context, 12),
        runSpacing: SizeConfig.scaleHeight(context, 12),
        children: [
          ElevatedButton.icon(
            onPressed: _isExporting ? null : () => _exportAsExcel(controller),
            icon: _isExporting
                ? SizedBox(
                    width: SizeConfig.scaleWidth(context, 14),
                    height: SizeConfig.scaleHeight(context, 14),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_outlined),
            label: const Text('Export Excel'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              fixedSize: Size(
                SizeConfig.scaleWidth(context, 130),
                MediaQuery.of(context).size.height * 45 / 768,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  SizeConfig.scaleWidth(context, 0),
                ),
              ),
            ),
            onPressed: () =>
                setState(() => _showCellBorders = !_showCellBorders),
            icon: SizedBox(),
            label: const Text('Cell Borders'),
          ),
        ],
      ),
    );
  }

  Widget _importActions(BuildContext context, TaskController controller) {
    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: SizeConfig.scaleWidth(context, 12),
      runSpacing: SizeConfig.scaleHeight(context, 12),
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandGreen,
            foregroundColor: Colors.white,
            fixedSize: Size(
              SizeConfig.scaleWidth(context, 160),
              MediaQuery.of(context).size.height * 40 / 768,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                SizeConfig.scaleWidth(context, 2),
              ),
            ),
          ),
          onPressed: _isExporting ? null : () => _exportAsExcel(controller),
          icon: _isExporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download_outlined),
          label: const Text('Export Excel'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            fixedSize: Size(
              SizeConfig.scaleWidth(context, 130),
              MediaQuery.of(context).size.height * 40 / 768,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                SizeConfig.scaleWidth(context, 2),
              ),
            ),
          ),
          onPressed: () =>
              _departmentViewKey.currentState?.openFilterDialog(context),
          icon: Icon(
            Icons.filter_alt_outlined,
            size: SizeConfig.iconSize(context, 18),
            color: _departmentViewKey.currentState?.hasActiveFilters == true
                ? AppColors.brandGreen
                : null,
          ),
          label: const Text('Filter'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            fixedSize: Size(
              SizeConfig.scaleWidth(context, 150),
              MediaQuery.of(context).size.height * 40 / 768,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                SizeConfig.scaleWidth(context, 2),
              ),
            ),
            foregroundColor: _showCellBorders ? AppColors.brandGreen : null,
            side: BorderSide(
              color: _showCellBorders
                  ? AppColors.brandGreen
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          onPressed: () => setState(() => _showCellBorders = !_showCellBorders),
          icon: Icon(
            Icons.border_all,
            size: SizeConfig.iconSize(context, 18),
            color: _showCellBorders ? AppColors.brandGreen : null,
          ),
          label: Text(
            'Cell Borders',
            style: TextStyle(
              color: !_showCellBorders ? AppColors.brandGreen : Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportAsExcel(TaskController controller) async {
    final shots = _isArtist
        ? controller.artistShots
        : controller.departmentShots;
    if (shots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rows available to export.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final excel = Excel.createExcel();
      final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
      final sheet = excel[sheetName];

      sheet.appendRow([
        TextCellValue('shot_id'),
        TextCellValue('show'),
        TextCellValue('client'),
        TextCellValue('frame_in'),
        TextCellValue('frame_out'),
        TextCellValue('client_status'),
        TextCellValue('artist_status'),
        TextCellValue('supervisor_status'),
        TextCellValue('artist_eta'),
        TextCellValue('client_eta'),
      ]);

      for (final shot in shots) {
        sheet.appendRow([
          TextCellValue(shot.shotCode),
          TextCellValue(shot.showName ?? ''),
          TextCellValue(shot.clientName ?? shot.clientId ?? ''),
          IntCellValue(shot.frameIn),
          IntCellValue(shot.frameOut),
          TextCellValue(shot.status),
          TextCellValue(shot.artistStatus),
          TextCellValue(shot.supervisorStatus ?? ''),
          TextCellValue(formatDateLikeExcelD(shot.artistEta)),
          TextCellValue(formatDateLikeExcelD(shot.clientEta)),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Unable to generate Excel file');
      }

      final fileName =
          'tasks_${DateTime.now().toIso8601String().replaceAll(':', '-')}.xlsx';
      await FileSaver.instance.saveFile(
        name: fileName.replaceAll('.xlsx', ''),
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Downloaded: $fileName')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  /// Builds the display Maps for the import preview. Cached and invalidated
  /// only when `_importDraftRows` changes, so unrelated setState calls never
  /// re-project thousands of rows on the UI thread.
  List<Map<String, dynamic>> _buildImportPreviewRows() {
    if (_cachedImportPreviewLength == _importDraftRows.length &&
        _cachedImportPreviewRows != null) {
      return _cachedImportPreviewRows!;
    }
    final rows = List<Map<String, dynamic>>.generate(_importDraftRows.length, (
      index,
    ) {
      final row = _importDraftRows[index];
      return {
        'shot': (row['shot_id'] ?? row['shot_code'] ?? row['shot'] ?? '')
            .toString(),
        'supervisorStatus': (row['supervisor_status'] ?? '').toString(),
        'artistStatus': (row['artist_status'] ?? '').toString(),
      };
    });
    _cachedImportPreviewLength = _importDraftRows.length;
    _cachedImportPreviewRows = rows;
    return rows;
  }

  /// Flips the import-preview page with a one-frame "Parsing…" overlay so the
  /// table rebuild is visible feedback instead of a silent freeze. The heavy
  /// work (slicing/rebuild) runs BETWEEN frames while the spinner is on
  /// screen. Deferred flips keep it safe even when the table's internal page
  /// clamp fires mid-build.
  void _changePreviewPage(int page) {
    if (_isPreviewGridChanging || page == _previewPage) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      // Called mid-build (DynamicDataTable internal page clamp) — defer.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _changePreviewPage(page);
      });
      return;
    }
    setState(() => _isPreviewGridChanging = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _previewPage = page);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _isPreviewGridChanging = false);
      });
    });
  }

  /// Overlays a "Parsing…" spinner on a grid while its page is switching.
  Widget _withGridParsingOverlay({
    required bool isLoading,
    required Widget child,
  }) {
    if (!isLoading) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.18),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  SizedBox(height: 10),
                  Text('Parsing…'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _importPreviewTable() {
    final previewRows = _buildImportPreviewRows();

    return GlassContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Imported Preview (${_importDraftRows.length} rows)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          _tasksPaginationBar(
            context,
            _previewPage,
            _importDraftRows.length,
            _changePreviewPage,
          ),
          _withGridParsingOverlay(
            isLoading: _isPreviewGridChanging,
            child: DynamicDataTable(
              currentPage: _previewPage,
              onPageChanged: _changePreviewPage,
              rowsPerPage: _tasksRowsPerPage,
              showCellBorders: true,
              // headingRowHeight: MediaQuery.of(context).size.height * 40 / 768,
              dataRowMinHeight: MediaQuery.of(context).size.height * 40 / 768,
              dataRowMaxHeight: MediaQuery.of(context).size.height * 52 / 768,
              fields: [
                DynamicTableField(
                  key: 'shot',
                  label: 'Shot',
                  width: SizeConfig.scaleWidth(context, 160),
                ),
                DynamicTableField(
                  key: 'supervisorStatus',
                  label: 'Supervisor Status',
                  width: SizeConfig.scaleWidth(context, 180),
                ),
                DynamicTableField(
                  key: 'artistStatus',
                  label: 'Artist Status',
                  width: SizeConfig.scaleWidth(context, 160),
                ),
              ],
              rows: previewRows,
            ),
          ),
        ],
      ),
    );
  }
}

// Only 10 rows per page — matches the Production & Projects grids. Every
// table slices rows internally, so each page renders just 10 rows.
const int _tasksRowsPerPage = 10;

int _tasksTotalPages(int totalRows) =>
    _tasksRowsPerPage > 0 ? (totalRows / _tasksRowsPerPage).ceil() : 1;

Widget _tasksPaginationBar(
  BuildContext context,
  int currentPage,
  int totalRows,
  ValueChanged<int> onPageChanged,
) {
  final totalPages = _tasksTotalPages(totalRows);
  if (totalPages <= 1) return const SizedBox.shrink();
  final start = currentPage * _tasksRowsPerPage + 1;
  final end = (start + _tasksRowsPerPage - 1).clamp(0, totalRows);
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$start–$end of $totalRows',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 20),
          onPressed: currentPage > 0
              ? () => onPageChanged(currentPage - 1)
              : null,
          tooltip: 'Previous page',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 20),
          onPressed: currentPage < totalPages - 1
              ? () => onPageChanged(currentPage + 1)
              : null,
          tooltip: 'Next page',
          visualDensity: VisualDensity.compact,
        ),
      ],
    ),
  );
}

class _ArtistPortal extends StatefulWidget {
  final TaskController controller;
  final bool showCellBorders;
  const _ArtistPortal({
    required this.controller,
    required this.showCellBorders,
  });

  @override
  State<_ArtistPortal> createState() => _ArtistPortalState();
}

class _ArtistPortalState extends State<_ArtistPortal> {
  int _artistPage = 0;
  String _shotIdFilter = '';
  String _showFilter = '';
  String _framesFilter = '';
  String _clientStatusFilter = '';
  String _artistStatusFilter = '';
  String _supervisorStatusFilter = '';
  String _artistEtaFilter = '';
  String _clientEtaFilter = '';

  bool _contains(dynamic value, String query) {
    if (query.trim().isEmpty) return true;
    return (value ?? '').toString().toLowerCase().contains(
      query.trim().toLowerCase(),
    );
  }

  /// Frame ranges are displayed as "100 - 200"; match regardless of whether
  /// the user types "100-200" or "100 - 200" (whitespace is ignored).
  bool _matchesFrames(int frameIn, int frameOut, String query) {
    if (query.trim().isEmpty) return true;
    final q = query.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    return '$frameIn-$frameOut'.contains(q);
  }

  List<FilterOption> _buildOptions(List<String> values, String selected) {
    return values
        .map(
          (value) => FilterOption(
            label: value,
            value: value,
            isSelected: value == selected,
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller.isLoading && controller.artistShots.isEmpty) {
      return const LoadingWidget(message: 'Loading your tasks...');
    }

    if (controller.artistShots.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.task_alt_outlined,
        title: 'No tasks assigned',
        description: 'Shots assigned to you will appear here.',
      );
    }

    final filteredShots = controller.artistShots
        .where((shot) {
          return _contains(shot.shotCode, _shotIdFilter) &&
              _contains(shot.showName ?? '—', _showFilter) &&
              _matchesFrames(shot.frameIn, shot.frameOut, _framesFilter) &&
              _contains(shot.status, _clientStatusFilter) &&
              _contains(shot.artistStatus, _artistStatusFilter) &&
              _contains(
                shot.supervisorStatus ?? '—',
                _supervisorStatusFilter,
              ) &&
              _contains(
                formatDateLikeExcelD(shot.artistEta),
                _artistEtaFilter,
              ) &&
              _contains(formatDateLikeExcelD(shot.clientEta), _clientEtaFilter);
        })
        .toList(growable: false);

    final rows = List<Map<String, dynamic>>.generate(filteredShots.length, (
      index,
    ) {
      final shot = filteredShots[index];
      return {
        'sno': index + 1,
        'shotId': shot.shotCode,
        'show': shot.showName ?? '—',
        'frames': '${shot.frameIn} - ${shot.frameOut}',
        'clientStatus': shot.status,
        'artistStatus': shot.artistStatus,
        'supervisorStatus': shot.supervisorStatus ?? '—',
        'artistEta': formatDateLikeExcelD(shot.artistEta),
        'clientEta': formatDateLikeExcelD(shot.clientEta),
        'shot': shot,
      };
    });

    return RefreshIndicator(
      onRefresh: controller.loadArtistShots,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          GlassContainer(
            padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 10)),
            borderRadius: SizeConfig.scaleWidth(context, 2),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final searchWidth = constraints.maxWidth < 320
                    ? constraints.maxWidth
                    : SizeConfig.scaleWidth(context, 260);
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: SizeConfig.scaleWidth(context, 10),
                  runSpacing: SizeConfig.scaleHeight(context, 10),
                  children: [
                    SizedBox(
                      width: searchWidth,
                      child: CustomTextField(
                        onChanged: (v) => setState(() {
                          _shotIdFilter = v;
                          _showFilter = v;
                        }),
                        labelText: 'Search shot / show',
                        suffixIcon: Icons.search,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _artistPage = 0;
                          _shotIdFilter = '';
                          _showFilter = '';
                          _framesFilter = '';
                          _clientStatusFilter = '';
                          _artistStatusFilter = '';
                          _supervisorStatusFilter = '';
                          _artistEtaFilter = '';
                          _clientEtaFilter = '';
                        });
                      },
                      child: const Text('Clear Filters'),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 8)),
          GlassContainer(
            padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 0)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tasksPaginationBar(
                  context,
                  _artistPage,
                  rows.length,
                  (page) => setState(() => _artistPage = page),
                ),
                DynamicDataTable(
                  currentPage: _artistPage,
                  onPageChanged: (page) => setState(() => _artistPage = page),
                  rowsPerPage: _tasksRowsPerPage,
                  showCellBorders: widget.showCellBorders,
                  headingRowHeight:
                      MediaQuery.of(context).size.height * 42 / 768,
                  dataRowMinHeight:
                      MediaQuery.of(context).size.height * 44 / 768,
                  dataRowMaxHeight:
                      MediaQuery.of(context).size.height * 56 / 768,
                  fields: [
                    DynamicTableField(
                      key: 'sno',
                      label: 'S.No',
                      width: SizeConfig.scaleWidth(context, 60),
                      numeric: true,
                      filterRequired: false,
                    ),
                    DynamicTableField(
                      key: 'shotId',
                      label: 'Shot ID',
                      width: SizeConfig.scaleWidth(context, 130),
                    ),
                    DynamicTableField(
                      key: 'show',
                      label: 'Show',
                      width: SizeConfig.scaleWidth(context, 140),
                    ),
                    DynamicTableField(
                      key: 'frames',
                      label: 'Frames',
                      width: SizeConfig.scaleWidth(context, 120),
                    ),
                    DynamicTableField(
                      key: 'clientStatus',
                      label: 'Client Status',
                      width: SizeConfig.scaleWidth(context, 140),
                      filterOptions: _buildOptions(
                        AppConstants.shotStatuses,
                        _clientStatusFilter,
                      ),
                    ),
                    DynamicTableField(
                      key: 'artistStatus',
                      label: 'Artist Status',
                      width: 180,
                      filterOptions: _buildOptions(
                        AppConstants.artistStatuses,
                        _artistStatusFilter,
                      ),
                      builder: (context, value, row, rowIndex) {
                        final shot = row['shot'] as ShotModel;
                        return SizedBox(
                          width: SizeConfig.scaleWidth(context, 170),
                          child: CustomDropdown<String>(
                            compact: true,
                            labelText: 'Artist Status',
                            value:
                                AppConstants.artistStatuses.contains(
                                  shot.artistStatus,
                                )
                                ? shot.artistStatus
                                : null,
                            items: AppConstants.artistStatuses,
                            onChanged: (v) {
                              if (v != null) {
                                controller.updateArtistStatus(shot.shotId, v);
                              }
                            },
                            itemToString: (v) => v,
                          ),
                        );
                      },
                    ),
                    DynamicTableField(
                      key: 'supervisorStatus',
                      label: 'Supervisor Status',
                      width: SizeConfig.scaleWidth(context, 160),
                      filterOptions: _buildOptions(
                        AppConstants.supervisorStatuses,
                        _supervisorStatusFilter,
                      ),
                    ),
                    DynamicTableField(
                      key: 'artistEta',
                      label: 'Artist ETA',
                      width: SizeConfig.scaleWidth(context, 130),
                    ),
                    DynamicTableField(
                      key: 'clientEta',
                      label: 'Client ETA',
                      width: SizeConfig.scaleWidth(context, 130),
                    ),
                    DynamicTableField(
                      key: 'actions',
                      label: 'Actions',
                      width: SizeConfig.scaleWidth(context, 90),
                      filterRequired: false,
                      builder: (context, value, row, rowIndex) {
                        final shot = row['shot'] as ShotModel;
                        return IconButton(
                          tooltip: 'Chat',
                          icon: Icon(
                            Icons.chat_bubble_outline,
                            size: SizeConfig.iconSize(context, 18),
                          ),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => ShotChatDialog(
                              shotId: shot.shotId,
                              shotCode: shot.shotCode,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  rows: rows,
                  onFilterChanged: (fieldKey, value) {
                    setState(() {
                      _artistPage = 0;
                      final query = value is String ? value : value.toString();
                      switch (fieldKey) {
                        case 'shotId':
                          _shotIdFilter = query;
                          break;
                        case 'show':
                          _showFilter = query;
                          break;
                        case 'frames':
                          _framesFilter = query;
                          break;
                        case 'clientStatus':
                          _clientStatusFilter = query;
                          break;
                        case 'artistStatus':
                          _artistStatusFilter = query;
                          break;
                        case 'supervisorStatus':
                          _supervisorStatusFilter = query;
                          break;
                        case 'artistEta':
                          _artistEtaFilter = query;
                          break;
                        case 'clientEta':
                          _clientEtaFilter = query;
                          break;
                        default:
                          break;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DepartmentView extends StatefulWidget {
  final TaskController controller;
  final bool showCellBorders;
  final VoidCallback? onFiltersChanged;
  const _DepartmentView({
    super.key,
    required this.controller,
    required this.showCellBorders,
    this.onFiltersChanged,
  });

  @override
  State<_DepartmentView> createState() => _DepartmentViewState();
}

class _DepartmentViewState extends State<_DepartmentView> {
  int _departmentPage = 0;
  // ── Row cache to avoid rebuilding all row Maps on every setState ──
  List<Map<String, dynamic>>? _cachedTaskRows;
  int _cachedShotsLength = -1;
  String? _cachedDepartment;
  String? _cachedClientId;
  String? _cachedShowId;

  String _shotIdFilter = '';
  String _frameInFilter = '';
  String _frameOutFilter = '';
  String _supervisorBidFilter = '';
  String _clientBidFilter = '';
  String _artistFilter = '';
  String _artistBidFilter = '';
  String _artistEtaFilter = '';
  Set<String> _supervisorStatusFilter = {};
  Set<String> _artistStatusFilter = {};
  String _coordinatorFilter = '';
  String _levelOfShotFilter = '';
  String _complexityFilter = '';
  String _totalFramesFilter = '';
  String _allocationDateFilter = '';
  String _allocationEtaFilter = '';
  String _startingDateFilter = '';
  String _completeDateFilter = '';
  String _dailyWipFilter = '';
  String _mandaysFilter = '';
  String _consumedMandaysFilter = '';
  String _savedMandaysFilter = '';
  String _approvedVersionFilter = '';
  String _approvedByFilter = '';
  String _commentsFilter = '';
  String _fromRotoFilter = '';
  String _fromPaintFilter = '';
  String _fromMmFilter = '';
  String _fromCompFilter = '';

  bool _contains(dynamic value, String query) {
    if (query.trim().isEmpty) return true;
    return (value ?? '').toString().toLowerCase().contains(
      query.trim().toLowerCase(),
    );
  }

  List<FilterOption> _buildOptions(List<String> values, String selected) {
    return values
        .map(
          (value) => FilterOption(
            label: value,
            value: value,
            isSelected: value == selected,
          ),
        )
        .toList(growable: false);
  }

  void _applyTaskGridFilter(String fieldKey, String query) {
    switch (fieldKey) {
      case 'shotId':
        _shotIdFilter = query;
        break;
      case 'frameIn':
        _frameInFilter = query;
        break;
      case 'frameOut':
        _frameOutFilter = query;
        break;
      case 'supervisorBid':
        _supervisorBidFilter = query;
        break;
      case 'clientBid':
        _clientBidFilter = query;
        break;
      case 'artist':
        _artistFilter = query;
        break;
      case 'artistBid':
        _artistBidFilter = query;
        break;
      case 'artistEta':
        _artistEtaFilter = query;
        break;
      case 'supervisorStatus':
        _supervisorStatusFilter = query.isEmpty ? {} : {query};
        break;
      case 'artistStatus':
        _artistStatusFilter = query.isEmpty ? {} : {query};
        break;
      case 'coordinator':
        _coordinatorFilter = query;
        break;
      case 'levelOfShot':
        _levelOfShotFilter = query;
        break;
      case 'complexity':
        _complexityFilter = query;
        break;
      case 'totalFrames':
        _totalFramesFilter = query;
        break;
      case 'allocationDate':
        _allocationDateFilter = query;
        break;
      case 'allocationEta':
        _allocationEtaFilter = query;
        break;
      case 'startingDate':
        _startingDateFilter = query;
        break;
      case 'completeDate':
        _completeDateFilter = query;
        break;
      case 'dailyWip':
        _dailyWipFilter = query;
        break;
      case 'mandays':
        _mandaysFilter = query;
        break;
      case 'consumedMandays':
        _consumedMandaysFilter = query;
        break;
      case 'savedMandays':
        _savedMandaysFilter = query;
        break;
      case 'approvedVersion':
        _approvedVersionFilter = query;
        break;
      case 'approvedBy':
        _approvedByFilter = query;
        break;
      case 'comments':
        _commentsFilter = query;
        break;
      case 'fromRoto':
        _fromRotoFilter = query;
        break;
      case 'fromPaint':
        _fromPaintFilter = query;
        break;
      case 'fromMm':
        _fromMmFilter = query;
        break;
      case 'fromComp':
        _fromCompFilter = query;
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller.isLoading && controller.departmentShots.isEmpty) {
      return const LoadingWidget(message: 'Loading shots...');
    }
    if (controller.departmentShots.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.task_outlined,

        title: 'No shots',
        description: 'No shots are present in this department yet.',
      );
    }

    // ── Rebuild row cache only when shots list changes ──────────────
    if (_cachedShotsLength != controller.departmentShots.length ||
        _cachedDepartment != controller.selectedDepartment ||
        _cachedClientId != controller.selectedClientId ||
        _cachedShowId != controller.selectedShowId ||
        _cachedTaskRows == null) {
      _cachedShotsLength = controller.departmentShots.length;
      _cachedDepartment = controller.selectedDepartment;
      _cachedClientId = controller.selectedClientId;
      _cachedShowId = controller.selectedShowId;
      _cachedTaskRows = controller.departmentShots
          .map((shot) {
            final totalFrames = shot.totalFrames > 0
                ? shot.totalFrames
                : (shot.frameOut - shot.frameIn + 1);
            return {
              'sno': controller.departmentShots.indexOf(shot) + 1,
              'shotId': shot.shotCode,
              'frameIn': shot.frameIn,
              'frameOut': shot.frameOut,
              'totalFrames': totalFrames,
              'supervisorBid': shot.supervisorBid.toStringAsFixed(1),
              'clientBid': shot.clientBid.toStringAsFixed(1),
              'artist': shot.artistName ?? 'Unassigned',
              'artistBid': shot.artistBid.toStringAsFixed(1),
              'artistEta': formatDateLikeExcelD(shot.artistEta),
              'supervisorStatus': shot.supervisorStatus ?? '—',
              'artistStatus': shot.artistStatus,
              'coordinator': shot.coordinator ?? '—',
              'levelOfShot': shot.levelOfShot ?? '—',
              'complexity': shot.complexity ?? '—',
              'allocationDate': formatDateLikeExcelD(shot.allocationDate),
              'allocationEta': formatDateLikeExcelD(shot.allocationEta),
              'startingDate': formatDateLikeExcelD(shot.startingDate),
              'completeDate': formatDateLikeExcelD(shot.completeDate),
              'dailyWip': shot.dailyWip.toStringAsFixed(1),
              'mandays': shot.mandays.toStringAsFixed(1),
              'consumedMandays': shot.consumedMandays.toStringAsFixed(1),
              'savedMandays': shot.savedMandays.toStringAsFixed(1),
              'approvedVersion': shot.approvedVersion ?? '—',
              'approvedBy': shot.approvedBy ?? '—',
              'comments': shot.comments ?? '—',
              'fromRoto': shot.fromRoto ?? '—',
              'fromPaint': shot.fromPaint ?? '—',
              'fromMm': shot.fromMm ?? '—',
              'fromComp': shot.fromComp ?? '—',
              'shot': shot,
            };
          })
          .toList(growable: false);
    }

    final cachedRows = _cachedTaskRows!;

    // ── Filter synchronously from cache (fast — string comparisons only) ──
    final rows = cachedRows
        .where((row) {
          return _contains(row['shotId'], _shotIdFilter) &&
              _contains(row['frameIn'], _frameInFilter) &&
              _contains(row['frameOut'], _frameOutFilter) &&
              _contains(row['supervisorBid'], _supervisorBidFilter) &&
              _contains(row['clientBid'], _clientBidFilter) &&
              _contains(row['artist'], _artistFilter) &&
              _contains(row['artistBid'], _artistBidFilter) &&
              _contains(row['artistEta'], _artistEtaFilter) &&
              (_supervisorStatusFilter.isEmpty ||
                  _supervisorStatusFilter.contains(row['supervisorStatus'])) &&
              (_artistStatusFilter.isEmpty ||
                  _artistStatusFilter.contains(row['artistStatus'])) &&
              _contains(row['coordinator'], _coordinatorFilter) &&
              _contains(row['levelOfShot'], _levelOfShotFilter) &&
              _contains(row['complexity'], _complexityFilter) &&
              _contains(row['totalFrames'], _totalFramesFilter) &&
              _contains(row['allocationDate'], _allocationDateFilter) &&
              _contains(row['allocationEta'], _allocationEtaFilter) &&
              _contains(row['startingDate'], _startingDateFilter) &&
              _contains(row['completeDate'], _completeDateFilter) &&
              _contains(row['dailyWip'], _dailyWipFilter) &&
              _contains(row['mandays'], _mandaysFilter) &&
              _contains(row['consumedMandays'], _consumedMandaysFilter) &&
              _contains(row['savedMandays'], _savedMandaysFilter) &&
              _contains(row['approvedVersion'], _approvedVersionFilter) &&
              _contains(row['approvedBy'], _approvedByFilter) &&
              _contains(row['comments'], _commentsFilter) &&
              _contains(row['fromRoto'], _fromRotoFilter) &&
              _contains(row['fromPaint'], _fromPaintFilter) &&
              _contains(row['fromMm'], _fromMmFilter) &&
              _contains(row['fromComp'], _fromCompFilter);
        })
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 12)),
          child: Text(
            'Task Management',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        GlassContainer(
          padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 8)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tasksPaginationBar(
                context,
                _departmentPage,
                rows.length,
                (page) => setState(() => _departmentPage = page),
              ),
              DynamicDataTable(
                currentPage: _departmentPage,
                onPageChanged: (page) => setState(() => _departmentPage = page),
                rowsPerPage: _tasksRowsPerPage,
                showCellBorders: widget.showCellBorders,
                // frozenColumnCount: 3,
                columnSpacing: SizeConfig.scaleWidth(context, 30),
                headingRowHeight: MediaQuery.of(context).size.height * 42 / 768,
                dataRowMinHeight: MediaQuery.of(context).size.height * 44 / 768,
                dataRowMaxHeight: MediaQuery.of(context).size.height * 56 / 768,
                fields: [
                  DynamicTableField(
                    key: 'sno',
                    label: 'S.No',
                    width: SizeConfig.scaleWidth(context, 48),
                    numeric: true,
                    filterRequired: false,
                  ),
                  DynamicTableField(
                    key: 'shotId',
                    label: 'Shot ID',
                    width: SizeConfig.scaleWidth(context, 130),
                  ),
                  DynamicTableField(
                    key: 'frameIn',
                    label: 'Frame In',
                    width: SizeConfig.scaleWidth(context, 80),
                    numeric: true,
                  ),
                  DynamicTableField(
                    key: 'frameOut',
                    label: 'Frame Out',
                    width: SizeConfig.scaleWidth(context, 80),
                    numeric: true,
                  ),
                  DynamicTableField(
                    key: 'totalFrames',
                    label: 'Total',
                    width: SizeConfig.scaleWidth(context, 70),
                    numeric: true,
                  ),
                  DynamicTableField(
                    key: 'coordinator',
                    label: 'Coordinator',
                    width: SizeConfig.scaleWidth(context, 120),
                  ),
                  DynamicTableField(
                    key: 'levelOfShot',
                    label: 'Level',
                    width: SizeConfig.scaleWidth(context, 90),
                  ),
                  DynamicTableField(
                    key: 'complexity',
                    label: 'Complexity',
                    width: SizeConfig.scaleWidth(context, 100),
                  ),
                  DynamicTableField(
                    key: 'allocationDate',
                    label: 'Alloc Date',
                    width: SizeConfig.scaleWidth(context, 110),
                  ),
                  DynamicTableField(
                    key: 'allocationEta',
                    label: 'Alloc ETA',
                    width: SizeConfig.scaleWidth(context, 110),
                  ),
                  DynamicTableField(
                    key: 'startingDate',
                    label: 'Start Date',
                    width: SizeConfig.scaleWidth(context, 110),
                  ),
                  DynamicTableField(
                    key: 'completeDate',
                    label: 'Complete',
                    width: SizeConfig.scaleWidth(context, 110),
                  ),
                  DynamicTableField(
                    key: 'dailyWip',
                    label: 'WIP %',
                    width: SizeConfig.scaleWidth(context, 70),
                    numeric: true,
                  ),
                  DynamicTableField(
                    key: 'mandays',
                    label: 'Mandays',
                    width: SizeConfig.scaleWidth(context, 80),
                    numeric: true,
                  ),
                  DynamicTableField(
                    key: 'consumedMandays',
                    label: 'Consumed',
                    width: SizeConfig.scaleWidth(context, 90),
                    numeric: true,
                  ),
                  DynamicTableField(
                    key: 'savedMandays',
                    label: 'Saved',
                    width: SizeConfig.scaleWidth(context, 80),
                    numeric: true,
                  ),
                  DynamicTableField(
                    key: 'supervisorBid',
                    label: 'Sup Bid',
                    width: SizeConfig.scaleWidth(context, 80),
                    numeric: true,
                  ),
                  DynamicTableField(
                    key: 'clientBid',
                    label: 'Cli Bid',
                    width: SizeConfig.scaleWidth(context, 80),
                    numeric: true,
                  ),
                  DynamicTableField(
                    key: 'artist',
                    label: 'Artist',
                    width: SizeConfig.scaleWidth(context, 120),
                  ),
                  DynamicTableField(
                    key: 'artistBid',
                    label: 'Art Bid',
                    width: SizeConfig.scaleWidth(context, 80),
                    numeric: true,
                  ),
                  DynamicTableField(
                    key: 'artistEta',
                    label: 'Art ETA',
                    width: SizeConfig.scaleWidth(context, 110),
                  ),
                  DynamicTableField(
                    key: 'approvedVersion',
                    label: 'Appr Ver',
                    width: SizeConfig.scaleWidth(context, 100),
                  ),
                  DynamicTableField(
                    key: 'approvedBy',
                    label: 'Appr By',
                    width: SizeConfig.scaleWidth(context, 100),
                  ),
                  DynamicTableField(
                    key: 'comments',
                    label: 'Comments',
                    width: SizeConfig.scaleWidth(context, 160),
                  ),
                  DynamicTableField(
                    key: 'supervisorStatus',
                    label: 'Sup Status',
                    width: 130,
                    filterOptions: _buildOptions(
                      AppConstants.supervisorStatuses,
                      _supervisorStatusFilter.length == 1
                          ? _supervisorStatusFilter.first
                          : '',
                    ),
                  ),
                  DynamicTableField(
                    key: 'artistStatus',
                    label: 'Art Status',
                    width: 130,
                    filterOptions: _buildOptions(
                      AppConstants.artistStatuses,
                      _artistStatusFilter.length == 1
                          ? _artistStatusFilter.first
                          : '',
                    ),
                  ),
                  DynamicTableField(
                    key: 'fromRoto',
                    label: 'From Roto',
                    width: SizeConfig.scaleWidth(context, 110),
                  ),
                  DynamicTableField(
                    key: 'fromPaint',
                    label: 'From Paint',
                    width: SizeConfig.scaleWidth(context, 110),
                  ),
                  DynamicTableField(
                    key: 'fromMm',
                    label: 'From MM',
                    width: SizeConfig.scaleWidth(context, 100),
                  ),
                  DynamicTableField(
                    key: 'fromComp',
                    label: 'From Comp',
                    width: SizeConfig.scaleWidth(context, 100),
                  ),
                  DynamicTableField(
                    key: 'actions',
                    label: 'Actions',
                    width: 110,
                    filterRequired: false,
                    builder: (context, value, row, rowIndex) {
                      final shot = row['shot'] as ShotModel;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Assign artist',
                            icon: Icon(
                              Icons.person_add_alt,
                              size: SizeConfig.iconSize(context, 18),
                            ),
                            onPressed: () => _assign(context, shot),
                          ),
                          IconButton(
                            tooltip: 'Chat',
                            icon: Icon(
                              Icons.chat_bubble_outline,
                              size: SizeConfig.iconSize(context, 18),
                            ),
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => ShotChatDialog(
                                shotId: shot.shotId,
                                shotCode: shot.shotCode,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                rows: rows,
                onFilterChanged: (fieldKey, value) {
                  setState(() {
                    _departmentPage = 0;
                    final query = value is String ? value : value.toString();
                    _applyTaskGridFilter(fieldKey, query);
                  });
                },
              ),
            ],
          ),
        ),
        // SizedBox(height: SizeConfig.scaleHeight(context, 20)),
        // Padding(
        //   padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 12)),
        //   child: Text(
        //     'Client Feedback Details',
        //     style: Theme.of(
        //       context,
        //     ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        //   ),
        // ),
        // _buildFeedbackTable(controller, rows),
      ],
    );
  }

  // Widget _buildFeedbackTable(
  //   TaskController controller,
  //   List<Map<String, dynamic>> taskRows,
  // ) {
  //   final filteredRows = taskRows
  //       .where((row) {
  //         final shot = row['shot'] as ShotModel;
  //         return _contains(shot.shotCode, _feedbackShotIdFilter) &&
  //             _contains(shot.department, _feedbackDepartmentFilter) &&
  //             _contains(shot.clientFeedback ?? '—', _feedbackFilter) &&
  //             _contains(
  //               shot.artistName ?? 'Unassigned',
  //               _feedbackArtistFilter,
  //             ) &&
  //             _contains(_fmtDate(shot.artistEta), _feedbackArtistEtaFilter) &&
  //             _contains(
  //               shot.supervisorStatus ?? '—',
  //               _feedbackSupervisorStatusFilter,
  //             ) &&
  //             _contains(shot.artistStatus, _feedbackArtistStatusFilter);
  //       })
  //       .map((row) {
  //         final shot = row['shot'] as ShotModel;
  //         return {
  //           'sno': taskRows.indexOf(row) + 1,
  //           'shotId': shot.shotCode,
  //           'department': shot.department,
  //           'feedback': shot.clientFeedback ?? '—',
  //           'artist': shot.artistName ?? 'Unassigned',
  //           'artistBid': shot.artistBid.toStringAsFixed(1),
  //           'artistEta': _fmtDate(shot.artistEta),
  //           'supervisorStatus': shot.supervisorStatus ?? '—',
  //           'artistStatus': shot.artistStatus,
  //           'shot': shot,
  //         };
  //       })
  //       .toList(growable: false);

  //   return GlassContainer(
  //     padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 8)),
  //     child: DynamicDataTable(
  //       // frozenColumnCount: 2,
  //       columnSpacing: SizeConfig.scaleWidth(context, 30),
  //       // headingRowHeight: MediaQuery.of(context).size.height * 42 / 768,
  //       dataRowMinHeight: MediaQuery.of(context).size.height * 44 / 768,
  //       dataRowMaxHeight: MediaQuery.of(context).size.height * 56 / 768,
  //       fields: [
  //         DynamicTableField(
  //           key: 'sno',
  //           label: 'S.No',
  //           numeric: true,
  //           filterRequired: false,
  //         ),
  //         DynamicTableField(key: 'shotId', label: 'Shot ID'),
  //         DynamicTableField(
  //           key: 'department',
  //           label: 'Department',
  //           filterOptions: _buildOptions(
  //             AppConstants.pipelineDepartments,
  //             _feedbackDepartmentFilter,
  //           ),
  //         ),
  //         DynamicTableField(key: 'artist', label: 'Artist'),
  //         DynamicTableField(
  //           key: 'artistBid',
  //           label: 'Artist Bid',
  //           numeric: true,
  //         ),
  //         DynamicTableField(key: 'artistEta', label: 'Artist ETA'),
  //         DynamicTableField(
  //           key: 'supervisorStatus',
  //           label: 'Supervisor Status',
  //           filterOptions: _buildOptions(
  //             AppConstants.supervisorStatuses,
  //             _feedbackSupervisorStatusFilter,
  //           ),
  //         ),
  //         DynamicTableField(
  //           key: 'artistStatus',
  //           label: 'Artist Status',
  //           filterOptions: _buildOptions(
  //             AppConstants.artistStatuses,
  //             _feedbackArtistStatusFilter,
  //           ),
  //         ),
  //         DynamicTableField(
  //           key: 'feedback',
  //           label: 'Client Feedback',
  //           builder: (context, value, row, rowIndex) {
  //             final feedback = (value ?? '—').toString();
  //             return Tooltip(
  //               message: feedback,
  //               child: SizedBox(
  //                 width: SizeConfig.scaleWidth(context, 240),
  //                 child: Text(
  //                   feedback,
  //                   maxLines: 2,
  //                   overflow: TextOverflow.ellipsis,
  //                 ),
  //               ),
  //             );
  //           },
  //         ),
  //         DynamicTableField(
  //           key: 'actions',
  //           label: 'Actions',
  //           filterRequired: false,
  //           builder: (context, value, row, rowIndex) {
  //             final shot = row['shot'] as ShotModel;
  //             return Row(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 IconButton(
  //                   tooltip: 'Assign artist',
  //                   icon: Icon(
  //                     Icons.person_add_alt,
  //                     size: SizeConfig.iconSize(context, 18),
  //                   ),
  //                   onPressed: () => _assign(context, shot),
  //                 ),
  //                 IconButton(
  //                   tooltip: 'Chat',
  //                   icon: Icon(
  //                     Icons.chat_bubble_outline,
  //                     size: SizeConfig.iconSize(context, 18),
  //                   ),
  //                   onPressed: () => showDialog(
  //                     context: context,
  //                     builder: (_) => ShotChatDialog(
  //                       shotId: shot.shotId,
  //                       shotCode: shot.shotCode,
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             );
  //           },
  //         ),
  //       ],
  //       rows: filteredRows,
  //       onFilterChanged: (fieldKey, value) {
  //         setState(() {
  //           final query = value is String ? value : value.toString();
  //           _applyFeedbackGridFilter(fieldKey, query);
  //         });
  //       },
  //     ),
  //   );
  // }

  bool get _hasActiveFilters =>
      _supervisorStatusFilter.isNotEmpty ||
      _artistStatusFilter.isNotEmpty ||
      _artistFilter.isNotEmpty ||
      _coordinatorFilter.isNotEmpty ||
      _shotIdFilter.isNotEmpty ||
      _frameInFilter.isNotEmpty ||
      _frameOutFilter.isNotEmpty ||
      _supervisorBidFilter.isNotEmpty ||
      _clientBidFilter.isNotEmpty ||
      _artistBidFilter.isNotEmpty ||
      _artistEtaFilter.isNotEmpty ||
      _levelOfShotFilter.isNotEmpty ||
      _complexityFilter.isNotEmpty ||
      _totalFramesFilter.isNotEmpty ||
      _allocationDateFilter.isNotEmpty ||
      _allocationEtaFilter.isNotEmpty ||
      _startingDateFilter.isNotEmpty ||
      _completeDateFilter.isNotEmpty ||
      _dailyWipFilter.isNotEmpty ||
      _mandaysFilter.isNotEmpty ||
      _consumedMandaysFilter.isNotEmpty ||
      _savedMandaysFilter.isNotEmpty ||
      _approvedVersionFilter.isNotEmpty ||
      _approvedByFilter.isNotEmpty ||
      _commentsFilter.isNotEmpty ||
      _fromRotoFilter.isNotEmpty ||
      _fromPaintFilter.isNotEmpty ||
      _fromMmFilter.isNotEmpty ||
      _fromCompFilter.isNotEmpty;

  bool get hasActiveFilters => _hasActiveFilters;

  Future<void> openFilterDialog(BuildContext context) =>
      _showFilterDialog(context);

  Future<void> _showFilterDialog(BuildContext context) async {
    final result = await showDialog<_FilterResult>(
      context: context,
      builder: (ctx) => _FilterDialog(
        controller: widget.controller,
        initialSupervisorStatuses: _supervisorStatusFilter,
        initialArtistStatuses: _artistStatusFilter,
        initialArtist: _artistFilter,
        initialCoordinator: _coordinatorFilter,
        initialShotId: _shotIdFilter,
        initialFrameIn: _frameInFilter,
        initialFrameOut: _frameOutFilter,
        initialSupervisorBid: _supervisorBidFilter,
        initialClientBid: _clientBidFilter,
        initialArtistBid: _artistBidFilter,
        initialArtistEta: _artistEtaFilter,
        initialLevelOfShot: _levelOfShotFilter,
        initialComplexity: _complexityFilter,
        initialTotalFrames: _totalFramesFilter,
        initialAllocationDate: _allocationDateFilter,
        initialAllocationEta: _allocationEtaFilter,
        initialStartingDate: _startingDateFilter,
        initialCompleteDate: _completeDateFilter,
        initialDailyWip: _dailyWipFilter,
        initialMandays: _mandaysFilter,
        initialConsumedMandays: _consumedMandaysFilter,
        initialSavedMandays: _savedMandaysFilter,
        initialApprovedVersion: _approvedVersionFilter,
        initialApprovedBy: _approvedByFilter,
        initialComments: _commentsFilter,
        initialFromRoto: _fromRotoFilter,
        initialFromPaint: _fromPaintFilter,
        initialFromMm: _fromMmFilter,
        initialFromComp: _fromCompFilter,
      ),
    );
    if (result == null || !mounted) return;

    // Apply data-source selection (department / client / show) first so the
    // grid reloads with the new scope before filters are applied below.
    // Capture into locals so they can be promoted to non-nullable.
    final dept = result.department;
    final clientId = result.clientId;
    final showId = result.showId;
    if (dept != null && dept != widget.controller.selectedDepartment) {
      widget.controller.selectDepartment(dept);
      await widget.controller.loadShots();
    }
    if (clientId != null && clientId != widget.controller.selectedClientId) {
      await widget.controller.selectClient(clientId);
    }
    if (showId != null && showId != widget.controller.selectedShowId) {
      await widget.controller.selectShow(showId);
    }
    if (!mounted) return;
    setState(() {
      _departmentPage = 0;
      _supervisorStatusFilter = result.supervisorStatuses;
      _artistStatusFilter = result.artistStatuses;
      _artistFilter = result.artist;
      _coordinatorFilter = result.coordinator;
      _shotIdFilter = result.shotId;
      _frameInFilter = result.frameIn;
      _frameOutFilter = result.frameOut;
      _supervisorBidFilter = result.supervisorBid;
      _clientBidFilter = result.clientBid;
      _artistBidFilter = result.artistBid;
      _artistEtaFilter = result.artistEta;
      _levelOfShotFilter = result.levelOfShot;
      _complexityFilter = result.complexity;
      _totalFramesFilter = result.totalFrames;
      _allocationDateFilter = result.allocationDate;
      _allocationEtaFilter = result.allocationEta;
      _startingDateFilter = result.startingDate;
      _completeDateFilter = result.completeDate;
      _dailyWipFilter = result.dailyWip;
      _mandaysFilter = result.mandays;
      _consumedMandaysFilter = result.consumedMandays;
      _savedMandaysFilter = result.savedMandays;
      _approvedVersionFilter = result.approvedVersion;
      _approvedByFilter = result.approvedBy;
      _commentsFilter = result.comments;
      _fromRotoFilter = result.fromRoto;
      _fromPaintFilter = result.fromPaint;
      _fromMmFilter = result.fromMm;
      _fromCompFilter = result.fromComp;
    });
    widget.onFiltersChanged?.call();
  }

  Future<void> _assign(BuildContext context, ShotModel shot) async {
    final assigned = await showDialog<bool>(
      context: context,
      builder: (_) => _AssignDialog(shot: shot, controller: widget.controller),
    );
    if (assigned == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Artist assigned')));
    }
  }
}

/// Admin-only: renders the selected department's shots mapped onto the
/// Production Management module's 20-column grid format. The data still comes
/// from the Tasks/Shots module — only the headers follow the Production grid.
class _ProductionView extends StatefulWidget {
  final TaskController controller;
  final bool showCellBorders;
  const _ProductionView({
    required this.controller,
    required this.showCellBorders,
  });

  @override
  State<_ProductionView> createState() => _ProductionViewState();
}

class _ProductionViewState extends State<_ProductionView> {
  int _page = 0;

  // ── Row cache to avoid rebuilding all row Maps on every setState ──
  List<Map<String, dynamic>>? _cachedRows;
  int _cachedShotsLength = -1;
  String? _cachedDepartment;

  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _monthLabel(DateTime? d) =>
      d == null ? '—' : '${_monthNames[d.month - 1]}-${d.year}';

  String _framesLabel(ShotModel shot) {
    if (shot.totalFrames > 0) return '${shot.totalFrames}';
    if (shot.frameIn > 0 || shot.frameOut > 0) {
      return '${shot.frameIn}-${shot.frameOut}';
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final shots = controller.departmentShots;
    if (controller.isLoading && shots.isEmpty) {
      return const SizedBox.shrink();
    }
    if (shots.isEmpty) {
      return const SizedBox.shrink();
    }

    // ── Rebuild row cache only when the shots list changes ──────────
    if (_cachedShotsLength != shots.length ||
        _cachedDepartment != controller.selectedDepartment ||
        _cachedRows == null) {
      _cachedShotsLength = shots.length;
      _cachedDepartment = controller.selectedDepartment;
      _cachedRows = List<Map<String, dynamic>>.generate(shots.length, (index) {
        final shot = shots[index];
        return {
          'sNo': index + 1,
          'coordinator': shot.coordinator ?? '—',
          'month': _monthLabel(shot.allocationDate),
          'shotsReceivedDate': formatDateLikeExcelD(shot.allocatedDate),
          'clientForRef': shot.clientName ?? shot.clientId ?? '—',
          'client': shot.clientName ?? '—',
          'show': shot.showName ?? '—',
          'wipEta': formatDateLikeExcelD(shot.allocationEta),
          'eta': formatDateLikeExcelD(shot.clientEta),
          'shotCode': shot.shotCode,
          'frames': _framesLabel(shot),
          'tasks': shot.department,
          'reviewNotes': shot.comments ?? shot.notes ?? '—',
          'status': shot.status,
          'deliveredOn': formatDateLikeExcelD(shot.completeDate),
          'workStation': '—',
          'shotMandays': shot.mandays.toStringAsFixed(1),
          'approvedClientMd': '—',
          'flEta': '—',
          'flMandays': '—',
          'shot': shot,
        };
      });
    }

    final rows = _cachedRows!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 12)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Production Management',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(context, 4)),
                    Text(
                      '${controller.selectedDepartment ?? 'Selected department'} — '
                      'mapped from the task grid',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        GlassContainer(
          padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 8)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tasksPaginationBar(
                context,
                _page,
                rows.length,
                (page) => setState(() => _page = page),
              ),
              DynamicDataTable(
                currentPage: _page,
                onPageChanged: (page) => setState(() => _page = page),
                rowsPerPage: _tasksRowsPerPage,
                showCellBorders: widget.showCellBorders,
                minColumnWidth: SizeConfig.scaleWidth(context, 40),
                columnSpacing: SizeConfig.scaleWidth(context, 12),
                headingRowHeight: MediaQuery.of(context).size.height * 42 / 768,
                dataRowMinHeight: MediaQuery.of(context).size.height * 38 / 768,
                dataRowMaxHeight: MediaQuery.of(context).size.height * 42 / 768,
                fields: [
                  DynamicTableField(
                    key: 'sNo',
                    label: 'S No',
                    width: SizeConfig.scaleWidth(context, 56),
                    numeric: true,
                    filterRequired: false,
                  ),
                  DynamicTableField(
                    key: 'coordinator',
                    label: 'Co ordinator',
                    width: SizeConfig.scaleWidth(context, 140),
                  ),
                  DynamicTableField(
                    key: 'month',
                    label: 'Month',
                    width: SizeConfig.scaleWidth(context, 90),
                  ),
                  DynamicTableField(
                    key: 'shotsReceivedDate',
                    label: 'Shots Received Date',
                    width: SizeConfig.scaleWidth(context, 150),
                  ),
                  DynamicTableField(
                    key: 'clientForRef',
                    label: 'Client for Ref',
                    width: SizeConfig.scaleWidth(context, 140),
                  ),
                  DynamicTableField(
                    key: 'client',
                    label: 'Client',
                    width: SizeConfig.scaleWidth(context, 150),
                  ),
                  DynamicTableField(
                    key: 'show',
                    label: 'Show',
                    width: SizeConfig.scaleWidth(context, 160),
                  ),
                  DynamicTableField(
                    key: 'wipEta',
                    label: 'WIP ETA',
                    width: SizeConfig.scaleWidth(context, 110),
                  ),
                  DynamicTableField(
                    key: 'eta',
                    label: 'ETA',
                    width: SizeConfig.scaleWidth(context, 110),
                  ),
                  DynamicTableField(
                    key: 'shotCode',
                    label: 'Shot ID',
                    width: SizeConfig.scaleWidth(context, 140),
                  ),
                  DynamicTableField(
                    key: 'frames',
                    label: 'Frames',
                    width: SizeConfig.scaleWidth(context, 80),
                    numeric: true,
                  ),
                  DynamicTableField(
                    key: 'tasks',
                    label: 'Tasks',
                    width: SizeConfig.scaleWidth(context, 90),
                  ),
                  DynamicTableField(
                    key: 'reviewNotes',
                    label: 'Review Notes',
                    width: SizeConfig.scaleWidth(context, 180),
                  ),
                  DynamicTableField(
                    key: 'status',
                    label: 'Status',
                    width: SizeConfig.scaleWidth(context, 130),
                  ),
                  DynamicTableField(
                    key: 'deliveredOn',
                    label: 'Delivered on',
                    width: SizeConfig.scaleWidth(context, 110),
                  ),
                  DynamicTableField(
                    key: 'workStation',
                    label: 'Work station',
                    width: SizeConfig.scaleWidth(context, 110),
                  ),
                  DynamicTableField(
                    key: 'shotMandays',
                    label: 'Shot man-days',
                    width: SizeConfig.scaleWidth(context, 110),
                    numeric: true,
                  ),
                  DynamicTableField(
                    key: 'approvedClientMd',
                    label: 'Approved Client MD',
                    width: SizeConfig.scaleWidth(context, 130),
                    numeric: true,
                  ),
                  DynamicTableField(
                    key: 'flEta',
                    label: 'FL ETA',
                    width: SizeConfig.scaleWidth(context, 90),
                  ),
                  DynamicTableField(
                    key: 'flMandays',
                    label: 'FL Man-days',
                    width: SizeConfig.scaleWidth(context, 100),
                    numeric: true,
                  ),
                ],
                rows: rows,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssignDialog extends StatefulWidget {
  final ShotModel shot;
  final TaskController controller;
  const _AssignDialog({required this.shot, required this.controller});

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  final TeamService _teamService = TeamService();
  List<TeamMember> _artists = [];
  String? _selected;
  final TextEditingController _bid = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadArtists();
  }

  @override
  void dispose() {
    _bid.dispose();
    super.dispose();
  }

  Future<void> _loadArtists() async {
    try {
      final resp = await _teamService.getTeams(
        department: widget.shot.department,
      );
      final teams = ((resp['departments'] as List<dynamic>?) ?? const [])
          .map((e) => DepartmentTeam.fromJson(e as Map<String, dynamic>))
          .toList();
      _artists = teams.expand((t) => t.members).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.of(context).size.width;
    final dialogWidth = availableWidth < 500 ? availableWidth * 0.88 : 360.0;

    return AlertDialog(
      title: Text('Assign ${widget.shot.shotCode}'),
      content: SizedBox(
        width: dialogWidth,
        child: _loading
            ? SizedBox(
                height: SizeConfig.scaleHeight(context, 80),
                child: const Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 12,
                children: [
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  DropdownButtonFormField<String>(
                    initialValue: _selected,
                    decoration: const InputDecoration(labelText: 'Artist'),
                    items: _artists
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.userId,
                            child: Text(
                              '${a.name}${a.level != null ? ' (${a.level})' : ''}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selected = v),
                  ),
                  TextField(
                    controller: _bid,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Artist bid (mandays)',
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving || _selected == null ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Assign'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await widget.controller.assignShot(widget.shot.shotId, {
      'artistId': _selected,
      'artistBid': double.tryParse(_bid.text) ?? 0,
    });
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = err;
      });
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter dialog data & widget
// ─────────────────────────────────────────────────────────────────────────────

class _FilterResult {
  final String? department;
  final String? clientId;
  final String? showId;
  final Set<String> supervisorStatuses;
  final Set<String> artistStatuses;
  final String artist;
  final String coordinator;
  final String shotId;
  final String frameIn;
  final String frameOut;
  final String supervisorBid;
  final String clientBid;
  final String artistBid;
  final String artistEta;
  final String levelOfShot;
  final String complexity;
  final String totalFrames;
  final String allocationDate;
  final String allocationEta;
  final String startingDate;
  final String completeDate;
  final String dailyWip;
  final String mandays;
  final String consumedMandays;
  final String savedMandays;
  final String approvedVersion;
  final String approvedBy;
  final String comments;
  final String fromRoto;
  final String fromPaint;
  final String fromMm;
  final String fromComp;

  const _FilterResult({
    this.department,
    this.clientId,
    this.showId,
    required this.supervisorStatuses,
    required this.artistStatuses,
    required this.artist,
    required this.coordinator,
    required this.shotId,
    required this.frameIn,
    required this.frameOut,
    required this.supervisorBid,
    required this.clientBid,
    required this.artistBid,
    required this.artistEta,
    required this.levelOfShot,
    required this.complexity,
    required this.totalFrames,
    required this.allocationDate,
    required this.allocationEta,
    required this.startingDate,
    required this.completeDate,
    required this.dailyWip,
    required this.mandays,
    required this.consumedMandays,
    required this.savedMandays,
    required this.approvedVersion,
    required this.approvedBy,
    required this.comments,
    required this.fromRoto,
    required this.fromPaint,
    required this.fromMm,
    required this.fromComp,
  });
}

class _FilterDialog extends StatefulWidget {
  final TaskController controller;
  final Set<String> initialSupervisorStatuses;
  final Set<String> initialArtistStatuses;
  final String initialArtist;
  final String initialCoordinator;
  final String initialShotId;
  final String initialFrameIn;
  final String initialFrameOut;
  final String initialSupervisorBid;
  final String initialClientBid;
  final String initialArtistBid;
  final String initialArtistEta;
  final String initialLevelOfShot;
  final String initialComplexity;
  final String initialTotalFrames;
  final String initialAllocationDate;
  final String initialAllocationEta;
  final String initialStartingDate;
  final String initialCompleteDate;
  final String initialDailyWip;
  final String initialMandays;
  final String initialConsumedMandays;
  final String initialSavedMandays;
  final String initialApprovedVersion;
  final String initialApprovedBy;
  final String initialComments;
  final String initialFromRoto;
  final String initialFromPaint;
  final String initialFromMm;
  final String initialFromComp;

  const _FilterDialog({
    required this.controller,
    required this.initialSupervisorStatuses,
    required this.initialArtistStatuses,
    required this.initialArtist,
    required this.initialCoordinator,
    required this.initialShotId,
    required this.initialFrameIn,
    required this.initialFrameOut,
    required this.initialSupervisorBid,
    required this.initialClientBid,
    required this.initialArtistBid,
    required this.initialArtistEta,
    required this.initialLevelOfShot,
    required this.initialComplexity,
    required this.initialTotalFrames,
    required this.initialAllocationDate,
    required this.initialAllocationEta,
    required this.initialStartingDate,
    required this.initialCompleteDate,
    required this.initialDailyWip,
    required this.initialMandays,
    required this.initialConsumedMandays,
    required this.initialSavedMandays,
    required this.initialApprovedVersion,
    required this.initialApprovedBy,
    required this.initialComments,
    required this.initialFromRoto,
    required this.initialFromPaint,
    required this.initialFromMm,
    required this.initialFromComp,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late Set<String> _supervisorStatuses;
  late Set<String> _artistStatuses;
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, bool> _expanded;

  // ── Data source (department / client / show) single-select ──
  late String? _selectedDept;
  late String? _selectedClientId;
  late String? _selectedShowId;

  @override
  void initState() {
    super.initState();
    _supervisorStatuses = Set<String>.from(widget.initialSupervisorStatuses);
    _artistStatuses = Set<String>.from(widget.initialArtistStatuses);
    _selectedDept =
        widget.controller.selectedDepartment ?? TaskController.allOption;
    _selectedClientId =
        widget.controller.selectedClientId ?? TaskController.allOption;
    _selectedShowId =
        widget.controller.selectedShowId ?? TaskController.allOption;
    _controllers = {
      'shotId': TextEditingController(text: widget.initialShotId),
      'artist': TextEditingController(text: widget.initialArtist),
      'coordinator': TextEditingController(text: widget.initialCoordinator),
      'frameIn': TextEditingController(text: widget.initialFrameIn),
      'frameOut': TextEditingController(text: widget.initialFrameOut),
      'totalFrames': TextEditingController(text: widget.initialTotalFrames),
      'supervisorBid': TextEditingController(text: widget.initialSupervisorBid),
      'clientBid': TextEditingController(text: widget.initialClientBid),
      'artistBid': TextEditingController(text: widget.initialArtistBid),
      'artistEta': TextEditingController(text: widget.initialArtistEta),
      'levelOfShot': TextEditingController(text: widget.initialLevelOfShot),
      'complexity': TextEditingController(text: widget.initialComplexity),
      'allocationDate': TextEditingController(
        text: widget.initialAllocationDate,
      ),
      'allocationEta': TextEditingController(text: widget.initialAllocationEta),
      'startingDate': TextEditingController(text: widget.initialStartingDate),
      'completeDate': TextEditingController(text: widget.initialCompleteDate),
      'dailyWip': TextEditingController(text: widget.initialDailyWip),
      'mandays': TextEditingController(text: widget.initialMandays),
      'consumedMandays': TextEditingController(
        text: widget.initialConsumedMandays,
      ),
      'savedMandays': TextEditingController(text: widget.initialSavedMandays),
      'approvedVersion': TextEditingController(
        text: widget.initialApprovedVersion,
      ),
      'approvedBy': TextEditingController(text: widget.initialApprovedBy),
      'comments': TextEditingController(text: widget.initialComments),
      'fromRoto': TextEditingController(text: widget.initialFromRoto),
      'fromPaint': TextEditingController(text: widget.initialFromPaint),
      'fromMm': TextEditingController(text: widget.initialFromMm),
      'fromComp': TextEditingController(text: widget.initialFromComp),
    };
    _expanded = {
      'supervisor': true,
      'artist': false,
      'search': false,
      'bidding': false,
      'frames': false,
      'dates': false,
      'crossDept': false,
      'other': false,
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _clearAll() {
    setState(() {
      _selectedDept = TaskController.allOption;
      _selectedClientId = TaskController.allOption;
      _selectedShowId = TaskController.allOption;
      _supervisorStatuses.clear();
      _artistStatuses.clear();
      for (final c in _controllers.values) {
        c.clear();
      }
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      _FilterResult(
        department:
            _selectedDept !=
                (widget.controller.selectedDepartment ??
                    TaskController.allOption)
            ? _selectedDept
            : null,
        clientId:
            _selectedClientId !=
                (widget.controller.selectedClientId ?? TaskController.allOption)
            ? _selectedClientId
            : null,
        showId:
            _selectedShowId !=
                (widget.controller.selectedShowId ?? TaskController.allOption)
            ? _selectedShowId
            : null,
        supervisorStatuses: _supervisorStatuses,
        artistStatuses: _artistStatuses,
        shotId: _controllers['shotId']!.text,
        artist: _controllers['artist']!.text,
        coordinator: _controllers['coordinator']!.text,
        frameIn: _controllers['frameIn']!.text,
        frameOut: _controllers['frameOut']!.text,
        totalFrames: _controllers['totalFrames']!.text,
        supervisorBid: _controllers['supervisorBid']!.text,
        clientBid: _controllers['clientBid']!.text,
        artistBid: _controllers['artistBid']!.text,
        artistEta: _controllers['artistEta']!.text,
        levelOfShot: _controllers['levelOfShot']!.text,
        complexity: _controllers['complexity']!.text,
        allocationDate: _controllers['allocationDate']!.text,
        allocationEta: _controllers['allocationEta']!.text,
        startingDate: _controllers['startingDate']!.text,
        completeDate: _controllers['completeDate']!.text,
        dailyWip: _controllers['dailyWip']!.text,
        mandays: _controllers['mandays']!.text,
        consumedMandays: _controllers['consumedMandays']!.text,
        savedMandays: _controllers['savedMandays']!.text,
        approvedVersion: _controllers['approvedVersion']!.text,
        approvedBy: _controllers['approvedBy']!.text,
        comments: _controllers['comments']!.text,
        fromRoto: _controllers['fromRoto']!.text,
        fromPaint: _controllers['fromPaint']!.text,
        fromMm: _controllers['fromMm']!.text,
        fromComp: _controllers['fromComp']!.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.of(context).size.width;
    final dialogWidth = availableWidth < 600 ? availableWidth * 0.92 : 560.0;

    return AlertDialog(
      title: Row(
        children: [
          const Text('Filter Tasks'),
          const Spacer(),
          TextButton(onPressed: _clearAll, child: const Text('Clear All')),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Data Source (inline single-select chips) ──
              _labeledChipRow(
                'Department',
                [TaskController.allOption, ...widget.controller.departments],
                _selectedDept,
                (v) => setState(() => _selectedDept = v),
              ),
              SizedBox(height: SizeConfig.scaleHeight(context, 8)),
              _labeledChipRow(
                'Client',
                [
                  TaskController.allOption,
                  ...widget.controller.clients.map((c) => c.clientId),
                ],
                _selectedClientId,
                (v) => setState(() => _selectedClientId = v),
                labelFn: _clientName,
              ),
              SizedBox(height: SizeConfig.scaleHeight(context, 8)),
              _labeledChipRow(
                'Show',
                [
                  TaskController.allOption,
                  ...widget.controller.shows.map((s) => s.showId),
                ],
                _selectedShowId,
                (v) => setState(() => _selectedShowId = v),
                labelFn: _showName,
              ),
              const Divider(height: 24),
              _sectionHeader(
                'Supervisor Status',
                'supervisor',
                _supervisorStatuses,
              ),
              if (_expanded['supervisor']!) ...[
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _chipGrid(
                  AppConstants.supervisorStatuses,
                  _supervisorStatuses,
                  (v) => setState(() {
                    if (_supervisorStatuses.contains(v)) {
                      _supervisorStatuses.remove(v);
                    } else {
                      _supervisorStatuses.add(v);
                    }
                  }),
                ),
                SizedBox(height: SizeConfig.scaleHeight(context, 12)),
              ],
              _sectionHeader('Artist Status', 'artist', _artistStatuses),
              if (_expanded['artist']!) ...[
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _chipGrid(
                  AppConstants.artistStatuses,
                  _artistStatuses,
                  (v) => setState(() {
                    if (_artistStatuses.contains(v)) {
                      _artistStatuses.remove(v);
                    } else {
                      _artistStatuses.add(v);
                    }
                  }),
                ),
                SizedBox(height: SizeConfig.scaleHeight(context, 12)),
              ],
              _sectionHeader('Search Fields', 'search', null),
              if (_expanded['search']!) ...[
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('shotId', 'Shot ID'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('artist', 'Artist'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('coordinator', 'Coordinator'),
                SizedBox(height: SizeConfig.scaleHeight(context, 12)),
              ],
              _sectionHeader('Bidding', 'bidding', null),
              if (_expanded['bidding']!) ...[
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('supervisorBid', 'Supervisor Bid'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('clientBid', 'Client Bid'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('artistBid', 'Artist Bid'),
                SizedBox(height: SizeConfig.scaleHeight(context, 12)),
              ],
              _sectionHeader('Frames', 'frames', null),
              if (_expanded['frames']!) ...[
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('frameIn', 'Frame In'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('frameOut', 'Frame Out'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('totalFrames', 'Total Frames'),
                SizedBox(height: SizeConfig.scaleHeight(context, 12)),
              ],
              _sectionHeader('Dates', 'dates', null),
              if (_expanded['dates']!) ...[
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('artistEta', 'Artist ETA'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('allocationDate', 'Allocation Date'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('allocationEta', 'Allocation ETA'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('startingDate', 'Start Date'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('completeDate', 'Complete Date'),
                SizedBox(height: SizeConfig.scaleHeight(context, 12)),
              ],
              _sectionHeader('Cross-Department', 'crossDept', null),
              if (_expanded['crossDept']!) ...[
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('fromRoto', 'From Roto'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('fromPaint', 'From Paint'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('fromMm', 'From MM'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('fromComp', 'From Comp'),
                SizedBox(height: SizeConfig.scaleHeight(context, 12)),
              ],
              _sectionHeader('Other Filters', 'other', null),
              if (_expanded['other']!) ...[
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('levelOfShot', 'Level of Shot'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('complexity', 'Complexity'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('dailyWip', 'Daily WIP %'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('mandays', 'Mandays'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('consumedMandays', 'Consumed Mandays'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('savedMandays', 'Saved Mandays'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('approvedVersion', 'Approved Version'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('approvedBy', 'Approved By'),
                SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                _textField('comments', 'Comments'),
                SizedBox(height: SizeConfig.scaleHeight(context, 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _apply,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandGreen,
            foregroundColor: Colors.white,
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, String key, Set<String>? activeSet) {
    final isExpanded = _expanded[key] ?? false;
    final activeCount = activeSet?.length ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 2)),
      onTap: () => setState(() => _expanded[key] = !isExpanded),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: SizeConfig.scaleWidth(context, 8),
          vertical: SizeConfig.scaleHeight(context, 10),
        ),
        decoration: BoxDecoration(
          color: isExpanded
              ? AppColors.brandGreen.withValues(alpha: 0.08)
              : null,
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: SizeConfig.iconSize(context, 20),
            ),
            SizedBox(width: SizeConfig.scaleWidth(context, 8)),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: SizeConfig.fontSize(context, 14),
                ),
              ),
            ),
            if (activeCount > 0)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.scaleWidth(context, 8),
                  vertical: SizeConfig.scaleHeight(context, 2),
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandGreen,
                  borderRadius: BorderRadius.circular(
                    SizeConfig.scaleWidth(context, 10),
                  ),
                ),
                child: Text(
                  '$activeCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: SizeConfig.fontSize(context, 11),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chipGrid(
    List<String> items,
    Set<String> selected,
    ValueChanged<String> onToggle,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.scaleWidth(context, 4),
      ),
      child: Wrap(
        spacing: SizeConfig.scaleWidth(context, 6),
        runSpacing: SizeConfig.scaleWidth(context, 6),
        children: items.map((item) {
          final isSelected = selected.contains(item);
          return FilterChip(
            label: Text(
              item,
              style: TextStyle(
                fontSize: SizeConfig.fontSize(context, 12),
                color: isSelected ? Colors.white : null,
              ),
            ),
            selected: isSelected,
            onSelected: (_) => onToggle(item),
            selectedColor: AppColors.brandGreen,
            checkmarkColor: Colors.white,
            side: BorderSide(
              color: isSelected
                  ? AppColors.brandGreen
                  : Colors.white.withValues(alpha: 0.2),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }

  String _clientName(String clientId) {
    if (clientId == TaskController.allOption) return clientId;
    try {
      return widget.controller.clients
          .firstWhere((c) => c.clientId == clientId)
          .clientName;
    } catch (_) {
      return clientId;
    }
  }

  String _showName(String showId) {
    if (showId == TaskController.allOption) return showId;
    try {
      return widget.controller.shows
          .firstWhere((s) => s.showId == showId)
          .showName;
    } catch (_) {
      return showId;
    }
  }

  Widget _labeledChipRow(
    String label,
    List<String> items,
    String? selected,
    ValueChanged<String> onSelect, {
    String Function(String)? labelFn,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.scaleWidth(context, 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: SizeConfig.fontSize(context, 12),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 4)),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: items.map((item) {
              final isSelected = item == selected;
              final display = labelFn != null ? labelFn(item) : item;
              return Padding(
                padding: const EdgeInsets.all(3),
                child: FilterChip(
                  label: Text(
                    display,
                    style: TextStyle(
                      fontSize: SizeConfig.fontSize(context, 11),
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                  avatar: null,
                  showCheckmark: false,
                  selected: isSelected,
                  onSelected: (_) => onSelect(item),
                  selectedColor: AppColors.brandGreen,
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.brandGreen
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _textField(String key, String label) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 40 / 768,
      child: TextField(
        controller: _controllers[key],
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: SizeConfig.scaleWidth(context, 10),
            vertical: SizeConfig.scaleHeight(context, 8),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              SizeConfig.scaleWidth(context, 2),
            ),
          ),
          suffixIcon: _controllers[key]!.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    size: SizeConfig.iconSize(context, 16),
                  ),
                  onPressed: () {
                    _controllers[key]!.clear();
                    setState(() {});
                  },
                )
              : null,
        ),
        style: TextStyle(fontSize: SizeConfig.fontSize(context, 13)),
      ),
    );
  }
}
