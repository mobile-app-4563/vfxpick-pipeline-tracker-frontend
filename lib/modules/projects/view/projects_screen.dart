import 'dart:convert';
import 'dart:math' as math;

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/shot_model.dart';
import '../../../core/services/api_controller.dart';
import '../../../core/utils/excel_export_utils.dart';
import '../../../core/utils/size_config.dart';
import '../../../shared/widgets/custom_dropdown.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/dynamic_data_table.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/projects_controller.dart';

class ProjectsScreen extends StatefulWidget {
  final String moduleLabel;
  final String exportFilePrefix;

  const ProjectsScreen({
    super.key,
    this.moduleLabel = 'Projects',
    this.exportFilePrefix = 'projects',
  });

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

/// Dropdown options for the PRIORITY grid column.
const List<String> _priorityOptions = [
  'Priority 1',
  'Priority 2',
  'Priority 3',
];

class _ProjectsScreenState extends State<ProjectsScreen> {
  final List<Map<String, dynamic>> _importDraftRows = [];
  final TextEditingController _csvPasteController = TextEditingController();

  // ── Text-based filters (freeform search) ──
  String _shotIdFilter = '';
  String _startFrameFilter = '';
  String _endFrameFilter = '';
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
  String _commentsFilter = '';

  // ── Chip-based filters (multi-select from unique values) ──
  Set<String> _coordinatorChips = {};
  Set<String> _artistNameChips = {};
  Set<String> _levelOfShotChips = {};
  Set<String> _approvedByChips = {};
  Set<String> _complexityChips = {};
  Set<String> _statusChips = {};
  Set<String> _priorityChips = {};
  Set<String> _fromRotoChips = {};
  Set<String> _fromPaintChips = {};
  Set<String> _fromMmChips = {};
  Set<String> _fromCompChips = {};

  final String _importShotFilter = '';
  final String _importFrameInFilter = '';
  final String _importFrameOutFilter = '';
  final String _importSupervisorBidFilter = '';
  final String _importClientBidFilter = '';
  final String _importEtaFilter = '';
  final String _importStatusFilter = '';

  bool _isImporting = false;
  bool _isSavingImport = false;
  bool _importAutoSaved = false;
  int _lastImportedTotal = 0;
  final List<String> _importFeedback = [];
  bool _isExporting = false;
  bool _isBroadAccess = false;
  bool _isArtist = false;
  bool _canCreateClientShow = false;
  bool _canCreateShot = false;
  bool _isBulkDeleteMode = false;
  final Set<String> _selectedShotIds = {};
  bool _isDeleting = false;
  String? _roleDepartment;

  // Show/hide the spreadsheet-style cell borders on the grid (toggled via the
  // "Cell Borders" checkbox in the toolbar). On by default to match the Excel
  // template — same behavior as the Production Management module.
  bool _showCellBorders = true;

  // ── Row cache to avoid rebuilding all row Maps on every setState ──
  List<Map<String, dynamic>>? _cachedRows;
  int _cachedShotsLength = -1;
  int _cachedShotsRevision = -1;

  // ── Filtered-grid cache: filtered rows are re-computed ONLY when the shots
  //    list or any filter changes — never on page changes / unrelated builds. ──
  List<Map<String, dynamic>>? _cachedFilteredRows;
  String _filterSignature = '';

  // ── Page-change feedback: brief "Parsing…" overlay while the grid switches
  //    pages, so heavy table rebuilds are never silent. ──
  bool _isProjectGridChanging = false;
  bool _isPreviewGridChanging = false;

  // ── Import-preview cache: projected preview Maps are rebuilt ONLY when the
  //    draft rows change — never on unrelated builds (large imports used to
  //    re-materialize thousands of Maps on the UI thread every setState). ──
  List<Map<String, dynamic>>? _cachedImportPreviewRows;
  int _cachedImportPreviewLength = -1;

  void _resetImportPreviewCache() {
    _cachedImportPreviewRows = null;
    _cachedImportPreviewLength = -1;
  }

  // ── Pagination ──
  int _projectPage = 0;
  int _previewPage = 0;

  // Only 10 rows per page — matches the Production grid. The table slices
  // rows internally, so this keeps every page light (filters / sorting still
  // run over the full list, but only 10 rows are ever rendered).
  static const int _rowsPerPage = 10;

  int _totalPages(int totalRows) =>
      _rowsPerPage > 0 ? (totalRows / _rowsPerPage).ceil() : 1;

  Widget _paginationBar(
    BuildContext context,
    int currentPage,
    int totalRows,
    ValueChanged<int> onPageChanged,
  ) {
    final totalPages = _totalPages(totalRows);
    if (totalPages <= 1) return const SizedBox.shrink();
    final start = currentPage * _rowsPerPage + 1;
    final end = (start + _rowsPerPage - 1).clamp(0, totalRows);
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: SizeConfig.scaleHeight(context, 6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$start–$end of $totalRows',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(width: SizeConfig.scaleWidth(context, 4)),
          IconButton(
            icon: Icon(
              Icons.chevron_left,
              size: SizeConfig.iconSize(context, 20),
            ),
            onPressed: currentPage > 0
                ? () => onPageChanged(currentPage - 1)
                : null,
            tooltip: 'Previous page',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              size: SizeConfig.iconSize(context, 20),
            ),
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

  /// Flips the project grid page with a one-frame "Parsing…" overlay so the
  /// table rebuild is visible feedback instead of a silent freeze. The heavy
  /// work (filtering/slicing/rebuild) runs BETWEEN frames while the spinner
  /// is on screen.
  void _changeProjectPage(int page) {
    if (_isProjectGridChanging || page == _projectPage) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      // Called mid-build (DynamicDataTable internal page clamp) — defer.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _changeProjectPage(page);
      });
      return;
    }
    setState(() => _isProjectGridChanging = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _projectPage = page);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _isProjectGridChanging = false);
      });
    });
  }

  /// Same deferred page flip with spinner for the import-preview table.
  void _changePreviewPage(int page) {
    if (_isPreviewGridChanging || page == _previewPage) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
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

  /// Signature of everything that affects the main grid's filtered rows.
  /// Page changes are deliberately NOT included — the filtered list is reused
  /// across page flips, only the visible slice changes.
  String _buildShotFilterSignature(ProjectController controller) {
    String join(Set<String> s) =>
        s.isEmpty ? '' : (s.toList()..sort()).join(',');
    return [
      controller.shots.length,
      _shotIdFilter,
      _startFrameFilter,
      _endFrameFilter,
      _totalFramesFilter,
      _allocationDateFilter,
      _allocationEtaFilter,
      _startingDateFilter,
      _completeDateFilter,
      _dailyWipFilter,
      _mandaysFilter,
      _consumedMandaysFilter,
      _savedMandaysFilter,
      _approvedVersionFilter,
      _commentsFilter,
      join(_coordinatorChips),
      join(_artistNameChips),
      join(_levelOfShotChips),
      join(_approvedByChips),
      join(_complexityChips),
      join(_statusChips),
      join(_priorityChips),
      join(_fromRotoChips),
      join(_fromPaintChips),
      join(_fromMmChips),
      join(_fromCompChips),
      _isBulkDeleteMode,
    ].join('|');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRoleAccess();
    });
  }

  @override
  void dispose() {
    _csvPasteController.dispose();
    super.dispose();
  }

  Future<void> _setupRoleAccess() async {
    final auth = context.read<AuthController>();
    final user = auth.currentUser;

    _isArtist = user?.role == AppConstants.roleArtist;
    _isBroadAccess = AppConstants.broadAccessRoles.contains(user?.role);
    _roleDepartment =
        AppConstants.pipelineDepartments.contains(user?.department)
        ? user?.department
        : null;

    _canCreateClientShow = _isBroadAccess;
    _canCreateShot =
        _isBroadAccess ||
        user?.role == AppConstants.roleSupervisor ||
        user?.role == AppConstants.roleTeamLead;

    final controller = context.read<ProjectController>();
    final query = GoRouterState.of(context).uri.queryParameters;
    final departmentParam = query['department'];
    final clientIdParam = query['clientId'];
    final showIdParam = query['showId'];
    await controller.init();

    if (!_isBroadAccess && _roleDepartment != null) {
      controller.selectDepartment(_roleDepartment!);
    } else if (departmentParam != null &&
        controller.departments.contains(departmentParam)) {
      controller.selectDepartment(departmentParam);
    }

    if (clientIdParam != null &&
        controller.clients.any((c) => c.clientId == clientIdParam)) {
      await controller.selectClient(clientIdParam);
    }

    if (showIdParam != null &&
        controller.shows.any((s) => s.showId == showIdParam)) {
      await controller.selectShow(showIdParam);
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();

    if (controller.isLoading && controller.clients.isEmpty) {
      return SizedBox(
        // color: Colors.red,
        width: SizeConfig.screenWidth(context),
        height: SizeConfig.screenHeight(context),
        child: LoadingWidget(
          message: 'Loading ${widget.moduleLabel.toLowerCase()}...',
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: (_canCreateClientShow || _canCreateShot)
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: Colors.white,
              onPressed: () => _openCreateMenu(context, controller),
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            )
          : null,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: SizeConfig.scaleHeight(context, 90),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _importActions(context, controller),
                      if (_importDraftRows.isNotEmpty) ...[
                        SizedBox(height: SizeConfig.scaleHeight(context, 12)),
                        _importPreviewTable(),
                      ],
                      SizedBox(height: SizeConfig.scaleHeight(context, 20)),
                      SizedBox(
                        // height: math.max(
                        //   SizeConfig.scaleHeight(context, 260),
                        //   shotsHeight,
                        // ),
                        child: _shots(context, controller),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_isImporting)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.brandGreen,
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(context, 16)),
                    Text(
                      'Importing data...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: SizeConfig.fontSize(context, 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _importActions(BuildContext context, ProjectController controller) {
    final canImport =
        _canCreateShot &&
        controller.selectedShowId != ProjectController.allOption &&
        controller.selectedDepartment != ProjectController.allOption;

    if (!_canCreateShot) {
      return const SizedBox.shrink();
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: SizeConfig.scaleWidth(context, 12),
      runSpacing: SizeConfig.scaleHeight(context, 12),
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandGreen,
            foregroundColor: Colors.white,
            fixedSize: SizeConfig.buttonFixedSize(context, 160, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                SizeConfig.scaleWidth(context, 2),
              ),
            ),
          ),

          onPressed: _isExporting
              ? null
              : () => _exportShotsAsExcel(controller),
          icon: _isExporting
              ? SizeConfig.loadingIndicator(size: 14, stroke: 2)
              : const Icon(Icons.download_outlined),
          label: const Text('Export Excel'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            fixedSize: SizeConfig.buttonFixedSize(context, 160, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                SizeConfig.scaleWidth(context, 2),
              ),
            ),
          ),
          onPressed: _isImporting || !canImport
              ? null
              : () => _openPasteCsvDialog(controller),
          icon: const Icon(Icons.content_paste_go_outlined),
          label: const Text('Paste CSV'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            fixedSize: SizeConfig.buttonFixedSize(context, 160, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                SizeConfig.scaleWidth(context, 2),
              ),
            ),
          ),
          onPressed: _isImporting || !canImport
              ? null
              : () => _pickAndParseExcel(controller),
          icon: _isImporting
              ? SizeConfig.loadingIndicator(size: 14, stroke: 2)
              : const Icon(Icons.upload_file_outlined),
          label: const Text('Import File'),
        ),
        if (_isBulkDeleteMode) ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              fixedSize: SizeConfig.buttonFixedSize(context, 180, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  SizeConfig.scaleWidth(context, 2),
                ),
              ),
            ),
            onPressed: (_isDeleting || _selectedShotIds.isEmpty)
                ? null
                : () => _confirmBulkDelete(context, controller),
            icon: _isDeleting
                ? SizeConfig.loadingIndicator(size: 14, stroke: 2)
                : const Icon(Icons.delete_forever_outlined),
            label: Text('Delete (${_selectedShotIds.length})'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              fixedSize: SizeConfig.buttonFixedSize(context, 120, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  SizeConfig.scaleWidth(context, 2),
                ),
              ),
            ),
            onPressed: _isDeleting
                ? null
                : () {
                    setState(() {
                      _isBulkDeleteMode = false;
                      _selectedShotIds.clear();
                    });
                  },
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
          ),
        ] else
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              fixedSize: SizeConfig.buttonFixedSize(context, 160, 40),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  SizeConfig.scaleWidth(context, 2),
                ),
              ),
            ),
            onPressed: _isImporting || _isExporting || _isSavingImport
                ? null
                : () {
                    setState(() {
                      _isBulkDeleteMode = true;
                      _selectedShotIds.clear();
                    });
                  },
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Bulk Delete'),
          ),
        // SizeConfig.sizedBoxW(context, 8),
        SizedBox(
          width: SizeConfig.scaleWidth(context, 200),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: Colors.white,
              fixedSize: SizeConfig.buttonFixedSize(context, 200, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  SizeConfig.scaleWidth(context, 2),
                ),
              ),
            ),
            onPressed:
                _isSavingImport || _importDraftRows.isEmpty || _importAutoSaved
                ? null
                : () => _saveImportedRows(controller),
            icon: _isSavingImport
                ? SizeConfig.loadingIndicator(size: 14, stroke: 2)
                : Icon(
                    _importAutoSaved
                        ? Icons.check_circle_outline
                        : Icons.save_outlined,
                  ),
            label: Text(
              _importAutoSaved ? 'Saved to Server' : 'Save Imported Data',
            ),
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            fixedSize: SizeConfig.buttonFixedSize(context, 100, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                SizeConfig.scaleWidth(context, 2),
              ),
            ),
          ),
          onPressed: _isImporting || _isExporting || _isSavingImport
              ? null
              : () => _showFilterDialog(context, controller),
          icon: const Icon(Icons.filter_alt_outlined),
          label: const Text('Filters'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            fixedSize: SizeConfig.buttonFixedSize(context, 160, 40),
            backgroundColor: _showCellBorders
                ? AppColors.brandGreen.withValues(alpha: 0.12)
                : null,
            foregroundColor: _showCellBorders ? AppColors.brandGreen : null,
            side: BorderSide(
              color: _showCellBorders
                  ? AppColors.brandGreen
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                SizeConfig.scaleWidth(context, 2),
              ),
            ),
          ),
          onPressed: () => setState(() => _showCellBorders = !_showCellBorders),
          icon: Icon(
            _showCellBorders ? Icons.check : Icons.border_all,
            size: SizeConfig.iconSize(context, 18),
          ),
          label: Text(
            'Cell Borders',
            style: TextStyle(
              color: !_showCellBorders
                  ? Theme.of(context).colorScheme.onSurface
                  : AppColors.brandGreen,
            ),
          ),
        ),
      ],
    );
  }

  void _openCreateMenu(BuildContext context, ProjectController controller) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create New Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: SizeConfig.scaleHeight(context, 8),
          children: [
            if (_canCreateClientShow)
              ListTile(
                leading: const Icon(Icons.business_outlined),
                title: const Text('New Client'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _openClientDialog(context, controller);
                },
              ),
            if (_canCreateClientShow)
              ListTile(
                leading: const Icon(Icons.movie_outlined),
                title: const Text('New Show'),
                subtitle: controller.selectedClientId == null
                    ? const Text('Select a client first')
                    : null,
                enabled: controller.selectedClientId != null,
                onTap: controller.selectedClientId != null
                    ? () {
                        Navigator.pop(dialogContext);
                        _openShowDialog(context, controller);
                      }
                    : null,
              ),
            if (_canCreateShot)
              ListTile(
                leading: const Icon(Icons.add_photo_alternate_outlined),
                title: const Text('New Shot'),
                subtitle:
                    controller.selectedShowId == ProjectController.allOption
                    ? const Text('Select a specific show first')
                    : null,
                enabled:
                    controller.selectedShowId != ProjectController.allOption,
                onTap: controller.selectedShowId != ProjectController.allOption
                    ? () {
                        Navigator.pop(dialogContext);
                        _openShotDialog(context, controller);
                      }
                    : null,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openClientDialog(
    BuildContext context,
    ProjectController controller,
  ) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _ClientDialog(controller: controller),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Client created')));
    }
  }

  Future<void> _openShowDialog(
    BuildContext context,
    ProjectController controller,
  ) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _ShowFormDialog(controller: controller),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Show created')));
    }
  }

  Future<void> _showFilterDialog(
    BuildContext context,
    ProjectController controller,
  ) async {
    final result = await showDialog<_ProjectFilterResult>(
      context: context,
      builder: (ctx) => _ProjectFilterDialog(
        controller: controller,
        initialShotId: _shotIdFilter,
        initialCoordinatorChips: _coordinatorChips,
        initialStartFrame: _startFrameFilter,
        initialEndFrame: _endFrameFilter,
        initialTotalFrames: _totalFramesFilter,
        initialArtistNameChips: _artistNameChips,
        initialLevelOfShotChips: _levelOfShotChips,
        initialAllocationDate: _allocationDateFilter,
        initialAllocationEta: _allocationEtaFilter,
        initialStartingDate: _startingDateFilter,
        initialCompleteDate: _completeDateFilter,
        initialDailyWip: _dailyWipFilter,
        initialMandays: _mandaysFilter,
        initialConsumedMandays: _consumedMandaysFilter,
        initialSavedMandays: _savedMandaysFilter,
        initialApprovedVersion: _approvedVersionFilter,
        initialApprovedByChips: _approvedByChips,
        initialComments: _commentsFilter,
        initialComplexityChips: _complexityChips,
        initialStatusChips: _statusChips,
        initialPriorityChips: _priorityChips,
        initialFromRotoChips: _fromRotoChips,
        initialFromPaintChips: _fromPaintChips,
        initialFromMmChips: _fromMmChips,
        initialFromCompChips: _fromCompChips,
      ),
    );
    if (result == null || !mounted) return;

    if (result.department != null &&
        result.department != controller.selectedDepartment) {
      controller.selectDepartment(result.department);
    }
    if (result.clientId != null &&
        result.clientId != controller.selectedClientId) {
      await controller.selectClient(result.clientId);
    }
    if (result.showId != null && result.showId != controller.selectedShowId) {
      controller.selectShow(result.showId);
    }

    setState(() {
      _shotIdFilter = result.shotId;
      _coordinatorChips = result.coordinatorChips;
      _startFrameFilter = result.startFrame;
      _endFrameFilter = result.endFrame;
      _totalFramesFilter = result.totalFrames;
      _artistNameChips = result.artistNameChips;
      _levelOfShotChips = result.levelOfShotChips;
      _allocationDateFilter = result.allocationDate;
      _allocationEtaFilter = result.allocationEta;
      _startingDateFilter = result.startingDate;
      _completeDateFilter = result.completeDate;
      _dailyWipFilter = result.dailyWip;
      _mandaysFilter = result.mandays;
      _consumedMandaysFilter = result.consumedMandays;
      _savedMandaysFilter = result.savedMandays;
      _approvedVersionFilter = result.approvedVersion;
      _approvedByChips = result.approvedByChips;
      _commentsFilter = result.comments;
      _complexityChips = result.complexityChips;
      _statusChips = result.statusChips;
      _priorityChips = result.priorityChips;
      _fromRotoChips = result.fromRotoChips;
      _fromPaintChips = result.fromPaintChips;
      _fromMmChips = result.fromMmChips;
      _fromCompChips = result.fromCompChips;
    });
  }

  Widget _shots(BuildContext context, ProjectController controller) {
    if (controller.isLoading) {
      return SizedBox(
        width: SizeConfig.screenWidth(context),
        height: SizeConfig.screenHeight(context),
        child: const LoadingWidget(),
      );
    }
    if (controller.selectedDepartment == null ||
        controller.selectedShowId == null ||
        controller.shots.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.movie_outlined,
        title: 'No shots',
        description: 'Pick a department / show or create a new shot.',
      );
    }

    // ── Rebuild cache only when shots list changes ──────────────────
    if (_cachedShotsRevision != controller.shotsRevision ||
        _cachedShotsLength != controller.shots.length ||
        _cachedRows == null) {
      _cachedShotsRevision = controller.shotsRevision;
      _cachedShotsLength = controller.shots.length;
      _cachedRows = List<Map<String, dynamic>>.generate(
        controller.shots.length,
        (index) {
          final shot = controller.shots[index];
          return {
            'sno': index + 1,
            'shotId': shot.shotCode,
            'coordinator': shot.coordinator ?? '-',
            'clientName': shot.clientName ?? '-',
            'showName': shot.showName ?? '-',
            'startFrame': shot.frameIn,
            'endFrame': shot.frameOut,
            'totalFrames': shot.totalFrames > 0
                ? shot.totalFrames
                : (shot.frameOut - shot.frameIn + 1),
            'artistName': shot.artistName ?? '-',
            'levelOfShot': shot.levelOfShot ?? '-',
            'allocationDate': _fmtDate(shot.allocationDate),
            'allocationEta': _fmtDate(shot.allocationEta),
            'startingDate': _fmtDate(shot.startingDate),
            'completeDate': _fmtDate(shot.completeDate),
            'dailyWip': shot.dailyWip.toStringAsFixed(1),
            'mandays': shot.mandays.toStringAsFixed(1),
            'consumedMandays': shot.consumedMandays.toStringAsFixed(1),
            'savedMandays': shot.savedMandays.toStringAsFixed(1),
            'approvedVersion': shot.approvedVersion ?? '-',
            'approvedBy': shot.approvedBy ?? '-',
            'comments': shot.comments ?? '-',
            'complexity': shot.complexity ?? '-',
            'department': shot.department,
            'fromRoto': shot.fromRoto ?? '-',
            'fromPaint': shot.fromPaint ?? '-',
            'fromMm': shot.fromMm ?? '-',
            'fromComp': shot.fromComp ?? '-',
            'status': shot.status,
            'priority': shot.priority ?? '',
            'shot': shot,
          };
        },
        growable: false,
      );
    }

    final cachedRows = _cachedRows!;

    // ── Filter ONCE from the row cache; the result is cached and reused
    //    across page flips and unrelated rebuilds (page changes only re-slice
    //    the cached filtered list — no re-parsing, no O(N) filter per build). ──
    final signature =
        '${_buildShotFilterSignature(controller)}#rev${controller.shotsRevision}';
    if (_filterSignature != signature || _cachedFilteredRows == null) {
      _filterSignature = signature;
      _cachedFilteredRows = cachedRows
          .where((row) {
            bool contains(String key, String query) {
              if (query.trim().isEmpty) return true;
              return (row[key] ?? '').toString().toLowerCase().contains(
                query.trim().toLowerCase(),
              );
            }

            bool chipMatch(String key, Set<String> selected) {
              if (selected.isEmpty) return true;
              return selected.contains((row[key] ?? '').toString());
            }

            return contains('shotId', _shotIdFilter) &&
                chipMatch('coordinator', _coordinatorChips) &&
                contains('startFrame', _startFrameFilter) &&
                contains('endFrame', _endFrameFilter) &&
                contains('totalFrames', _totalFramesFilter) &&
                chipMatch('artistName', _artistNameChips) &&
                chipMatch('levelOfShot', _levelOfShotChips) &&
                contains('allocationDate', _allocationDateFilter) &&
                contains('allocationEta', _allocationEtaFilter) &&
                contains('startingDate', _startingDateFilter) &&
                contains('completeDate', _completeDateFilter) &&
                contains('dailyWip', _dailyWipFilter) &&
                contains('mandays', _mandaysFilter) &&
                contains('consumedMandays', _consumedMandaysFilter) &&
                contains('savedMandays', _savedMandaysFilter) &&
                contains('approvedVersion', _approvedVersionFilter) &&
                chipMatch('approvedBy', _approvedByChips) &&
                contains('comments', _commentsFilter) &&
                chipMatch('complexity', _complexityChips) &&
                chipMatch('status', _statusChips) &&
                chipMatch('priority', _priorityChips) &&
                chipMatch('fromRoto', _fromRotoChips) &&
                chipMatch('fromPaint', _fromPaintChips) &&
                chipMatch('fromMm', _fromMmChips) &&
                chipMatch('fromComp', _fromCompChips);
          })
          .toList(growable: false);

      // Bulk-delete selection state (recomputed only when the cache rebuilds)
      for (final row in _cachedFilteredRows!) {
        row['select'] = _selectedShotIds.contains(
          (row['shot'] as ShotModel).shotId,
        );
      }
    }

    final filteredRows = _cachedFilteredRows!;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GlassContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _paginationBar(
                context,
                _projectPage,
                filteredRows.length,
                _changeProjectPage,
              ),
              _withGridParsingOverlay(
                isLoading: _isProjectGridChanging,
                child: DynamicDataTable(
                  currentPage: _projectPage,
                  onPageChanged: _changeProjectPage,
                  rowsPerPage: _rowsPerPage,
                  minColumnWidth: SizeConfig.scaleWidth(context, 40),
                  columnSpacing: SizeConfig.scaleWidth(context, 30),
                  dataRowMinHeight:
                      MediaQuery.of(context).size.height * 48 / 768,
                  dataRowMaxHeight:
                      MediaQuery.of(context).size.height * 62 / 768,
                  showCellBorders: _showCellBorders,
                  // frozenColumnCount: _isBulkDeleteMode ? 6 : 5,
                  fields: [
                    if (_isBulkDeleteMode)
                      DynamicTableField(
                        key: 'select',
                        label: '',
                        width: SizeConfig.scaleWidth(context, 48),
                        filterRequired: false,
                        builder: (context, value, row, rowIndex) {
                          final shot = row['shot'] as ShotModel;
                          final isSelected = _selectedShotIds.contains(
                            shot.shotId,
                          );
                          return Checkbox(
                            value: isSelected,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedShotIds.add(shot.shotId);
                                } else {
                                  _selectedShotIds.remove(shot.shotId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    DynamicTableField(
                      key: 'sno',
                      label: 'S.No',
                      width: SizeConfig.scaleWidth(context, 40),
                      filterRequired: false,
                      numeric: true,
                    ),
                    DynamicTableField(
                      key: 'shotId',
                      label: 'Shot ID',
                      width: SizeConfig.scaleWidth(context, 140),
                    ),
                    DynamicTableField(
                      key: 'coordinator',
                      label: 'Coordinator',
                      width: SizeConfig.scaleWidth(context, 110),
                    ),
                    DynamicTableField(
                      key: 'clientName',
                      label: 'Client',
                      width: SizeConfig.scaleWidth(context, 110),
                    ),
                    DynamicTableField(
                      key: 'showName',
                      label: 'Show',
                      width: SizeConfig.scaleWidth(context, 110),
                    ),
                    DynamicTableField(
                      key: 'startFrame',
                      label: 'Start Frame',
                      width: SizeConfig.scaleWidth(context, 90),
                      numeric: true,
                    ),
                    DynamicTableField(
                      key: 'endFrame',
                      label: 'End Frame',
                      width: SizeConfig.scaleWidth(context, 90),
                      numeric: true,
                    ),
                    DynamicTableField(
                      key: 'totalFrames',
                      label: 'Total Frames',
                      width: SizeConfig.scaleWidth(context, 95),
                      numeric: true,
                    ),
                    DynamicTableField(
                      key: 'artistName',
                      label: 'Artist Name',
                      width: SizeConfig.scaleWidth(context, 120),
                    ),
                    DynamicTableField(
                      key: 'levelOfShot',
                      label: 'Level of Shot',
                      width: SizeConfig.scaleWidth(context, 110),
                    ),
                    DynamicTableField(
                      key: 'allocationDate',
                      label: 'Allocation Date',
                      width: SizeConfig.scaleWidth(context, 120),
                    ),
                    DynamicTableField(
                      key: 'allocationEta',
                      label: 'Allocation ETA',
                      width: SizeConfig.scaleWidth(context, 120),
                    ),
                    DynamicTableField(
                      key: 'startingDate',
                      label: 'Starting Date',
                      width: SizeConfig.scaleWidth(context, 120),
                    ),
                    DynamicTableField(
                      key: 'completeDate',
                      label: 'Complete Date',
                      width: SizeConfig.scaleWidth(context, 120),
                    ),
                    DynamicTableField(
                      key: 'dailyWip',
                      label: 'Daily WIP %',
                      width: SizeConfig.scaleWidth(context, 100),
                      numeric: true,
                    ),
                    DynamicTableField(
                      key: 'mandays',
                      label: 'Mandays',
                      width: SizeConfig.scaleWidth(context, 90),
                      numeric: true,
                    ),
                    DynamicTableField(
                      key: 'consumedMandays',
                      label: 'Consumed Mandays',
                      width: SizeConfig.scaleWidth(context, 130),
                      numeric: true,
                    ),
                    DynamicTableField(
                      key: 'savedMandays',
                      label: 'Saved Mandays',
                      width: SizeConfig.scaleWidth(context, 115),
                      numeric: true,
                    ),
                    DynamicTableField(
                      key: 'approvedVersion',
                      label: 'Approved Version',
                      width: SizeConfig.scaleWidth(context, 130),
                    ),
                    DynamicTableField(
                      key: 'approvedBy',
                      label: 'Approved By',
                      width: SizeConfig.scaleWidth(context, 120),
                    ),
                    DynamicTableField(
                      key: 'comments',
                      label: 'Comments',
                      width: SizeConfig.scaleWidth(context, 180),
                    ),
                    DynamicTableField(
                      key: 'complexity',
                      label: 'Complexity',
                      width: SizeConfig.scaleWidth(context, 110),
                    ),
                    DynamicTableField(
                      key: 'department',
                      label: 'Department',
                      width: SizeConfig.scaleWidth(context, 100),
                    ),
                    DynamicTableField(
                      key: 'fromRoto',
                      label: 'From Roto',
                      width: SizeConfig.scaleWidth(context, 120),
                    ),
                    DynamicTableField(
                      key: 'fromPaint',
                      label: 'From Paint',
                      width: SizeConfig.scaleWidth(context, 120),
                    ),
                    DynamicTableField(
                      key: 'fromMm',
                      label: 'From MM',
                      width: SizeConfig.scaleWidth(context, 110),
                    ),
                    DynamicTableField(
                      key: 'fromComp',
                      label: 'From Comp',
                      width: SizeConfig.scaleWidth(context, 110),
                    ),
                    DynamicTableField(
                      key: 'status',
                      label: 'Status',
                      width: SizeConfig.scaleWidth(context, 180),
                      builder: (context, value, row, rowIndex) {
                        final shot = row['shot'] as ShotModel;
                        return SingleChildScrollView(
                          child: CustomDropdown<String>(
                            compact: true,
                            labelText: 'Status',
                            value: AppConstants.shotStatuses.contains(value)
                                ? value as String
                                : null,
                            items: AppConstants.shotStatuses,
                            itemToString: (st) => st,
                            onChanged: _isArtist
                                ? null
                                : (v) {
                                    if (v != null) {
                                      controller.updateStatus(shot.shotId, v);
                                    }
                                  },
                          ),
                        );
                      },
                    ),
                    DynamicTableField(
                      key: 'priority',
                      label: 'Priority',
                      width: SizeConfig.scaleWidth(context, 120),
                      builder: (context, value, row, rowIndex) {
                        final shot = row['shot'] as ShotModel;
                        final current = value == null ? '' : value.toString();
                        return SingleChildScrollView(
                          child: CustomDropdown<String>(
                            compact: true,
                            labelText: 'Priority',
                            value: _priorityOptions.contains(current)
                                ? current
                                : null,
                            items: _priorityOptions,
                            itemToString: (v) => v,
                            onChanged: _isArtist
                                ? null
                                : (v) {
                                    if (v != null) {
                                      controller.updatePriority(shot.shotId, v);
                                    }
                                  },
                          ),
                        );
                      },
                    ),
                    DynamicTableField(
                      key: 'actions',
                      filterRequired: false,
                      label: 'Actions',
                      width: SizeConfig.scaleWidth(context, 110),
                      builder: (context, value, row, rowIndex) {
                        final shot = row['shot'] as ShotModel;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit shot',
                              onPressed: _canCreateShot
                                  ? () => _openShotDialog(
                                      context,
                                      controller,
                                      shot: shot,
                                    )
                                  : null,
                              icon: Icon(
                                Icons.edit_outlined,
                                size: SizeConfig.iconSize(context, 18),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete shot',
                              onPressed: _isDeleting
                                  ? null
                                  : () => _confirmDeleteShot(
                                      context,
                                      controller,
                                      shot,
                                    ),
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.red,
                              ),
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
                        case 'shotId':
                          _shotIdFilter = v;
                          break;
                        case 'coordinator':
                          _coordinatorChips = v.isEmpty ? {} : {v};
                          break;
                        case 'startFrame':
                          _startFrameFilter = v;
                          break;
                        case 'endFrame':
                          _endFrameFilter = v;
                          break;
                        case 'totalFrames':
                          _totalFramesFilter = v;
                          break;
                        case 'artistName':
                          _artistNameChips = v.isEmpty ? {} : {v};
                          break;
                        case 'levelOfShot':
                          _levelOfShotChips = v.isEmpty ? {} : {v};
                          break;
                        case 'allocationDate':
                          _allocationDateFilter = v;
                          break;
                        case 'allocationEta':
                          _allocationEtaFilter = v;
                          break;
                        case 'startingDate':
                          _startingDateFilter = v;
                          break;
                        case 'completeDate':
                          _completeDateFilter = v;
                          break;
                        case 'dailyWip':
                          _dailyWipFilter = v;
                          break;
                        case 'mandays':
                          _mandaysFilter = v;
                          break;
                        case 'consumedMandays':
                          _consumedMandaysFilter = v;
                          break;
                        case 'savedMandays':
                          _savedMandaysFilter = v;
                          break;
                        case 'approvedVersion':
                          _approvedVersionFilter = v;
                          break;
                        case 'approvedBy':
                          _approvedByChips = v.isEmpty ? {} : {v};
                          break;
                        case 'comments':
                          _commentsFilter = v;
                          break;
                        case 'complexity':
                          _complexityChips = v.isEmpty ? {} : {v};
                          break;
                        case 'status':
                          _statusChips = v.isEmpty ? {} : {v};
                          break;
                        case 'priority':
                          _priorityChips = v.isEmpty ? {} : {v};
                          break;
                        case 'fromRoto':
                          _fromRotoChips = v.isEmpty ? {} : {v};
                          break;
                        case 'fromPaint':
                          _fromPaintChips = v.isEmpty ? {} : {v};
                          break;
                        case 'fromMm':
                          _fromMmChips = v.isEmpty ? {} : {v};
                          break;
                        case 'fromComp':
                          _fromCompChips = v.isEmpty ? {} : {v};
                          break;
                        default:
                          break;
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the display Maps for the import preview. The result is cached and
  /// invalidated only when `_importDraftRows` changes, so unrelated setState
  /// calls never re-project thousands of rows on the UI thread.
  List<Map<String, dynamic>> _buildImportPreviewRows() {
    if (_cachedImportPreviewLength == _importDraftRows.length &&
        _cachedImportPreviewRows != null) {
      return _cachedImportPreviewRows!;
    }
    final rows = List<Map<String, dynamic>>.generate(
      _importDraftRows.length,
      (index) => _projectPreviewRowT(_importDraftRows[index]),
    );
    _cachedImportPreviewLength = _importDraftRows.length;
    _cachedImportPreviewRows = rows;
    return rows;
  }

  Widget _importPreviewTable() {
    final previewRows = _buildImportPreviewRows();

    // Filtering disabled by default — all _import*Filter vars are ''.
    // Skip the O(N) filter copy entirely when nothing is active.
    final hasActiveImportFilter =
        _importShotFilter.trim().isNotEmpty ||
        _importFrameInFilter.trim().isNotEmpty ||
        _importFrameOutFilter.trim().isNotEmpty ||
        _importSupervisorBidFilter.trim().isNotEmpty ||
        _importClientBidFilter.trim().isNotEmpty ||
        _importEtaFilter.trim().isNotEmpty ||
        _importStatusFilter.trim().isNotEmpty;
    final filteredPreviewRows = hasActiveImportFilter
        ? previewRows
              .where((row) {
                bool contains(String key, String query) {
                  if (query.trim().isEmpty) return true;
                  return (row[key] ?? '').toString().toLowerCase().contains(
                    query.trim().toLowerCase(),
                  );
                }

                return contains('shotCode', _importShotFilter) &&
                    contains('frameIn', _importFrameInFilter) &&
                    contains('frameOut', _importFrameOutFilter) &&
                    contains('supervisorBid', _importSupervisorBidFilter) &&
                    contains('clientBid', _importClientBidFilter) &&
                    contains('clientEta', _importEtaFilter) &&
                    contains('status', _importStatusFilter);
              })
              .toList(growable: false)
        : previewRows;

    return GlassContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: SizeConfig.paddingOnly(
              context,
              left: 10,
              top: 10,
              right: 10,
            ),
            child: Text(
              _lastImportedTotal > _importDraftRows.length
                  ? 'Imported Preview ($_lastImportedTotal rows — showing first ${_importDraftRows.length})'
                  : 'Imported Preview (${_importDraftRows.length} rows)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          _paginationBar(
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
              rowsPerPage: _rowsPerPage,
              columnSpacing: SizeConfig.scaleWidth(context, 30),
              padding: SizeConfig.paddingSymmetric(
                context,
                horizontal: 4,
                vertical: 4,
              ),
              showCellBorders: true,
              // headingRowHeight: MediaQuery.of(context).size.height * 40 / 768,
              dataRowMinHeight: MediaQuery.of(context).size.height * 40 / 768,
              dataRowMaxHeight: MediaQuery.of(context).size.height * 52 / 768,
              // frozenColumnCount: 5,
              fields: [
                DynamicTableField(
                  key: 'shotCode',
                  label: 'Shot',
                  width: SizeConfig.scaleWidth(context, 130),
                ),
                DynamicTableField(
                  key: 'frameIn',
                  label: 'Frame In',
                  width: SizeConfig.scaleWidth(context, 90),
                ),
                DynamicTableField(
                  key: 'frameOut',
                  label: 'Frame Out',
                  width: SizeConfig.scaleWidth(context, 90),
                ),
                DynamicTableField(
                  key: 'totalFrames',
                  label: 'Total',
                  width: SizeConfig.scaleWidth(context, 80),
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
                  key: 'allocationDate',
                  label: 'Alloc Date',
                  width: SizeConfig.scaleWidth(context, 100),
                ),
                DynamicTableField(
                  key: 'allocationEta',
                  label: 'Alloc ETA',
                  width: SizeConfig.scaleWidth(context, 100),
                ),
                DynamicTableField(
                  key: 'startingDate',
                  label: 'Start Date',
                  width: SizeConfig.scaleWidth(context, 100),
                ),
                DynamicTableField(
                  key: 'completeDate',
                  label: 'Complete',
                  width: SizeConfig.scaleWidth(context, 100),
                ),
                DynamicTableField(
                  key: 'dailyWip',
                  label: 'WIP %',
                  width: SizeConfig.scaleWidth(context, 80),
                ),
                DynamicTableField(
                  key: 'mandays',
                  label: 'Mandays',
                  width: SizeConfig.scaleWidth(context, 80),
                ),
                DynamicTableField(
                  key: 'consumedMandays',
                  label: 'Consumed',
                  width: SizeConfig.scaleWidth(context, 90),
                ),
                DynamicTableField(
                  key: 'savedMandays',
                  label: 'Saved',
                  width: SizeConfig.scaleWidth(context, 80),
                ),
                DynamicTableField(
                  key: 'supervisorBid',
                  label: 'Sup Bid',
                  width: SizeConfig.scaleWidth(context, 90),
                ),
                DynamicTableField(
                  key: 'clientBid',
                  label: 'Cli Bid',
                  width: SizeConfig.scaleWidth(context, 90),
                ),
                DynamicTableField(
                  key: 'clientEta',
                  label: 'ETA',
                  width: SizeConfig.scaleWidth(context, 100),
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
                  width: SizeConfig.scaleWidth(context, 130),
                ),
                DynamicTableField(
                  key: 'complexity',
                  label: 'Complexity',
                  width: SizeConfig.scaleWidth(context, 100),
                ),
                DynamicTableField(
                  key: 'notes',
                  label: 'Notes',
                  width: SizeConfig.scaleWidth(context, 130),
                ),
                DynamicTableField(
                  key: 'status',
                  label: 'Status',
                  width: SizeConfig.scaleWidth(context, 130),
                ),
                DynamicTableField(
                  key: 'priority',
                  label: 'Priority',
                  width: SizeConfig.scaleWidth(context, 100),
                ),
                DynamicTableField(
                  key: 'fromRoto',
                  label: 'Roto',
                  width: SizeConfig.scaleWidth(context, 100),
                ),
                DynamicTableField(
                  key: 'fromPaint',
                  label: 'Paint',
                  width: SizeConfig.scaleWidth(context, 100),
                ),
                DynamicTableField(
                  key: 'fromMm',
                  label: 'MM',
                  width: SizeConfig.scaleWidth(context, 80),
                ),
                DynamicTableField(
                  key: 'fromComp',
                  label: 'Comp',
                  width: SizeConfig.scaleWidth(context, 80),
                ),
              ],
              rows: filteredPreviewRows,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndParseExcel(ProjectController controller) async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'xlsm', 'xlsb', 'ods', 'csv'],
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (bytes == null || bytes.isEmpty) {
        return;
      }
      final extension =
          ((file?.extension ?? '').trim().isNotEmpty
                  ? file!.extension!
                  : file?.name.split('.').last ?? '')
              .toLowerCase();

      // Heavy decode + parse + API upload all happen in a background isolate.
      // Only a compact summary + capped preview come back to the UI thread, so
      // large files never block the UI or transfer thousands of row Maps.
      final outcome =
          await compute(_parseAndSaveImportInIsolate, <String, dynamic>{
            'bytes': bytes,
            'extension': extension,
            'showId': controller.selectedShowId ?? '',
            'department': controller.selectedDepartment ?? '',
            'shotStatuses': AppConstants.shotStatuses,
            'baseUrl': ApiConstants.baseUrl,
            'endpoint': ApiConstants.projectShotsBulkUpsert,
            'token': ApiController.instance.getToken(),
          });

      if (!mounted) return;

      // Refresh the grid ONCE with all the newly-saved rows (instead of after
      // every 100-row chunk, which used to rebuild the whole table repeatedly).
      await controller.loadShots();
      if (!mounted) return;

      final total = (outcome['total'] as int?) ?? 0;
      final created = (outcome['created'] as int?) ?? 0;
      final updated = (outcome['updated'] as int?) ?? 0;
      final errors = ((outcome['errors'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false);
      final notes = ((outcome['notes'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false);
      final preview = ((outcome['preview'] as List<dynamic>?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);

      setState(() {
        _importAutoSaved = true;
        _lastImportedTotal = total;
        _previewPage = 0;
        _resetImportPreviewCache();
        _importDraftRows
          ..clear()
          ..addAll(preview);
        _importFeedback
          ..clear()
          ..addAll(errors)
          ..addAll(notes);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved $total rows to the server '
            '(created: $created, updated: $updated, errors: ${errors.length})',
          ),
        ),
      );
      _showImportFeedback();
    } on UnsupportedError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Unsupported file')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _openPasteCsvDialog(ProjectController controller) async {
    _csvPasteController.clear();
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paste CSV Data'),
        content: SizedBox(
          width: SizeConfig.screenWidth(dialogContext) < 700
              ? SizeConfig.width(dialogContext, 0.92)
              : SizeConfig.scaleWidth(dialogContext, 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste CSV data. Any header format is accepted; columns are auto-mapped.',
                style: TextStyle(fontSize: SizeConfig.fontSize(context, 12)),
              ),
              SizedBox(height: SizeConfig.scaleHeight(context, 10)),
              TextField(
                controller: _csvPasteController,
                minLines: SizeConfig.deviceValue(
                  context,
                  mobile: 6,
                  desktop: 8,
                ),
                maxLines: SizeConfig.deviceValue(
                  context,
                  mobile: 10,
                  desktop: 14,
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText:
                      'Shot ID,Frame In,Frame Out,Supervisor Bid,Client Bid,ETA,Status,Notes',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (shouldImport != true) {
      return;
    }

    setState(() => _isImporting = true);
    try {
      // Parse the pasted CSV in a background isolate so the UI never janks.
      final rows = await compute(_parseCsvTextInIsolate, <String, dynamic>{
        'text': _csvPasteController.text,
        'showId': controller.selectedShowId ?? '',
        'department': controller.selectedDepartment ?? '',
        'shotStatuses': AppConstants.shotStatuses,
      });
      if (!mounted) return;
      setState(() {
        _importAutoSaved = false;
        _lastImportedTotal = rows.length;
        _previewPage = 0;
        _resetImportPreviewCache();
        _importDraftRows
          ..clear()
          ..addAll(rows);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${rows.length} rows for review')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV paste failed: $e')));
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _exportShotsAsExcel(ProjectController controller) async {
    final shots = controller.shots;
    if (shots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rows available to export.')),
      );
      return;
    }

    const totalCols = 28;
    const lastCol = totalCols - 1;

    setState(() => _isExporting = true);
    try {
      final excel = Excel.createExcel();
      final sheetName = excel.getDefaultSheet() ?? 'Shots';
      final sheet = excel[sheetName];
      final titleStyle = ExcelExportUtils.titleCellStyle();
      final labelStyle = ExcelExportUtils.metaLabelStyle();
      final valueStyle = ExcelExportUtils.metaValueStyle();
      final headerStyle = ExcelExportUtils.tableHeaderStyle();
      final dataStyle = ExcelExportUtils.dataCellStyle();

      final totalMandays = shots.fold<double>(0, (s, r) => s + r.mandays);
      final dept = controller.selectedDepartment ?? 'All';
      final client = controller.selectedClientId == ProjectController.allOption
          ? 'All'
          : (controller.clients
                .firstWhere(
                  (c) => c.clientId == controller.selectedClientId,
                  orElse: () => controller.clients.first,
                )
                .clientName);
      final show = controller.selectedShowId == ProjectController.allOption
          ? 'All'
          : (controller.shows
                .firstWhere(
                  (s) => s.showId == controller.selectedShowId,
                  orElse: () => controller.shows.first,
                )
                .showName);

      // Column widths
      ExcelExportUtils.setColumnWidths(sheet, [
        8,
        14,
        14,
        14,
        14,
        12,
        12,
        12,
        14,
        14,
        14,
        14,
        14,
        14,
        12,
        10,
        14,
        12,
        14,
        14,
        18,
        12,
        14,
        12,
        12,
        10,
        10,
        14,
      ]);

      // ---- Title row ----
      final titleRow = sheet.maxRows;
      final titleCells = List<CellValue>.filled(totalCols, TextCellValue(''));
      titleCells[0] = TextCellValue('Shots Export');
      sheet.appendRow(titleCells);
      ExcelExportUtils.mergeRowAcross(
        sheet,
        rowIndex: titleRow,
        fromCol: 0,
        toCol: lastCol,
      );
      ExcelExportUtils.styleRow(
        sheet,
        rowIndex: titleRow,
        fromCol: 0,
        toCol: lastCol,
        style: titleStyle,
      );
      ExcelExportUtils.setRowHeight(sheet, titleRow, 34);

      // spacer
      sheet.appendRow(List<CellValue>.filled(totalCols, TextCellValue('')));

      // ---- Metadata label row ----
      final metaLabelRow = sheet.maxRows;
      final metaLabels = List<CellValue>.filled(totalCols, TextCellValue(''));
      metaLabels[0] = TextCellValue('DEPARTMENT');
      metaLabels[1] = TextCellValue('CLIENT');
      metaLabels[2] = TextCellValue('SHOW');
      metaLabels[3] = TextCellValue('TOTAL SHOTS');
      metaLabels[4] = TextCellValue('TOTAL MANDAYS');
      sheet.appendRow(metaLabels);
      ExcelExportUtils.styleRow(
        sheet,
        rowIndex: metaLabelRow,
        fromCol: 0,
        toCol: lastCol,
        style: labelStyle,
      );
      ExcelExportUtils.setRowHeight(sheet, metaLabelRow, 26);

      // ---- Metadata value row ----
      final metaValueRow = sheet.maxRows;
      final metaValues = List<CellValue>.filled(totalCols, TextCellValue(''));
      metaValues[0] = TextCellValue(dept);
      metaValues[1] = TextCellValue(client);
      metaValues[2] = TextCellValue(show);
      metaValues[3] = IntCellValue(shots.length);
      metaValues[4] = DoubleCellValue(totalMandays);
      sheet.appendRow(metaValues);
      ExcelExportUtils.styleRow(
        sheet,
        rowIndex: metaValueRow,
        fromCol: 0,
        toCol: lastCol,
        style: valueStyle,
      );
      ExcelExportUtils.setRowHeight(sheet, metaValueRow, 26);

      // spacer
      sheet.appendRow(List<CellValue>.filled(totalCols, TextCellValue('')));

      // ---- Table header row ----
      final headerRow = sheet.maxRows;
      sheet.appendRow([
        TextCellValue('S.No'),
        TextCellValue('Coordinator'),
        TextCellValue('Client'),
        TextCellValue('Show'),
        TextCellValue('Shot ID'),
        TextCellValue('Start Frame'),
        TextCellValue('End Frame'),
        TextCellValue('Total Frames'),
        TextCellValue('Artist Name'),
        TextCellValue('Level of Shot'),
        TextCellValue('Allocation Date'),
        TextCellValue('Allocation ETA'),
        TextCellValue('Starting Date'),
        TextCellValue('Complete Date'),
        TextCellValue('Daily WIP %'),
        TextCellValue('Mandays'),
        TextCellValue('Consumed Mandays'),
        TextCellValue('Saved Mandays'),
        TextCellValue('Approved Version'),
        TextCellValue('Approved By'),
        TextCellValue('Comments'),
        TextCellValue('Complexity'),
        TextCellValue('Department'),
        TextCellValue('From Roto'),
        TextCellValue('From Paint'),
        TextCellValue('From MM'),
        TextCellValue('From Comp'),
        TextCellValue('Status'),
        TextCellValue('Priority'),
      ]);
      ExcelExportUtils.styleRow(
        sheet,
        rowIndex: headerRow,
        fromCol: 0,
        toCol: lastCol,
        style: headerStyle,
      );
      ExcelExportUtils.setRowHeight(sheet, headerRow, 26);

      // ---- Data rows ----
      for (var i = 0; i < shots.length; i++) {
        final shot = shots[i];
        final totalFrames = shot.totalFrames > 0
            ? shot.totalFrames
            : (shot.frameOut - shot.frameIn + 1);
        final dataRowIndex = sheet.maxRows;
        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(shot.coordinator ?? '-'),
          TextCellValue(shot.clientName ?? '-'),
          TextCellValue(shot.showName ?? '-'),
          TextCellValue(shot.shotCode),
          IntCellValue(shot.frameIn),
          IntCellValue(shot.frameOut),
          IntCellValue(totalFrames),
          TextCellValue(shot.artistName ?? '-'),
          TextCellValue(shot.levelOfShot ?? '-'),
          TextCellValue(ExcelExportUtils.formatDate(shot.allocationDate)),
          TextCellValue(ExcelExportUtils.formatDate(shot.allocationEta)),
          TextCellValue(ExcelExportUtils.formatDate(shot.startingDate)),
          TextCellValue(ExcelExportUtils.formatDate(shot.completeDate)),
          DoubleCellValue(shot.dailyWip),
          DoubleCellValue(shot.mandays),
          DoubleCellValue(shot.consumedMandays),
          DoubleCellValue(shot.savedMandays),
          TextCellValue(shot.approvedVersion ?? '-'),
          TextCellValue(shot.approvedBy ?? '-'),
          TextCellValue(shot.comments ?? '-'),
          TextCellValue(shot.complexity ?? '-'),
          TextCellValue(shot.department),
          TextCellValue(shot.fromRoto ?? '-'),
          TextCellValue(shot.fromPaint ?? '-'),
          TextCellValue(shot.fromMm ?? '-'),
          TextCellValue(shot.fromComp ?? '-'),
          TextCellValue(shot.status),
          TextCellValue(shot.priority ?? '-'),
        ]);
        ExcelExportUtils.styleRow(
          sheet,
          rowIndex: dataRowIndex,
          fromCol: 0,
          toCol: lastCol,
          style: dataStyle,
        );
        ExcelExportUtils.setRowHeight(sheet, dataRowIndex, 26);
      }

      final bytes = excel.encode();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Unable to generate Excel file');
      }

      final fileName = ExcelExportUtils.buildExportFileName(
        prefix: 'shots_export',
        department: controller.selectedDepartment,
        month: DateTime.now().month,
        year: DateTime.now().year,
      );
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

  Future<void> _saveImportedRows(ProjectController controller) async {
    setState(() {
      _isSavingImport = true;
      _importAutoSaved = false;
    });
    _importFeedback.clear();
    const chunkSize = 100; // send in batches to avoid huge JSON payloads
    var totalCreated = 0;
    var totalUpdated = 0;
    var totalErrors = 0;
    var failed = false;

    try {
      for (var i = 0; i < _importDraftRows.length; i += chunkSize) {
        final end = (i + chunkSize).clamp(0, _importDraftRows.length);
        final chunk = _importDraftRows.sublist(i, end);
        final batchLabel = '${i + 1}-${math.min(end, _importDraftRows.length)}';
        // reload:false → no full network refetch + grid rebuild after every
        // chunk (that was the main source of UI jank during big imports).
        final response = await controller.bulkUpsertShots(chunk, reload: false);

        if (!mounted) return;

        if (response == null) {
          final message =
              controller.error ?? 'Unable to save batch $batchLabel';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          failed = true;
          break;
        }

        totalCreated += (response['created'] as int?) ?? 0;
        totalUpdated += (response['updated'] as int?) ?? 0;
        final errs = (response['errors'] as List<dynamic>?) ?? const [];
        final notes = (response['notes'] as List<dynamic>?) ?? const [];
        totalErrors += errs.length;
        _importFeedback.addAll(errs.map((e) => e.toString()));
        _importFeedback.addAll(notes.map((e) => e.toString()));

        // Update progress on every batch
        setState(() {});

        if (mounted && i + chunkSize < _importDraftRows.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Saved batch $batchLabel… ($totalCreated created, $totalUpdated updated so far)',
              ),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }

      // One single grid refresh AFTER all chunks complete (not per chunk).
      if (!failed) {
        await controller.loadShots();
        if (!mounted) return;
      }

      if (!failed && mounted) {
        setState(() {
          _importDraftRows.clear();
          _resetImportPreviewCache();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import complete. Created: $totalCreated, Updated: $totalUpdated, Errors: $totalErrors',
            ),
          ),
        );
      }
      if (mounted) _showImportFeedback();
    } finally {
      if (mounted) setState(() => _isSavingImport = false);
    }
  }

  /// Shows the per-row feedback (warnings / auto-created users) from the last
  /// import so the user can see exactly why some cells may be empty.
  void _showImportFeedback() {
    if (_importFeedback.isEmpty || !mounted) return;
    final items = _importFeedback.length > 12
        ? <String>[
            ..._importFeedback.take(12),
            '… and ${_importFeedback.length - 12} more',
          ]
        : List<String>.from(_importFeedback);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import feedback'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(items[i], style: const TextStyle(fontSize: 13)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime? d) => d == null
      ? '—'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _confirmDeleteShot(
    BuildContext context,
    ProjectController controller,
    ShotModel shot,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Shot'),
        content: Text(
          'Are you sure you want to delete shot '
          '"${shot.shotCode}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      final error = await controller.deleteShot(shot.shotId);
      if (!context.mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $error')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shot "${shot.shotCode}" deleted.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _confirmBulkDelete(
    BuildContext context,
    ProjectController controller,
  ) async {
    final count = _selectedShotIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Delete Shots'),
        content: Text(
          'Are you sure you want to delete $count selected shot(s)? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      final shotIds = _selectedShotIds.toList();
      final error = await controller.bulkDeleteShots(shotIds);
      if (!context.mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Bulk delete failed: $error')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$count shot(s) deleted.')));
        setState(() {
          _isBulkDeleteMode = false;
          _selectedShotIds.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _openShotDialog(
    BuildContext context,
    ProjectController controller, {
    ShotModel? shot,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _ShotDialog(controller: controller, shot: shot),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Shot saved')));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Top-level import-parsing helpers (usable from isolates via compute())
// ═══════════════════════════════════════════════════════════════════════════════

String _normalizeHeaderT(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll(' ', '_')
      .replaceAll('-', '_')
      .replaceAll('.', '');
}

String _sanitizeHeaderKeyT(String input) {
  return input.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Words that identify an import header cell.  Used to locate the real header
/// row in department templates that put a title / spacer above the column
/// headers (e.g. the Roto header-requirement template).
const Set<String> _importHeaderSignalWords = {
  's_no',
  'sno',
  'coordinator',
  'coord',
  'client',
  'show',
  'shot',
  'frame',
  'total',
  'artist',
  'level',
  'allocation',
  'eta',
  'wip',
  'manday',
  'consumed',
  'saved',
  'approved',
  'comment',
  'complexity',
  'department',
  'roto',
  'paint',
  'comp',
  'mm',
  'status',
  'note',
  'bid',
  'due',
  'date',
  'starting',
  'complete',
  'from',
  'description',
  'remarks',
  'start',
  'end',
};

int _importHeaderSignalScore(String normalized) {
  if (normalized.isEmpty) return 0;
  var score = 0;
  for (final word in _importHeaderSignalWords) {
    if (normalized == word) {
      score += 3;
    } else if (RegExp(
      '(^|_)${RegExp.escape(word)}(_|\$)',
    ).hasMatch(normalized)) {
      score += 2;
    } else if (normalized.contains(word)) {
      score += 1;
    }
  }
  return score;
}

/// Locates the real header row in an Excel sheet.  Falls back to row 0 when
/// no row scores strongly enough (files that already start with the header).
int _findHeaderRowIndexT(List<List<Data?>> rows) {
  var bestIdx = 0;
  var bestScore = 0;
  for (var i = 0; i < rows.length; i++) {
    var score = 0;
    for (final cell in rows[i]) {
      score += _importHeaderSignalScore(
        _normalizeHeaderT(cell?.value?.toString() ?? ''),
      );
    }
    if (score > bestScore) {
      bestScore = score;
      bestIdx = i;
    }
  }
  return bestScore >= 12 ? bestIdx : 0;
}

/// Locates the real header row in a CSV text (list of lines).
int _findHeaderRowIndexLinesT(List<String> lines) {
  var bestIdx = 0;
  var bestScore = 0;
  for (var i = 0; i < lines.length; i++) {
    var score = 0;
    for (final value in _splitCsvLineT(lines[i])) {
      score += _importHeaderSignalScore(_normalizeHeaderT(value));
    }
    if (score > bestScore) {
      bestScore = score;
      bestIdx = i;
    }
  }
  return bestScore >= 12 ? bestIdx : 0;
}

String? _toIsoDateT(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
  if (value is num && value > 0 && value < 70000) {
    // Excel / OpenOffice serial date: days since 1899-12-30
    final serial = value.floor();
    final d = DateTime(1899, 12, 30).add(Duration(days: serial));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed != null) {
    return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }
  // dd-MM-yyyy / dd/MM/yyyy / dd.MM.yyyy (day-first, common in VFX sheets)
  final m = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})$').firstMatch(text);
  if (m != null) {
    final first = int.parse(m.group(1)!);
    final second = int.parse(m.group(2)!);
    final year = int.parse(m.group(3)!);
    int day, month;
    if (first > 12 && second <= 12) {
      day = first;
      month = second;
    } else if (second > 12 && first <= 12) {
      day = second;
      month = first;
    } else {
      day = first;
      month = second; // ambiguous → treat as day-first
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) return text;
    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }
  return text;
}

int _toIntValueT(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim()) ?? 0;
}

double _toDoubleValueT(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().trim()) ?? 0;
}

List<String> _splitCsvLineT(String line) {
  final result = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (ch == ',' && !inQuotes) {
      result.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(ch);
  }
  result.add(buffer.toString());
  return result;
}

bool _isHeaderLikeRowT(List<String> cellValues, Set<String> headerLabels) {
  final normalizedValues = cellValues
      .map((cell) => _normalizeHeaderT(cell))
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  if (normalizedValues.isEmpty) return false;
  var matches = 0;
  const headerSignalWords = <String>{
    'shot',
    'frame',
    'start',
    'end',
    'total',
    'coordinator',
    'client',
    'show',
    'artist',
    'level',
    'allocation',
    'eta',
    'date',
    'wip',
    'manday',
    'consumed',
    'saved',
    'approved',
    'comment',
    'complexity',
    'status',
    'from',
    'paint',
    'roto',
    'comp',
    'mm',
    'note',
    'bid',
  };
  for (final value in normalizedValues) {
    final isHeaderMatch = headerLabels.contains(value);
    final containsSignalWord = headerSignalWords.any(
      (word) => value.contains(word),
    );
    if (isHeaderMatch || containsSignalWord) matches++;
  }
  final nonEmptyCount = normalizedValues.length;
  if (nonEmptyCount == 0) return false;
  // A very short row is only skipped when every cell looks like a header —
  // otherwise sparse data rows (e.g. just a shot code) would be dropped.
  if (nonEmptyCount <= 2) return matches > 0 && matches == nonEmptyCount;
  final matchRatio = matches / nonEmptyCount;
  return nonEmptyCount >= 4 && matchRatio >= 0.6;
}

dynamic _pickFieldValueT(
  Map<String, dynamic> row,
  List<String> aliases, {
  int? fallbackColumnIndex,
}) {
  for (final alias in aliases) {
    if (!row.containsKey(alias)) continue;
    final value = row[alias];
    if (value != null && value.toString().trim().isNotEmpty) return value;
  }
  final aliasKeys = aliases
      .map(_sanitizeHeaderKeyT)
      .where((k) => k.isNotEmpty)
      .toList(growable: false);
  String? bestKey;
  var bestScore = 0;
  for (final entry in row.entries) {
    final key = entry.key.toString();
    if (key.startsWith('col_')) continue;
    final value = entry.value;
    if (value == null || value.toString().trim().isEmpty) continue;
    final normalizedKey = _sanitizeHeaderKeyT(key);
    if (normalizedKey.isEmpty) continue;
    var score = 0;
    for (final alias in aliasKeys) {
      if (normalizedKey == alias) {
        score = math.max(score, 4);
        continue;
      }
      if (normalizedKey.contains(alias) || alias.contains(normalizedKey)) {
        score = math.max(score, 3);
        continue;
      }
      if (alias.length >= 4 && normalizedKey.contains(alias.substring(0, 4))) {
        score = math.max(score, 2);
      }
    }
    if (score > bestScore) {
      bestScore = score;
      bestKey = key;
    }
  }
  if (bestKey != null && bestScore > 0) return row[bestKey];
  if (fallbackColumnIndex != null) {
    final fallbackValue = row['col_$fallbackColumnIndex'];
    if (fallbackValue != null && fallbackValue.toString().trim().isNotEmpty) {
      return fallbackValue;
    }
  }
  return null;
}

Map<String, dynamic> _toApiImportRowT(
  Map<String, dynamic> row,
  String showId,
  String department,
  List<String> shotStatuses,
) {
  final shotCode =
      (_pickFieldValueT(row, [
                'shot_id',
                'shot',
                'shotcode',
                'shot_id_code',
                'shot_code',
                'shot_name',
                'shotname',
              ], fallbackColumnIndex: 0) ??
              '')
          .toString()
          .trim();
  final statusRaw =
      (_pickFieldValueT(row, [
                'status',
                'shot_status',
                'pipeline_status',
              ], fallbackColumnIndex: 27) ??
              'Awaiting Approval')
          .toString()
          .trim();
  final status = shotStatuses.contains(statusRaw)
      ? statusRaw
      : 'Awaiting Approval';
  return {
    'showId': showId,
    'department': department,
    'shotCode': shotCode,
    'frameIn': _toIntValueT(
      _pickFieldValueT(row, [
        'frame_in',
        'framein',
        'start_frame',
      ], fallbackColumnIndex: 5),
    ),
    'frameOut': _toIntValueT(
      _pickFieldValueT(row, [
        'frame_out',
        'frameout',
        'end_frame',
      ], fallbackColumnIndex: 6),
    ),
    'totalFrames': _toIntValueT(
      _pickFieldValueT(row, [
        'total_frames',
        'totalframes',
        'total frames',
      ], fallbackColumnIndex: 7),
    ),
    'supervisorBid': _toDoubleValueT(
      _pickFieldValueT(row, [
        'supervisor_bid',
        'supervisorbid',
        'sup_bid',
        'supervisor_estimate',
      ], fallbackColumnIndex: 0),
    ),
    'clientBid': _toDoubleValueT(
      _pickFieldValueT(row, [
        'client_bid',
        'clientbid',
        'cli_bid',
        'client_estimate',
      ], fallbackColumnIndex: 0),
    ),
    'clientEta': _toIsoDateT(
      _pickFieldValueT(row, [
        'client_eta',
        'eta',
        'client_due',
        'delivery_date',
      ], fallbackColumnIndex: 0),
    ),
    'coordinator':
        (_pickFieldValueT(row, [
                  'coordinator',
                  'coord',
                ], fallbackColumnIndex: 1) ??
                '')
            .toString(),
    'levelOfShot':
        (_pickFieldValueT(row, [
                  'level_of_shot',
                  'levelofshot',
                  'shot_level',
                  'level',
                ], fallbackColumnIndex: 9) ??
                '')
            .toString(),
    'allocationDate': _toIsoDateT(
      _pickFieldValueT(row, [
        'allocation_date',
        'allocationdate',
      ], fallbackColumnIndex: 10),
    ),
    'allocationEta': _toIsoDateT(
      _pickFieldValueT(row, [
        'allocation_eta',
        'allocationeta',
        'alloc_eta',
      ], fallbackColumnIndex: 11),
    ),
    'startingDate': _toIsoDateT(
      _pickFieldValueT(row, [
        'starting_date',
        'start_date',
        'startingdate',
      ], fallbackColumnIndex: 12),
    ),
    'completeDate': _toIsoDateT(
      _pickFieldValueT(row, [
        'complete_date',
        'completion_date',
        'completed_date',
      ], fallbackColumnIndex: 13),
    ),
    'dailyWip': _toDoubleValueT(
      _pickFieldValueT(row, [
        'daily_wip',
        'dailywip',
        'wip',
        'daily_wip_%',
      ], fallbackColumnIndex: 14),
    ),
    'mandays': _toDoubleValueT(
      _pickFieldValueT(row, ['mandays', 'man_days'], fallbackColumnIndex: 15),
    ),
    'consumedMandays': _toDoubleValueT(
      _pickFieldValueT(row, [
        'consumed_mandays',
        'consumedmandays',
        'consumed_man_days',
      ], fallbackColumnIndex: 16),
    ),
    'savedMandays': _toDoubleValueT(
      _pickFieldValueT(row, [
        'saved_mandays',
        'savedmandays',
        'saved_man_days',
      ], fallbackColumnIndex: 17),
    ),
    'approvedVersion':
        (_pickFieldValueT(row, [
                  'approved_version',
                  'approvedversion',
                  'version',
                ], fallbackColumnIndex: 18) ??
                '')
            .toString(),
    'approvedBy':
        (_pickFieldValueT(row, [
                  'approved_by',
                  'approvedby',
                ], fallbackColumnIndex: 19) ??
                '')
            .toString(),
    'comments':
        (_pickFieldValueT(row, [
                  'comments',
                  'comment',
                ], fallbackColumnIndex: 20) ??
                '')
            .toString(),
    'complexity':
        (_pickFieldValueT(row, [
                  'complexity',
                  'shot_complexity',
                ], fallbackColumnIndex: 21) ??
                '')
            .toString(),
    'priority':
        (_pickFieldValueT(row, [
                  'priority',
                  'shot_priority',
                  'pipeline_priority',
                ], fallbackColumnIndex: 0) ??
                '')
            .toString(),
    'notes':
        (_pickFieldValueT(row, [
                  'notes',
                  'description',
                  'remarks',
                ], fallbackColumnIndex: 0) ??
                '')
            .toString(),
    'status': status,
    'artistId':
        (_pickFieldValueT(row, [
                  'artist_id',
                  'artistid',
                  'assigned_to',
                  'artist_user_id',
                ]) ??
                '')
            .toString(),
    'artistName':
        (_pickFieldValueT(row, [
                  'artist_name',
                  'artistname',
                  'artist',
                  'assigned_artist',
                  'roto_artist',
                  'paint_artist',
                  'comp_artist',
                  'mm_artist',
                  'artists',
                ]) ??
                '')
            .toString(),
    'fromRoto':
        (_pickFieldValueT(row, [
                  'from_roto',
                  'fromroto',
                ], fallbackColumnIndex: 23) ??
                '')
            .toString(),
    'fromPaint':
        (_pickFieldValueT(row, [
                  'from_paint',
                  'frompaint',
                ], fallbackColumnIndex: 24) ??
                '')
            .toString(),
    'fromMm':
        (_pickFieldValueT(row, [
                  'from_mm',
                  'frommm',
                ], fallbackColumnIndex: 25) ??
                '')
            .toString(),
    'fromComp':
        (_pickFieldValueT(row, [
                  'from_comp',
                  'fromcomp',
                ], fallbackColumnIndex: 26) ??
                '')
            .toString(),
  };
}

/// Entry point for `compute()`.  Parses Excel/CSV bytes in a background isolate
/// AND uploads every row to the API in 100-row chunks.
/// Only a compact summary + a capped preview are transferred back to the UI
/// thread, so even 10k+ row files never jank the app or flood main-thread GC.
/// All arguments must be serializable (no object references).
Future<Map<String, dynamic>> _parseAndSaveImportInIsolate(
  Map<String, dynamic> args,
) async {
  final bytes = Uint8List.fromList(List<int>.from(args['bytes'] as List));
  final extension = (args['extension'] as String?) ?? '';
  final showId = (args['showId'] as String?) ?? '';
  final department = (args['department'] as String?) ?? '';
  final shotStatuses = ((args['shotStatuses'] as List<dynamic>?) ?? const [])
      .map((e) => e.toString())
      .toList(growable: false);
  final baseUrl = (args['baseUrl'] as String?) ?? '';
  final endpoint = (args['endpoint'] as String?) ?? '';
  final token = args['token'] as String?;

  final List<Map<String, dynamic>> rows;
  if (extension == 'xlsx') {
    rows = _parseExcelRowsT(bytes, showId, department, shotStatuses);
  } else if (extension == 'csv') {
    rows = _parseCsvRowsT(bytes, showId, department, shotStatuses);
  } else {
    throw Exception('Unsupported format: .$extension');
  }

  var created = 0;
  var updated = 0;
  final errors = <String>[];
  final notes = <String>[];
  const chunkSize = 100;
  for (var i = 0; i < rows.length; i += chunkSize) {
    final end = (i + chunkSize).clamp(0, rows.length);
    final chunk = rows.sublist(i, end);
    final resp = await _postBulkUpsertT(baseUrl, endpoint, token, chunk);
    created += (resp['created'] as int?) ?? 0;
    updated += (resp['updated'] as int?) ?? 0;
    for (final e in (resp['errors'] as List<dynamic>?) ?? const <dynamic>[]) {
      if (errors.length < 100) errors.add(e.toString());
    }
    for (final n in (resp['notes'] as List<dynamic>?) ?? const <dynamic>[]) {
      if (notes.length < 100) notes.add(n.toString());
    }
  }

  // Cap the preview transferred back — the table paginates this client-side.
  const previewCap = 60;
  final preview = <Map<String, dynamic>>[];
  final limit = rows.length < previewCap ? rows.length : previewCap;
  for (var i = 0; i < limit; i++) {
    preview.add(_projectPreviewRowT(rows[i]));
  }

  return <String, dynamic>{
    'total': rows.length,
    'created': created,
    'updated': updated,
    'errors': errors,
    'notes': notes,
    'preview': preview,
  };
}

/// Isolate-safe HTTP POST to the bulk-upsert endpoint. Uses `package:http`
/// directly because isolates share no state with the `ApiController` singleton.
Future<Map<String, dynamic>> _postBulkUpsertT(
  String baseUrl,
  String endpoint,
  String? token,
  List<Map<String, dynamic>> rows,
) async {
  final uri = Uri.parse('$baseUrl$endpoint');
  final response = await http
      .post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        body: jsonEncode(<String, dynamic>{'rows': rows}),
      )
      .timeout(const Duration(seconds: 180));
  if (response.statusCode >= 200 && response.statusCode < 300) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }
  throw Exception(
    'Bulk upsert failed (${response.statusCode}): ${response.body}',
  );
}

/// Compact display row used only by the import preview table.
Map<String, dynamic> _projectPreviewRowT(Map<String, dynamic> row) {
  String s(String key) => (row[key] ?? '').toString();
  return <String, dynamic>{
    'shotCode': s('shotCode'),
    'frameIn': s('frameIn'),
    'frameOut': s('frameOut'),
    'totalFrames': s('totalFrames'),
    'supervisorBid': s('supervisorBid'),
    'clientBid': s('clientBid'),
    'clientEta': s('clientEta'),
    'coordinator': s('coordinator'),
    'levelOfShot': s('levelOfShot'),
    'allocationDate': s('allocationDate'),
    'allocationEta': s('allocationEta'),
    'startingDate': s('startingDate'),
    'completeDate': s('completeDate'),
    'dailyWip': s('dailyWip'),
    'mandays': s('mandays'),
    'consumedMandays': s('consumedMandays'),
    'savedMandays': s('savedMandays'),
    'approvedVersion': s('approvedVersion'),
    'approvedBy': s('approvedBy'),
    'comments': s('comments'),
    'complexity': s('complexity'),
    'notes': s('notes'),
    'status': s('status'),
    'fromRoto': s('fromRoto'),
    'fromPaint': s('fromPaint'),
    'fromMm': s('fromMm'),
    'fromComp': s('fromComp'),
  };
}

/// Entry point for `compute()`.  Parses pasted CSV text in a background
/// isolate so the UI thread never blocks on large pastes.
List<Map<String, dynamic>> _parseCsvTextInIsolate(Map<String, dynamic> args) {
  final text = (args['text'] as String?) ?? '';
  final showId = (args['showId'] as String?) ?? '';
  final department = (args['department'] as String?) ?? '';
  final shotStatuses = ((args['shotStatuses'] as List<dynamic>?) ?? const [])
      .map((e) => e.toString())
      .toList(growable: false);
  return _parseCsvTextRowsT(text, showId, department, shotStatuses);
}

/// Isolate-safe paste parser: locates the header row, splits the CSV, maps
/// every column to API fields and de-duplicates shot codes.
List<Map<String, dynamic>> _parseCsvTextRowsT(
  String csvText,
  String showId,
  String department,
  List<String> shotStatuses,
) {
  final lines = const LineSplitter().convert(csvText.trim());
  if (lines.length < 2) {
    return const [];
  }

  final headerIndex = _findHeaderRowIndexLinesT(lines);
  final headers = _splitCsvLineT(
    lines[headerIndex],
  ).map(_normalizeHeaderT).toList(growable: false);
  final headerLabels = headers.where((h) => h.isNotEmpty).toSet();
  final out = <Map<String, dynamic>>[];
  final seenShotCodes = <String>{};

  for (var i = headerIndex + 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final values = _splitCsvLineT(lines[i]);
    // Skip rows whose cell values match header labels (duplicate header rows)
    if (_isHeaderLikeRowT(values, headerLabels)) continue;
    final raw = <String, dynamic>{};
    for (var c = 0; c < headers.length; c++) {
      final key = headers[c];
      final value = c < values.length ? values[c].trim() : null;
      raw['col_$c'] = value;
      if (key.isEmpty) continue;
      raw[key] = value;
    }

    final apiRow = _toApiImportRowT(raw, showId, department, shotStatuses);
    final shotCode = (apiRow['shotCode'] ?? '').toString().trim();
    if (shotCode.isEmpty) continue;
    if (seenShotCodes.contains(shotCode)) continue;
    seenShotCodes.add(shotCode);
    out.add(apiRow);
  }

  return out;
}

List<Map<String, dynamic>> _parseExcelRowsT(
  Uint8List bytes,
  String showId,
  String department,
  List<String> shotStatuses,
) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) return const [];
  final firstSheet = excel.tables.values.first;
  final rows = firstSheet.rows;
  if (rows.length < 2) return const [];
  final headerIndex = _findHeaderRowIndexT(rows);
  final headers = rows[headerIndex]
      .map((c) => _normalizeHeaderT(c?.value?.toString() ?? ''))
      .toList();
  final headerLabels = headers.where((h) => h.isNotEmpty).toSet();
  final out = <Map<String, dynamic>>[];
  final seenShotCodes = <String>{};
  for (var i = headerIndex + 1; i < rows.length; i++) {
    final r = rows[i];
    if (r.every((c) => (c?.value?.toString().trim() ?? '').isEmpty)) continue;
    final cellValues = r.map((c) => c?.value?.toString().trim() ?? '').toList();
    if (_isHeaderLikeRowT(cellValues, headerLabels)) continue;
    final raw = <String, dynamic>{};
    for (var c = 0; c < headers.length; c++) {
      final key = headers[c];
      final cell = c < r.length ? r[c] : null;
      raw['col_$c'] = cell?.value;
      if (key.isEmpty) continue;
      raw[key] = cell?.value;
    }
    final apiRow = _toApiImportRowT(raw, showId, department, shotStatuses);
    final code = (apiRow['shotCode'] ?? '').toString().trim();
    if (code.isEmpty) continue;
    if (seenShotCodes.contains(code)) continue;
    seenShotCodes.add(code);
    out.add(apiRow);
  }
  return out;
}

List<Map<String, dynamic>> _parseCsvRowsT(
  Uint8List bytes,
  String showId,
  String department,
  List<String> shotStatuses,
) {
  final csv = utf8.decode(bytes, allowMalformed: true);
  final lines = const LineSplitter().convert(csv);
  if (lines.length < 2) return const [];
  final headerIndex = _findHeaderRowIndexLinesT(lines);
  final headers = _splitCsvLineT(
    lines[headerIndex],
  ).map(_normalizeHeaderT).toList(growable: false);
  final headerLabels = headers.where((h) => h.isNotEmpty).toSet();
  final out = <Map<String, dynamic>>[];
  final seenShotCodes = <String>{};
  for (var i = headerIndex + 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final values = _splitCsvLineT(lines[i]);
    if (_isHeaderLikeRowT(values, headerLabels)) continue;
    final raw = <String, dynamic>{};
    for (var c = 0; c < headers.length; c++) {
      final key = headers[c];
      final value = c < values.length ? values[c].trim() : null;
      raw['col_$c'] = value;
      if (key.isEmpty) continue;
      raw[key] = value;
    }
    final apiRow = _toApiImportRowT(raw, showId, department, shotStatuses);
    final code = (apiRow['shotCode'] ?? '').toString().trim();
    if (code.isEmpty) continue;
    if (seenShotCodes.contains(code)) continue;
    seenShotCodes.add(code);
    out.add(apiRow);
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip-filter sub-page — navigated to from the filter dialog ListTiles.
// Shows a search bar at the top, filtered chip grids, and a loader.
// ─────────────────────────────────────────────────────────────────────────────

class _ChipFieldGroup {
  final String label;
  final List<String> allItems;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const _ChipFieldGroup({
    required this.label,
    required this.allItems,
    required this.selected,
    required this.onChanged,
  });
}

class _ClientDialog extends StatefulWidget {
  final ProjectController controller;
  const _ClientDialog({required this.controller});

  @override
  State<_ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends State<_ClientDialog> {
  final _name = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Client name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await widget.controller.createClient(name);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Client'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomTextField(
            controller: _name,
            labelText: 'Client name',
            prefixIcon: Icons.business,
          ),
          if (_error != null) ...[
            SizedBox(height: SizeConfig.scaleHeight(context, 8)),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? SizedBox(
                  width: SizeConfig.iconSize(context, 16),
                  height: SizeConfig.iconSize(context, 16),
                  child: CircularProgressIndicator(
                    strokeWidth: SizeConfig.scaleWidth(context, 2),
                  ),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

class _ShowFormDialog extends StatefulWidget {
  final ProjectController controller;
  const _ShowFormDialog({required this.controller});

  @override
  State<_ShowFormDialog> createState() => _ShowFormDialogState();
}

class _ShowFormDialogState extends State<_ShowFormDialog> {
  final _name = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final clientId = widget.controller.selectedClientId;
    if (clientId == null) {
      setState(() => _error = 'Select a client first');
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = 'Show name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await widget.controller.createShow(clientId, name);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Show'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomTextField(
            controller: _name,
            labelText: 'Show name',
            prefixIcon: Icons.movie,
          ),
          if (_error != null) ...[
            SizedBox(height: SizeConfig.scaleHeight(context, 8)),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? SizedBox(
                  width: SizeConfig.iconSize(context, 16),
                  height: SizeConfig.iconSize(context, 16),
                  child: CircularProgressIndicator(
                    strokeWidth: SizeConfig.scaleWidth(context, 2),
                  ),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

class _ShotDialog extends StatefulWidget {
  final ProjectController controller;
  final ShotModel? shot;
  const _ShotDialog({required this.controller, this.shot});

  @override
  State<_ShotDialog> createState() => _ShotDialogState();
}

class _ShotDialogState extends State<_ShotDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _coordinator;
  late final TextEditingController _frameIn;
  late final TextEditingController _frameOut;
  late final TextEditingController _totalFrames;
  late final TextEditingController _supBid;
  late final TextEditingController _cliBid;
  late final TextEditingController _mandays;
  late final TextEditingController _consumedMandays;
  late final TextEditingController _savedMandays;
  late final TextEditingController _notes;
  late final TextEditingController _comments;
  late final TextEditingController _description;
  late final TextEditingController _approvedVersion;
  late final TextEditingController _approvedBy;
  late final TextEditingController _dailyWip;
  late final TextEditingController _fromRoto;
  late final TextEditingController _fromPaint;
  late final TextEditingController _fromMm;
  late final TextEditingController _fromComp;
  // Date fields
  late final TextEditingController _clientEta;
  late final TextEditingController _dueDate;
  late final TextEditingController _allocationDate;
  late final TextEditingController _allocationEta;
  late final TextEditingController _startingDate;
  late final TextEditingController _completeDate;
  // Dropdown fields
  late final List<String> _accessibleDepartments;
  late String _department;
  late String _status;
  late String _levelOfShot;
  late String _complexity;
  String? _error;
  bool _saving = false;

  static const List<String> _levelOptions = [
    'Easy',
    'Medium',
    'Hard',
    'Key level shot',
  ];
  static const List<String> _complexityOptions = [
    'Low',
    'Medium',
    'High',
    'Critical',
  ];

  String _fmtDateInput(DateTime? d) {
    if (d == null) return '';
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    final s = widget.shot;
    _code = TextEditingController(text: s?.shotCode ?? '');
    _coordinator = TextEditingController(text: s?.coordinator ?? '');
    _frameIn = TextEditingController(text: s != null ? '${s.frameIn}' : '');
    _frameOut = TextEditingController(text: s != null ? '${s.frameOut}' : '');
    _totalFrames = TextEditingController(
      text: s != null ? '${s.totalFrames}' : '',
    );
    _supBid = TextEditingController(
      text: s != null ? '${s.supervisorBid}' : '',
    );
    _cliBid = TextEditingController(text: s != null ? '${s.clientBid}' : '');
    _mandays = TextEditingController(text: s != null ? '${s.mandays}' : '');
    _consumedMandays = TextEditingController(
      text: s != null ? '${s.consumedMandays}' : '',
    );
    _savedMandays = TextEditingController(
      text: s != null ? '${s.savedMandays}' : '',
    );
    _notes = TextEditingController(text: s?.notes ?? '');
    _comments = TextEditingController(text: s?.comments ?? '');
    _description = TextEditingController(text: s?.description ?? '');
    _approvedVersion = TextEditingController(text: s?.approvedVersion ?? '');
    _approvedBy = TextEditingController(text: s?.approvedBy ?? '');
    _dailyWip = TextEditingController(text: s != null ? '${s.dailyWip}' : '');
    _fromRoto = TextEditingController(text: s?.fromRoto ?? '');
    _fromPaint = TextEditingController(text: s?.fromPaint ?? '');
    _fromMm = TextEditingController(text: s?.fromMm ?? '');
    _fromComp = TextEditingController(text: s?.fromComp ?? '');
    _clientEta = TextEditingController(text: _fmtDateInput(s?.clientEta));
    _dueDate = TextEditingController(text: _fmtDateInput(s?.dueDate));
    _allocationDate = TextEditingController(
      text: _fmtDateInput(s?.allocationDate),
    );
    _allocationEta = TextEditingController(
      text: _fmtDateInput(s?.allocationEta),
    );
    _startingDate = TextEditingController(text: _fmtDateInput(s?.startingDate));
    _completeDate = TextEditingController(text: _fmtDateInput(s?.completeDate));

    final user = context.read<AuthController>().currentUser;
    final roleDepartments = AppConstants.accessiblePipelineDepartments(
      role: user?.role,
      department: user?.department,
    );
    final controllerDepartments = widget.controller.departments;
    if (controllerDepartments.isNotEmpty) {
      _accessibleDepartments = roleDepartments.isEmpty
          ? controllerDepartments
          : controllerDepartments
                .where((d) => roleDepartments.contains(d))
                .toList(growable: false);
    } else {
      _accessibleDepartments = roleDepartments.isEmpty
          ? AppConstants.pipelineDepartments
          : roleDepartments;
    }

    final defaultDepartment =
        s?.department ?? widget.controller.selectedDepartment;
    if (defaultDepartment != null &&
        _accessibleDepartments.contains(defaultDepartment)) {
      _department = defaultDepartment;
    } else {
      _department = _accessibleDepartments.first;
    }
    _status = s?.status ?? AppConstants.shotStatuses[2];
    _levelOfShot = s?.levelOfShot ?? _levelOptions.first;
    _complexity = s?.complexity ?? _complexityOptions.first;
  }

  @override
  void dispose() {
    _code.dispose();
    _coordinator.dispose();
    _frameIn.dispose();
    _frameOut.dispose();
    _totalFrames.dispose();
    _supBid.dispose();
    _cliBid.dispose();
    _mandays.dispose();
    _consumedMandays.dispose();
    _savedMandays.dispose();
    _notes.dispose();
    _comments.dispose();
    _description.dispose();
    _approvedVersion.dispose();
    _approvedBy.dispose();
    _dailyWip.dispose();
    _fromRoto.dispose();
    _fromPaint.dispose();
    _fromMm.dispose();
    _fromComp.dispose();
    _clientEta.dispose();
    _dueDate.dispose();
    _allocationDate.dispose();
    _allocationEta.dispose();
    _startingDate.dispose();
    _completeDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.of(context).size.width;
    final dialogWidth = availableWidth < 760 ? availableWidth * 0.95 : 680.0;
    final halfWidth = (dialogWidth - 16) / 2;
    const narrowWidth = 180.0;

    return AlertDialog(
      title: Text(widget.shot == null ? 'New Shot' : 'Edit Shot'),
      content: SizedBox(
        width: dialogWidth,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: [
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                // Row 1: Shot Code + Department
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _code,
                        labelText: 'Shot code *',
                        prefixIcon: Icons.confirmation_number_outlined,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomDropdown<String>(
                        labelText: 'Department',
                        value: _department,
                        items: _accessibleDepartments,
                        itemToString: (d) => d,
                        onChanged: (v) => setState(() => _department = v!),
                      ),
                    ),
                  ],
                ),
                // Row 2: Coordinator + Status
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _coordinator,
                        labelText: 'Coordinator',
                        prefixIcon: Icons.person_outline,
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomDropdown<String>(
                        labelText: 'Status',
                        value: _status,
                        items: AppConstants.shotStatuses,
                        itemToString: (s) => s,
                        onChanged: (v) {
                          if (v != null) setState(() => _status = v);
                        },
                      ),
                    ),
                  ],
                ),
                // Row 3: Start Frame, End Frame, Total Frames
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: narrowWidth,
                      child: CustomTextField(
                        controller: _frameIn,
                        labelText: 'Start Frame',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(
                      width: narrowWidth,
                      child: CustomTextField(
                        controller: _frameOut,
                        labelText: 'End Frame',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(
                      width: narrowWidth,
                      child: CustomTextField(
                        controller: _totalFrames,
                        labelText: 'Total Frames',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                // Row 4: Level of Shot + Complexity
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomDropdown<String>(
                        labelText: 'Level of Shot',
                        value: _levelOfShot,
                        items: _levelOptions,
                        itemToString: (l) => l,
                        onChanged: (v) {
                          if (v != null) setState(() => _levelOfShot = v);
                        },
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomDropdown<String>(
                        labelText: 'Complexity',
                        value: _complexity,
                        items: _complexityOptions,
                        itemToString: (c) => c,
                        onChanged: (v) {
                          if (v != null) setState(() => _complexity = v);
                        },
                      ),
                    ),
                  ],
                ),
                // Row 5: Dates - Allocation, Allocation ETA
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _allocationDate,
                        labelText: 'Allocation Date',
                        isDateField: true,
                        onDateTap: (ctx) => _pickDate(ctx, _allocationDate),
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _allocationEta,
                        labelText: 'Allocation ETA',
                        isDateField: true,
                        onDateTap: (ctx) => _pickDate(ctx, _allocationEta),
                      ),
                    ),
                  ],
                ),
                // Row 6: Dates - Starting, Complete
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _startingDate,
                        labelText: 'Starting Date',
                        isDateField: true,
                        onDateTap: (ctx) => _pickDate(ctx, _startingDate),
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _completeDate,
                        labelText: 'Complete Date',
                        isDateField: true,
                        onDateTap: (ctx) => _pickDate(ctx, _completeDate),
                      ),
                    ),
                  ],
                ),
                // Row 7: Client ETA + Due Date
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _clientEta,
                        labelText: 'Client ETA',
                        isDateField: true,
                        onDateTap: (ctx) => _pickDate(ctx, _clientEta),
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _dueDate,
                        labelText: 'Due Date',
                        isDateField: true,
                        onDateTap: (ctx) => _pickDate(ctx, _dueDate),
                      ),
                    ),
                  ],
                ),
                // Row 8: Mandays fields
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: narrowWidth,
                      child: CustomTextField(
                        controller: _mandays,
                        labelText: 'Mandays',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(
                      width: narrowWidth,
                      child: CustomTextField(
                        controller: _consumedMandays,
                        labelText: 'Consumed Mandays',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(
                      width: narrowWidth,
                      child: CustomTextField(
                        controller: _savedMandays,
                        labelText: 'Saved Mandays',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                // Row 9: Daily WIP + Supervisor Bid + Client Bid
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: narrowWidth,
                      child: CustomTextField(
                        controller: _dailyWip,
                        labelText: 'Daily WIP %',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(
                      width: narrowWidth,
                      child: CustomTextField(
                        controller: _supBid,
                        labelText: 'Supervisor Bid',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(
                      width: narrowWidth,
                      child: CustomTextField(
                        controller: _cliBid,
                        labelText: 'Client Bid',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                // Row 10: Approved Version + Approved By
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _approvedVersion,
                        labelText: 'Approved Version',
                        prefixIcon: Icons.tag,
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _approvedBy,
                        labelText: 'Approved By',
                        prefixIcon: Icons.person,
                      ),
                    ),
                  ],
                ),
                // Notes, Comments, Description
                CustomTextField(
                  controller: _notes,
                  labelText: 'Notes',
                  maxLines: 2,
                ),
                CustomTextField(
                  controller: _comments,
                  labelText: 'Comments',
                  maxLines: 2,
                ),
                CustomTextField(
                  controller: _description,
                  labelText: 'Description',
                  maxLines: 2,
                ),
                // From Roto / Paint / MM / Comp
                const Divider(),
                Text(
                  'Cross-Department Work Notes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: SizeConfig.fontSize(context, 13),
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _fromRoto,
                        labelText: 'From Roto',
                        prefixIcon: Icons.swap_horiz,
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _fromPaint,
                        labelText: 'From Paint',
                        prefixIcon: Icons.swap_horiz,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _fromMm,
                        labelText: 'From MM',
                        prefixIcon: Icons.swap_horiz,
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _fromComp,
                        labelText: 'From Comp',
                        prefixIcon: Icons.swap_horiz,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'shotCode': _code.text.trim(),
      'department': _department,
      'coordinator': _coordinator.text.trim().isEmpty
          ? null
          : _coordinator.text.trim(),
      'frameIn': int.tryParse(_frameIn.text) ?? 0,
      'frameOut': int.tryParse(_frameOut.text) ?? 0,
      'totalFrames': int.tryParse(_totalFrames.text) ?? 0,
      'supervisorBid': double.tryParse(_supBid.text) ?? 0,
      'clientBid': double.tryParse(_cliBid.text) ?? 0,
      'mandays': double.tryParse(_mandays.text) ?? 0,
      'consumedMandays': double.tryParse(_consumedMandays.text) ?? 0,
      'savedMandays': double.tryParse(_savedMandays.text) ?? 0,
      'dailyWip': double.tryParse(_dailyWip.text) ?? 0,
      'status': _status,
      'levelOfShot': _levelOfShot,
      'complexity': _complexity,
      'approvedVersion': _approvedVersion.text.trim().isEmpty
          ? null
          : _approvedVersion.text.trim(),
      'approvedBy': _approvedBy.text.trim().isEmpty
          ? null
          : _approvedBy.text.trim(),
      'clientEta': _clientEta.text.trim().isEmpty
          ? null
          : _clientEta.text.trim(),
      'dueDate': _dueDate.text.trim().isEmpty ? null : _dueDate.text.trim(),
      'allocationDate': _allocationDate.text.trim().isEmpty
          ? null
          : _allocationDate.text.trim(),
      'allocationEta': _allocationEta.text.trim().isEmpty
          ? null
          : _allocationEta.text.trim(),
      'startingDate': _startingDate.text.trim().isEmpty
          ? null
          : _startingDate.text.trim(),
      'completeDate': _completeDate.text.trim().isEmpty
          ? null
          : _completeDate.text.trim(),
      'notes': _notes.text.trim(),
      'comments': _comments.text.trim().isEmpty ? null : _comments.text.trim(),
      'description': _description.text.trim(),
      'fromRoto': _fromRoto.text.trim().isEmpty ? null : _fromRoto.text.trim(),
      'fromPaint': _fromPaint.text.trim().isEmpty
          ? null
          : _fromPaint.text.trim(),
      'fromMm': _fromMm.text.trim().isEmpty ? null : _fromMm.text.trim(),
      'fromComp': _fromComp.text.trim().isEmpty ? null : _fromComp.text.trim(),
      if (widget.shot == null) 'showId': widget.controller.selectedShowId,
    };
    final err = widget.shot == null
        ? await widget.controller.createShot(body)
        : await widget.controller.updateShot(widget.shot!.shotId, body);
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

  Future<void> _pickDate(
    BuildContext context,
    TextEditingController ctrl,
  ) async {
    final dateStr = ctrl.text.trim();
    DateTime initialDate = DateTime.now();
    try {
      if (dateStr.isNotEmpty) {
        initialDate = DateTime.parse(dateStr);
      }
    } catch (_) {}

    if (!mounted) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      ctrl.text = _fmtDateInput(picked);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Project filter dialog data & widget
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectFilterResult {
  final String? department;
  final String? clientId;
  final String? showId;
  final String shotId;
  final String startFrame;
  final String endFrame;
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
  final String comments;
  // Chip-based (multi-select)
  final Set<String> coordinatorChips;
  final Set<String> artistNameChips;
  final Set<String> levelOfShotChips;
  final Set<String> approvedByChips;
  final Set<String> complexityChips;
  final Set<String> statusChips;
  final Set<String> priorityChips;
  final Set<String> fromRotoChips;
  final Set<String> fromPaintChips;
  final Set<String> fromMmChips;
  final Set<String> fromCompChips;

  const _ProjectFilterResult({
    this.department,
    this.clientId,
    this.showId,
    required this.shotId,
    required this.startFrame,
    required this.endFrame,
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
    required this.comments,
    required this.coordinatorChips,
    required this.artistNameChips,
    required this.levelOfShotChips,
    required this.approvedByChips,
    required this.complexityChips,
    required this.statusChips,
    required this.priorityChips,
    required this.fromRotoChips,
    required this.fromPaintChips,
    required this.fromMmChips,
    required this.fromCompChips,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Project filter dialog — chip-based multi-select for discrete fields,
// text fields for freeform / numeric / date fields.
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectFilterDialog extends StatefulWidget {
  final ProjectController controller;
  // Text fields
  final String initialShotId;
  final String initialStartFrame;
  final String initialEndFrame;
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
  final String initialComments;
  // Chip fields
  final Set<String> initialCoordinatorChips;
  final Set<String> initialArtistNameChips;
  final Set<String> initialLevelOfShotChips;
  final Set<String> initialApprovedByChips;
  final Set<String> initialComplexityChips;
  final Set<String> initialStatusChips;
  final Set<String> initialPriorityChips;
  final Set<String> initialFromRotoChips;
  final Set<String> initialFromPaintChips;
  final Set<String> initialFromMmChips;
  final Set<String> initialFromCompChips;

  const _ProjectFilterDialog({
    required this.controller,
    required this.initialShotId,
    required this.initialStartFrame,
    required this.initialEndFrame,
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
    required this.initialComments,
    required this.initialCoordinatorChips,
    required this.initialArtistNameChips,
    required this.initialLevelOfShotChips,
    required this.initialApprovedByChips,
    required this.initialComplexityChips,
    required this.initialStatusChips,
    required this.initialPriorityChips,
    required this.initialFromRotoChips,
    required this.initialFromPaintChips,
    required this.initialFromMmChips,
    required this.initialFromCompChips,
  });

  @override
  State<_ProjectFilterDialog> createState() => _ProjectFilterDialogState();
}

class _ProjectFilterDialogState extends State<_ProjectFilterDialog> {
  late String? _selectedDept;
  late String? _selectedClientId;
  late String? _selectedShowId;

  // ── Text controllers ──
  late final Map<String, TextEditingController> _controllers;

  // ── Chip selections (multi-select) ──
  late Set<String> _coordinatorChips;
  late Set<String> _artistNameChips;
  late Set<String> _levelOfShotChips;
  late Set<String> _approvedByChips;
  late Set<String> _complexityChips;
  late Set<String> _statusChips;
  late Set<String> _priorityChips;
  late Set<String> _fromRotoChips;
  late Set<String> _fromPaintChips;
  late Set<String> _fromMmChips;
  late Set<String> _fromCompChips;

  // ── Unique values extracted from loaded shots ──
  List<String> _uniqueStatuses = [];
  List<String> _uniqueCoordinators = [];
  List<String> _uniqueArtists = [];
  List<String> _uniqueLevels = [];
  List<String> _uniqueComplexities = [];
  List<String> _uniqueApprovers = [];
  List<String> _uniquePriorities = [];
  List<String> _uniqueFromRoto = [];
  List<String> _uniqueFromPaint = [];
  List<String> _uniqueFromMm = [];
  List<String> _uniqueFromComp = [];

  /// Shows a loader while unique values are being parsed from shot data.
  bool _isLoadingValues = true;

  /// When non-null a sub-page is shown inside the dialog instead of the main
  /// ListTile list.  Values: 'status', 'personnel', 'classification',
  /// 'crossDept', 'search', 'frames', 'dates', 'metrics'.
  String? _subPageKey;

  @override
  void initState() {
    super.initState();
    _selectedDept = widget.controller.selectedDepartment;
    _selectedClientId = widget.controller.selectedClientId;
    _selectedShowId = widget.controller.selectedShowId;

    _controllers = {
      'shotId': TextEditingController(text: widget.initialShotId),
      'startFrame': TextEditingController(text: widget.initialStartFrame),
      'endFrame': TextEditingController(text: widget.initialEndFrame),
      'totalFrames': TextEditingController(text: widget.initialTotalFrames),
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
      'comments': TextEditingController(text: widget.initialComments),
    };

    _coordinatorChips = Set<String>.from(widget.initialCoordinatorChips);
    _artistNameChips = Set<String>.from(widget.initialArtistNameChips);
    _levelOfShotChips = Set<String>.from(widget.initialLevelOfShotChips);
    _approvedByChips = Set<String>.from(widget.initialApprovedByChips);
    _complexityChips = Set<String>.from(widget.initialComplexityChips);
    _statusChips = Set<String>.from(widget.initialStatusChips);
    _priorityChips = Set<String>.from(widget.initialPriorityChips);
    _fromRotoChips = Set<String>.from(widget.initialFromRotoChips);
    _fromPaintChips = Set<String>.from(widget.initialFromPaintChips);
    _fromMmChips = Set<String>.from(widget.initialFromMmChips);
    _fromCompChips = Set<String>.from(widget.initialFromCompChips);

    // Defer computation so the loader is visible while parsing shot data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _computeUniqueValues();
    });
  }

  void _computeUniqueValues() {
    final shots = widget.controller.shots;
    Set<String> uq(String? Function(ShotModel) fn) => shots
        .map((s) => (fn(s) ?? '').trim())
        .where((v) => v.isNotEmpty)
        .toSet();

    _uniqueStatuses = _dedupeSorted([
      ...AppConstants.shotStatuses,
      ...uq((s) => s.status),
    ]);
    _uniqueCoordinators = _sorted(uq((s) => s.coordinator));
    _uniqueArtists = _sorted(uq((s) => s.artistName));
    _uniqueLevels = _sorted(uq((s) => s.levelOfShot));
    _uniqueComplexities = _sorted(uq((s) => s.complexity));
    _uniqueApprovers = _sorted(uq((s) => s.approvedBy));
    _uniquePriorities = _dedupeSorted([
      ..._priorityOptions,
      ...uq((s) => s.priority),
    ]);
    _uniqueFromRoto = _sorted(uq((s) => s.fromRoto));
    _uniqueFromPaint = _sorted(uq((s) => s.fromPaint));
    _uniqueFromMm = _sorted(uq((s) => s.fromMm));
    _uniqueFromComp = _sorted(uq((s) => s.fromComp));

    if (mounted) {
      setState(() => _isLoadingValues = false);
    }
  }

  List<String> _sorted(Set<String> s) => s.toList()..sort();
  List<String> _dedupeSorted(List<String> items) {
    final seen = <String>{};
    return items.where(seen.add).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _subSearchCtrl.dispose();
    super.dispose();
  }

  void _clearAll() {
    setState(() {
      _selectedDept = ProjectController.allOption;
      _selectedClientId = ProjectController.allOption;
      _selectedShowId = ProjectController.allOption;
      for (final c in _controllers.values) {
        c.clear();
      }
      _coordinatorChips.clear();
      _artistNameChips.clear();
      _levelOfShotChips.clear();
      _approvedByChips.clear();
      _complexityChips.clear();
      _statusChips.clear();
      _priorityChips.clear();
      _fromRotoChips.clear();
      _fromPaintChips.clear();
      _fromMmChips.clear();
      _fromCompChips.clear();
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      _ProjectFilterResult(
        department: _selectedDept != widget.controller.selectedDepartment
            ? _selectedDept
            : null,
        clientId: _selectedClientId != widget.controller.selectedClientId
            ? _selectedClientId
            : null,
        showId: _selectedShowId != widget.controller.selectedShowId
            ? _selectedShowId
            : null,
        shotId: _controllers['shotId']!.text,
        startFrame: _controllers['startFrame']!.text,
        endFrame: _controllers['endFrame']!.text,
        totalFrames: _controllers['totalFrames']!.text,
        allocationDate: _controllers['allocationDate']!.text,
        allocationEta: _controllers['allocationEta']!.text,
        startingDate: _controllers['startingDate']!.text,
        completeDate: _controllers['completeDate']!.text,
        dailyWip: _controllers['dailyWip']!.text,
        mandays: _controllers['mandays']!.text,
        consumedMandays: _controllers['consumedMandays']!.text,
        savedMandays: _controllers['savedMandays']!.text,
        approvedVersion: _controllers['approvedVersion']!.text,
        comments: _controllers['comments']!.text,
        coordinatorChips: _coordinatorChips,
        artistNameChips: _artistNameChips,
        levelOfShotChips: _levelOfShotChips,
        approvedByChips: _approvedByChips,
        complexityChips: _complexityChips,
        statusChips: _statusChips,
        priorityChips: _priorityChips,
        fromRotoChips: _fromRotoChips,
        fromPaintChips: _fromPaintChips,
        fromMmChips: _fromMmChips,
        fromCompChips: _fromCompChips,
      ),
    );
  }

  String _clientName(String clientId) {
    if (clientId == ProjectController.allOption) return clientId;
    try {
      return widget.controller.clients
          .firstWhere((c) => c.clientId == clientId)
          .clientName;
    } catch (_) {
      return clientId;
    }
  }

  String _showName(String showId) {
    if (showId == ProjectController.allOption) return showId;
    try {
      return widget.controller.shows
          .firstWhere((s) => s.showId == showId)
          .showName;
    } catch (_) {
      return showId;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build — flat ListTile list with inline sub-page switching
  // ─────────────────────────────────────────────────────────────────────────

  // ── Sub-page title / subtitle lookup ──
  String get _subPageTitle {
    switch (_subPageKey) {
      case 'status':
        return 'Status';
      case 'personnel':
        return 'Personnel';
      case 'classification':
        return 'Classification';
      case 'crossDept':
        return 'Cross-Department';
      default:
        return 'Filter Projects';
    }
  }

  String get _subPageSubtitle {
    switch (_subPageKey) {
      case 'status':
        return 'Filter by pipeline status';
      case 'personnel':
        return 'Filter by coordinator, artist & approver';
      case 'classification':
        return 'Filter by level of shot & complexity';
      case 'crossDept':
        return 'Filter by cross-department work notes';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.of(context).size.width;
    final dialogWidth = availableWidth < 600 ? availableWidth * 0.92 : 560.0;

    final showSubPage = _subPageKey != null;

    return AlertDialog(
      title: Row(
        children: [
          if (showSubPage)
            IconButton(
              icon: Icon(
                Icons.arrow_back,
                size: SizeConfig.iconSize(context, 18),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _subPageKey = null),
            ),
          if (showSubPage) SizedBox(width: SizeConfig.scaleWidth(context, 8)),
          Expanded(
            child: Text(
              showSubPage ? _subPageTitle : 'Filter Projects',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!showSubPage) ...[
            const Spacer(),
            TextButton(onPressed: _clearAll, child: const Text('Clear All')),
          ],
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: dialogWidth,
          height: showSubPage ? SizeConfig.scaleHeight(context, 400) : null,
          child: _isLoadingValues
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: AppColors.brandGreen,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Parsing filter values…',
                          style: TextStyle(
                            fontSize: SizeConfig.fontSize(context, 13),
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : showSubPage
              ? _buildSubPageBody()
              : _buildMainList(),
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

  /// Main ListTile list (when no sub-page is open).
  Widget _buildMainList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Data Source (inline single-select chips) ──
        _labeledChipRow(
          'Department',
          [ProjectController.allOption, ...widget.controller.departments],
          _selectedDept,
          (v) => setState(() => _selectedDept = v),
        ),
        SizedBox(height: SizeConfig.scaleHeight(context, 8)),
        _labeledChipRow(
          'Client',
          [
            ProjectController.allOption,
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
            ProjectController.allOption,
            ...widget.controller.shows.map((s) => s.showId),
          ],
          _selectedShowId,
          (v) => setState(() => _selectedShowId = v),
          labelFn: _showName,
        ),
        const Divider(height: 24),

        // ── Status ──
        _filterListTile(
          'Status',
          subtitle: _statusChips.isEmpty
              ? null
              : '${_statusChips.length} selected',
          activeCount: _statusChips.length,
          onTap: () => setState(() => _subPageKey = 'status'),
        ),

        // ── Personnel ──
        _filterListTile(
          'Personnel',
          subtitle: _personnelSummary,
          activeCount:
              _coordinatorChips.length +
              _artistNameChips.length +
              _approvedByChips.length,
          onTap: () => setState(() => _subPageKey = 'personnel'),
        ),

        // ── Classification ──
        _filterListTile(
          'Classification',
          subtitle: _classificationSummary,
          activeCount:
              _levelOfShotChips.length +
              _complexityChips.length +
              _priorityChips.length,
          onTap: () => setState(() => _subPageKey = 'classification'),
        ),

        // ── Cross-Department ──
        _filterListTile(
          'Cross-Department',
          subtitle: _crossDeptSummary,
          activeCount:
              _fromRotoChips.length +
              _fromPaintChips.length +
              _fromMmChips.length +
              _fromCompChips.length,
          onTap: () => setState(() => _subPageKey = 'crossDept'),
        ),
      ],
    );
  }

  /// Builds the inline sub-page body based on [_subPageKey].
  Widget _buildSubPageBody() {
    switch (_subPageKey) {
      case 'status':
        return _buildChipSubPageBody([
          _ChipFieldGroup(
            label: 'Status',
            allItems: _uniqueStatuses,
            selected: _statusChips,
            onChanged: (v) => setState(() => _statusChips = v),
          ),
        ]);
      case 'personnel':
        return _buildChipSubPageBody([
          _ChipFieldGroup(
            label: 'Coordinator',
            allItems: _uniqueCoordinators,
            selected: _coordinatorChips,
            onChanged: (v) => setState(() => _coordinatorChips = v),
          ),
          _ChipFieldGroup(
            label: 'Artist Name',
            allItems: _uniqueArtists,
            selected: _artistNameChips,
            onChanged: (v) => setState(() => _artistNameChips = v),
          ),
          _ChipFieldGroup(
            label: 'Approved By',
            allItems: _uniqueApprovers,
            selected: _approvedByChips,
            onChanged: (v) => setState(() => _approvedByChips = v),
          ),
        ]);
      case 'classification':
        return _buildChipSubPageBody([
          _ChipFieldGroup(
            label: 'Level of Shot',
            allItems: _uniqueLevels,
            selected: _levelOfShotChips,
            onChanged: (v) => setState(() => _levelOfShotChips = v),
          ),
          _ChipFieldGroup(
            label: 'Complexity',
            allItems: _uniqueComplexities,
            selected: _complexityChips,
            onChanged: (v) => setState(() => _complexityChips = v),
          ),
          _ChipFieldGroup(
            label: 'Priority',
            allItems: _uniquePriorities,
            selected: _priorityChips,
            onChanged: (v) => setState(() => _priorityChips = v),
          ),
        ]);
      case 'crossDept':
        return _buildChipSubPageBody([
          _ChipFieldGroup(
            label: 'From Roto',
            allItems: _uniqueFromRoto,
            selected: _fromRotoChips,
            onChanged: (v) => setState(() => _fromRotoChips = v),
          ),
          _ChipFieldGroup(
            label: 'From Paint',
            allItems: _uniqueFromPaint,
            selected: _fromPaintChips,
            onChanged: (v) => setState(() => _fromPaintChips = v),
          ),
          _ChipFieldGroup(
            label: 'From MM',
            allItems: _uniqueFromMm,
            selected: _fromMmChips,
            onChanged: (v) => setState(() => _fromMmChips = v),
          ),
          _ChipFieldGroup(
            label: 'From Comp',
            allItems: _uniqueFromComp,
            selected: _fromCompChips,
            onChanged: (v) => setState(() => _fromCompChips = v),
          ),
        ]);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Searchable chip-grid sub-page body ──
  final _subSearchCtrl = TextEditingController();
  String _subQuery = '';

  List<String> _filteredItems(List<String> items) {
    if (_subQuery.isEmpty) return items;
    final q = _subQuery.toLowerCase();
    return items.where((i) => i.toLowerCase().contains(q)).toList();
  }

  Widget _buildChipSubPageBody(List<_ChipFieldGroup> groups) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.scaleWidth(context, 4),
        vertical: SizeConfig.scaleWidth(context, 4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.fromLTRB(
              0,
              0,
              0,
              SizeConfig.scaleHeight(context, 4),
            ),
            child: TextField(
              controller: _subSearchCtrl,
              decoration: InputDecoration(
                hintText: 'Search…',
                prefixIcon: Icon(
                  Icons.search,
                  size: SizeConfig.iconSize(context, 20),
                ),
                suffixIcon: _subQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: SizeConfig.iconSize(context, 18),
                        ),
                        onPressed: () {
                          _subSearchCtrl.clear();
                          setState(() => _subQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.scaleWidth(context, 10),
                  vertical: SizeConfig.scaleWidth(context, 10),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    SizeConfig.scaleWidth(context, 2),
                  ),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
              ),
              style: TextStyle(fontSize: SizeConfig.fontSize(context, 13)),
              onChanged: (v) => setState(() => _subQuery = v.trim()),
            ),
          ),
          Text(
            _subPageSubtitle,
            style: TextStyle(
              fontSize: SizeConfig.fontSize(context, 11),
              color: Colors.white54,
            ),
          ),
          const Divider(),
          for (final group in groups) ...[
            _buildGroupHeader(group),
            SizedBox(height: SizeConfig.scaleHeight(context, 4)),
            _buildChipGridInline(
              _filteredItems(group.allItems),
              group.selected,
              group.onChanged,
            ),
            SizedBox(height: SizeConfig.scaleHeight(context, 14)),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupHeader(_ChipFieldGroup group) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.scaleWidth(context, 4),
      ),
      child: Text(
        '${group.label}  (${group.selected.length} selected)',
        style: TextStyle(
          fontSize: SizeConfig.fontSize(context, 12),
          fontWeight: FontWeight.w600,
          color: group.selected.isNotEmpty
              ? AppColors.brandGreen
              : Colors.white70,
        ),
      ),
    );
  }

  Widget _buildChipGridInline(
    List<String> items,
    Set<String> selected,
    ValueChanged<Set<String>> onChanged,
  ) {
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: SizeConfig.scaleWidth(context, 4),
          vertical: SizeConfig.scaleHeight(context, 8),
        ),
        child: Text(
          'No matching values',
          style: TextStyle(
            fontSize: SizeConfig.fontSize(context, 11),
            color: Colors.white38,
          ),
        ),
      );
    }
    return Wrap(
      spacing: SizeConfig.scaleWidth(context, 4),
      runSpacing: SizeConfig.scaleWidth(context, 4),
      children: items.map((item) {
        final isSelected = selected.contains(item);
        return FilterChip(
          label: Text(
            item,
            style: TextStyle(
              fontSize: SizeConfig.fontSize(context, 11),
              color: isSelected ? Colors.white : null,
            ),
          ),
          selected: isSelected,
          onSelected: (checked) {
            final updated = Set<String>.from(selected);
            if (checked) {
              updated.add(item);
            } else {
              updated.remove(item);
            }
            onChanged(updated);
            setState(() {}); // refresh header counts
          },
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
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Summary getters for ListTile subtitles
  // ─────────────────────────────────────────────────────────────────────────

  String? get _personnelSummary {
    final parts = <String>[];
    if (_coordinatorChips.isNotEmpty) {
      parts.add('Coordinator (${_coordinatorChips.length})');
    }
    if (_artistNameChips.isNotEmpty) {
      parts.add('Artist (${_artistNameChips.length})');
    }
    if (_approvedByChips.isNotEmpty) {
      parts.add('Approver (${_approvedByChips.length})');
    }
    return parts.isEmpty ? null : parts.join(', ');
  }

  String? get _classificationSummary {
    final parts = <String>[];
    if (_levelOfShotChips.isNotEmpty) {
      parts.add('Level (${_levelOfShotChips.length})');
    }
    if (_complexityChips.isNotEmpty) {
      parts.add('Complexity (${_complexityChips.length})');
    }
    if (_priorityChips.isNotEmpty) {
      parts.add('Priority (${_priorityChips.length})');
    }
    return parts.isEmpty ? null : parts.join(', ');
  }

  String? get _crossDeptSummary {
    final parts = <String>[];
    if (_fromRotoChips.isNotEmpty) parts.add('Roto (${_fromRotoChips.length})');
    if (_fromPaintChips.isNotEmpty) {
      parts.add('Paint (${_fromPaintChips.length})');
    }
    if (_fromMmChips.isNotEmpty) parts.add('MM (${_fromMmChips.length})');
    if (_fromCompChips.isNotEmpty) {
      parts.add('Comp (${_fromCompChips.length})');
    }
    return parts.isEmpty ? null : parts.join(', ');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Widget helpers
  // ─────────────────────────────────────────────────────────────────────────

  Widget _filterListTile(
    String title, {
    String? subtitle,
    int activeCount = 0,
    bool hasText = false,
    VoidCallback? onTap,
  }) {
    final hasActive = activeCount > 0 || hasText;
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: SizeConfig.scaleWidth(context, 4),
      ),
      visualDensity: VisualDensity.compact,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: SizeConfig.fontSize(context, 14),
          color: hasActive ? AppColors.brandGreen : null,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: SizeConfig.fontSize(context, 12),
                color: hasActive ? AppColors.brandGreen : Colors.white54,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          SizedBox(width: SizeConfig.scaleWidth(context, 4)),
          Icon(Icons.chevron_right, size: SizeConfig.iconSize(context, 20)),
        ],
      ),
      onTap: onTap,
    );
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
}
