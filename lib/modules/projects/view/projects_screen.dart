import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/shot_model.dart';
import '../../../shared/widgets/custom_dropdown.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/dynamic_data_table.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/projects_controller.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final List<Map<String, dynamic>> _importDraftRows = [];
  final TextEditingController _csvPasteController = TextEditingController();

  String _shotIdFilter = '';
  String _frameInFilter = '';
  String _frameOutFilter = '';
  String _supervisorBidFilter = '';
  String _clientBidFilter = '';
  String _notesFilter = '';
  String _taskFilter = '';
  String _etaFilter = '';
  String _statusFilter = '';

  final String _importShotFilter = '';
  final String _importFrameInFilter = '';
  final String _importFrameOutFilter = '';
  final String _importSupervisorBidFilter = '';
  final String _importClientBidFilter = '';
  final String _importEtaFilter = '';
  final String _importStatusFilter = '';

  bool _isImporting = false;
  bool _isSavingImport = false;
  bool _isExporting = false;
  bool _isBroadAccess = false;
  bool _isArtist = false;
  bool _canCreateClientShow = false;
  bool _canCreateShot = false;
  String? _roleDepartment;

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
      return const LoadingWidget(message: 'Loading projects...');
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: const Text(
                  'Select department and show to import.',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              _filters(context, controller),
              if (_importDraftRows.isNotEmpty) ...[
                const SizedBox(height: 12),
                _importPreviewTable(),
              ],
              const SizedBox(height: 8),
              Expanded(child: _shots(context, controller)),
            ],
          );
        },
      ),
    );
  }

  Widget _importActions(BuildContext context, ProjectController controller) {
    final canImport =
        _canCreateShot &&
        controller.selectedShowId != null &&
        controller.selectedDepartment != null;

    if (!_canCreateShot) {
      return const SizedBox.shrink();
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandGreen,
            foregroundColor: Colors.white,
            fixedSize: const Size(160, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          onPressed: _isExporting
              ? null
              : () => _exportShotsAsExcel(controller),
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
            fixedSize: const Size(160, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
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
            fixedSize: const Size(160, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          onPressed: _isImporting || !canImport
              ? null
              : () => _pickAndParseExcel(controller),
          icon: _isImporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_outlined),
          label: const Text('Import File'),
        ),
        SizedBox(
          width: 200,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: Colors.white,
              fixedSize: const Size(200, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            onPressed: _isSavingImport || _importDraftRows.isEmpty
                ? null
                : () => _saveImportedRows(controller),
            icon: _isSavingImport
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save Imported Data'),
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
          spacing: 8,
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
                subtitle: controller.selectedShowId == null
                    ? const Text('Select a show first')
                    : null,
                enabled: controller.selectedShowId != null,
                onTap: controller.selectedShowId != null
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

  Widget _filters(BuildContext context, ProjectController controller) {
    final canFilterDepartment = _isBroadAccess;
    final canFilterClientShow = !_isArtist;

    return SizedBox(
      width: double.infinity,
      child: GlassContainer(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _dropdown<String>(
                  hint: 'Department',
                  value: controller.selectedDepartment,
                  items: controller.departments,
                  label: (d) => d,
                  enabled: canFilterDepartment,
                  onChanged: (v) {
                    if (v != null) {
                      controller.selectDepartment(v);
                      controller.loadShots();
                    }
                  },
                ),
                _dropdown<String>(
                  hint: 'Client',
                  value: controller.selectedClientId,
                  items: controller.clients.map((c) => c.clientId).toList(),
                  label: (id) => controller.clients
                      .firstWhere((c) => c.clientId == id)
                      .clientName,
                  enabled: canFilterClientShow,
                  onChanged: (v) {
                    if (v != null) controller.selectClient(v);
                  },
                ),
                _dropdown<String>(
                  hint: 'Show',
                  value: controller.selectedShowId,
                  items: controller.shows.map((s) => s.showId).toList(),
                  label: (id) => controller.shows
                      .firstWhere((s) => s.showId == id)
                      .showName,
                  enabled: canFilterClientShow,
                  onChanged: (v) {
                    if (v != null) controller.selectShow(v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _importActions(context, controller),
            if (!canFilterDepartment || !canFilterClientShow) ...[
              const SizedBox(height: 8),
              Text(
                !canFilterClientShow
                    ? 'Filters are restricted for your role.'
                    : 'Department is locked based on your role.',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String hint,
    required T? value,
    required List<T> items,
    required String Function(T) label,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
  }) {
    return SizedBox(
      width: 200,
      child: CustomDropdown<T>(
        labelText: hint,
        value: items.contains(value) ? value : null,
        items: items,
        itemToString: label,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  Widget _shots(BuildContext context, ProjectController controller) {
    if (controller.isLoading) {
      return const LoadingWidget();
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

    final rows = List<Map<String, dynamic>>.generate(controller.shots.length, (
      index,
    ) {
      final shot = controller.shots[index];
      return {
        'sno': index + 1,
        'shotId': shot.shotCode,
        'frameIn': shot.frameIn,
        'frameOut': shot.frameOut,
        'supervisorBid': shot.supervisorBid.toStringAsFixed(1),
        'clientBid': shot.clientBid.toStringAsFixed(1),
        'notes': shot.notes ?? '—',
        'task':
            (shot.description != null && shot.description!.trim().isNotEmpty)
            ? shot.description
            : '—',
        'clientEta': _fmtDate(shot.clientEta),
        'status': shot.status,
        'shot': shot,
      };
    });

    final filteredRows = rows
        .where((row) {
          bool contains(String key, String query) {
            if (query.trim().isEmpty) return true;
            return (row[key] ?? '').toString().toLowerCase().contains(
              query.trim().toLowerCase(),
            );
          }

          return contains('shotId', _shotIdFilter) &&
              contains('frameIn', _frameInFilter) &&
              contains('frameOut', _frameOutFilter) &&
              contains('supervisorBid', _supervisorBidFilter) &&
              contains('clientBid', _clientBidFilter) &&
              contains('notes', _notesFilter) &&
              contains('task', _taskFilter) &&
              contains('clientEta', _etaFilter) &&
              contains('status', _statusFilter);
        })
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: GlassContainer(
            child: DynamicDataTable(
              columnSpacing: 10,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              dataRowMinHeight: 48,
              dataRowMaxHeight: 62,
              fields: [
                const DynamicTableField(
                  key: 'sno',
                  label: 'S.No',
                  width: 40,
                  filterRequired: false,
                  numeric: true,
                ),
                const DynamicTableField(
                  key: 'shotId',
                  label: 'Shot ID',
                  width: 140,
                ),
                const DynamicTableField(
                  key: 'frameIn',
                  label: 'Frame In',
                  width: 120,
                  numeric: true,
                ),
                const DynamicTableField(
                  key: 'frameOut',
                  label: 'Frame Out',
                  width: 110,
                  numeric: true,
                ),
                const DynamicTableField(
                  key: 'supervisorBid',
                  label: 'Supervisor Bid',
                  width: 120,
                  numeric: true,
                ),
                const DynamicTableField(
                  key: 'clientBid',
                  label: 'Client Bid',
                  width: 120,
                  numeric: true,
                ),
                const DynamicTableField(
                  key: 'notes',
                  label: 'Notes',
                  width: 220,
                ),
                const DynamicTableField(key: 'task', label: 'Task', width: 240),
                const DynamicTableField(
                  key: 'clientEta',
                  label: 'Client ETA',
                  width: 130,
                ),
                DynamicTableField(
                  key: 'status',
                  label: 'Status',
                  width: 150,
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
                  key: 'actions',
                  filterRequired: false,
                  label: 'Actions',
                  width: 90,
                  builder: (context, value, row, rowIndex) {
                    final shot = row['shot'] as ShotModel;
                    return IconButton(
                      tooltip: 'Edit shot',
                      onPressed: _canCreateShot
                          ? () =>
                                _openShotDialog(context, controller, shot: shot)
                          : null,
                      icon: const Icon(Icons.edit_outlined, size: 18),
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
                    case 'frameIn':
                      _frameInFilter = v;
                      break;
                    case 'frameOut':
                      _frameOutFilter = v;
                      break;
                    case 'supervisorBid':
                      _supervisorBidFilter = v;
                      break;
                    case 'clientBid':
                      _clientBidFilter = v;
                      break;
                    case 'notes':
                      _notesFilter = v;
                      break;
                    case 'task':
                      _taskFilter = v;
                      break;
                    case 'clientEta':
                      _etaFilter = v;
                      break;
                    case 'status':
                      _statusFilter = v;
                      break;
                    default:
                      break;
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _importPreviewTable() {
    final previewRows = List<Map<String, dynamic>>.generate(
      _importDraftRows.length,
      (index) {
        final row = _importDraftRows[index];
        return {
          'shot': (row['shotCode'] ?? '').toString(),
          'frameIn': (row['frameIn'] ?? '').toString(),
          'frameOut': (row['frameOut'] ?? '').toString(),
          'supervisorBid': (row['supervisorBid'] ?? '').toString(),
          'clientBid': (row['clientBid'] ?? '').toString(),
          'eta': (row['clientEta'] ?? '').toString(),
          'status': (row['status'] ?? '').toString(),
        };
      },
    );

    final filteredPreviewRows = previewRows
        .where((row) {
          bool contains(String key, String query) {
            if (query.trim().isEmpty) return true;
            return (row[key] ?? '').toString().toLowerCase().contains(
              query.trim().toLowerCase(),
            );
          }

          return contains('shot', _importShotFilter) &&
              contains('frameIn', _importFrameInFilter) &&
              contains('frameOut', _importFrameOutFilter) &&
              contains('supervisorBid', _importSupervisorBidFilter) &&
              contains('clientBid', _importClientBidFilter) &&
              contains('eta', _importEtaFilter) &&
              contains('status', _importStatusFilter);
        })
        .toList(growable: false);

    return GlassContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Text(
              'Imported Preview (${_importDraftRows.length} rows)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          // Padding(
          //   padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          //   child: Wrap(
          //     spacing: 10,
          //     runSpacing: 10,
          //     children: [
          //       SizedBox(
          //         width: 120,
          //         child: CustomTextField(
          //           labelText: 'Shot ID',
          //           controller: TextEditingController(text: _shotIdFilter),
          //           onChanged: (v) => setState(() {
          //             _shotIdFilter = v;
          //           }),
          //         ),
          //       ),
          //       SizedBox(
          //         width: 110,
          //         child: CustomTextField(
          //           labelText: 'Frame In',
          //           controller: TextEditingController(text: _frameInFilter),
          //           onChanged: (v) => setState(() {
          //             _frameInFilter = v;
          //           }),
          //         ),
          //       ),
          //       SizedBox(
          //         width: 110,
          //         child: CustomTextField(
          //           labelText: 'Frame Out',
          //           controller: TextEditingController(text: _frameOutFilter),
          //           onChanged: (v) => setState(() {
          //             _frameOutFilter = v;
          //           }),
          //         ),
          //       ),

          //       SizedBox(
          //         width: 130,
          //         child: CustomTextField(
          //           labelText: 'Supervisor Bid',
          //           controller: TextEditingController(
          //             text: _supervisorBidFilter,
          //           ),
          //           onChanged: (v) => setState(() {
          //             _supervisorBidFilter = v;
          //           }),
          //         ),
          //       ),
          //       SizedBox(
          //         width: 120,
          //         child: CustomTextField(
          //           labelText: 'Client Bid',
          //           controller: TextEditingController(text: _clientBidFilter),
          //           onChanged: (v) => setState(() {
          //             _clientBidFilter = v;
          //           }),
          //         ),
          //       ),
          //       SizedBox(
          //         width: 160,
          //         child: CustomTextField(
          //           labelText: 'Notes',
          //           controller: TextEditingController(text: _notesFilter),
          //           onChanged: (v) => setState(() {
          //             _notesFilter = v;
          //           }),
          //         ),
          //       ),
          //       SizedBox(
          //         width: 120,
          //         child: CustomTextField(
          //           labelText: 'ETA',
          //           controller: TextEditingController(text: _importEtaFilter),
          //           onChanged: (v) => setState(() {
          //             _importEtaFilter = v;
          //           }),
          //         ),
          //       ),

          //       OutlinedButton(
          //         onPressed: () {
          //           setState(() {
          //             _importShotFilter = '';
          //             _importFrameInFilter = '';
          //             _importFrameOutFilter = '';
          //             _importSupervisorBidFilter = '';
          //             _importClientBidFilter = '';
          //             _importEtaFilter = '';
          //             _importStatusFilter = '';
          //           });
          //         },
          //         child: const Text('Clear Filters'),
          //       ),
          //     ],
          //   ),
          // ),
          DynamicDataTable(
            height: 240,
            columnSpacing: 10,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            headingRowHeight: 40,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 52,
            fields: const [
              DynamicTableField(key: 'shot', label: 'Shot', width: 140),
              DynamicTableField(key: 'frameIn', label: 'Frame In', width: 100),
              DynamicTableField(
                key: 'frameOut',
                label: 'Frame Out',
                width: 100,
              ),
              DynamicTableField(
                key: 'supervisorBid',
                label: 'Supervisor Bid',
                width: 120,
              ),
              DynamicTableField(
                key: 'clientBid',
                label: 'Client Bid',
                width: 110,
              ),
              DynamicTableField(key: 'eta', label: 'ETA', width: 120),
              DynamicTableField(key: 'status', label: 'Status', width: 140),
            ],
            rows: filteredPreviewRows,
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
      final rows = _parseImportRows(bytes, extension, controller);
      if (!mounted) return;
      setState(() {
        _importDraftRows
          ..clear()
          ..addAll(rows);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${rows.length} rows for review')),
      );
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
          width: MediaQuery.of(dialogContext).size.width < 700
              ? MediaQuery.of(dialogContext).size.width * 0.92
              : 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste CSV with headers like: shot_id,frame_in,frame_out,supervisor_bid,client_bid,client_eta,status,notes',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _csvPasteController,
                minLines: 8,
                maxLines: 14,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText:
                      'shot_id,frame_in,frame_out,supervisor_bid,client_bid,client_eta,status,notes',
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
      final rows = _parseCsvTextRows(_csvPasteController.text, controller);
      if (!mounted) return;
      setState(() {
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

  List<Map<String, dynamic>> _parseCsvTextRows(
    String csvText,
    ProjectController controller,
  ) {
    final lines = const LineSplitter().convert(csvText.trim());
    if (lines.length < 2) {
      return const [];
    }

    final headers = _splitCsvLine(
      lines.first,
    ).map(_normalizeHeader).toList(growable: false);
    final out = <Map<String, dynamic>>[];

    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final values = _splitCsvLine(lines[i]);
      final raw = <String, dynamic>{};
      for (var c = 0; c < headers.length; c++) {
        final key = headers[c];
        if (key.isEmpty) continue;
        raw[key] = c < values.length ? values[c].trim() : null;
      }

      final apiRow = _toApiImportRow(raw, controller);
      if ((apiRow['shotCode'] ?? '').toString().isNotEmpty) {
        out.add(apiRow);
      }
    }

    return out;
  }

  Future<void> _exportShotsAsExcel(ProjectController controller) async {
    final shots = controller.shots;
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
        TextCellValue('frame_in'),
        TextCellValue('frame_out'),
        TextCellValue('supervisor_bid'),
        TextCellValue('client_bid'),
        TextCellValue('client_eta'),
        TextCellValue('status'),
        TextCellValue('notes'),
      ]);

      for (final shot in shots) {
        sheet.appendRow([
          TextCellValue(shot.shotCode),
          IntCellValue(shot.frameIn),
          IntCellValue(shot.frameOut),
          DoubleCellValue(shot.supervisorBid),
          DoubleCellValue(shot.clientBid),
          TextCellValue(_fmtDate(shot.clientEta)),
          TextCellValue(shot.status),
          TextCellValue(shot.notes ?? ''),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Unable to generate Excel file');
      }

      final fileName =
          'projects_${DateTime.now().toIso8601String().replaceAll(':', '-')}.xlsx';
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

  List<Map<String, dynamic>> _parseImportRows(
    Uint8List bytes,
    String extension,
    ProjectController controller,
  ) {
    if (extension == 'xlsx') {
      return _parseExcelRows(bytes, controller);
    }
    if (extension == 'csv') {
      return _parseCsvRows(bytes, controller);
    }
    if (extension.isEmpty) {
      throw UnsupportedError(
        'Unsupported file type. Please use .xlsx or .csv files.',
      );
    }
    throw UnsupportedError(
      'The .$extension format is not supported for import. Please convert to .xlsx or .csv.',
    );
  }

  List<Map<String, dynamic>> _parseExcelRows(
    Uint8List bytes,
    ProjectController controller,
  ) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return const [];

    final firstSheet = excel.tables.values.first;
    final rows = firstSheet.rows;
    if (rows.length < 2) return const [];

    final headers = rows.first
        .map((c) => _normalizeHeader(c?.value?.toString() ?? ''))
        .toList();

    final out = <Map<String, dynamic>>[];
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.every((c) => (c?.value?.toString().trim() ?? '').isEmpty)) {
        continue;
      }
      final raw = <String, dynamic>{};
      for (var c = 0; c < headers.length; c++) {
        final key = headers[c];
        if (key.isEmpty) continue;
        final cell = c < r.length ? r[c] : null;
        raw[key] = cell?.value;
      }
      final apiRow = _toApiImportRow(raw, controller);
      if ((apiRow['shotCode'] ?? '').toString().isNotEmpty) {
        out.add(apiRow);
      }
    }
    return out;
  }

  List<Map<String, dynamic>> _parseCsvRows(
    Uint8List bytes,
    ProjectController controller,
  ) {
    final csv = utf8.decode(bytes, allowMalformed: true);
    final lines = const LineSplitter().convert(csv);
    if (lines.length < 2) return const [];

    final headers = _splitCsvLine(
      lines.first,
    ).map(_normalizeHeader).toList(growable: false);

    final out = <Map<String, dynamic>>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final values = _splitCsvLine(lines[i]);
      final raw = <String, dynamic>{};
      for (var c = 0; c < headers.length; c++) {
        final key = headers[c];
        if (key.isEmpty) continue;
        raw[key] = c < values.length ? values[c].trim() : null;
      }

      final apiRow = _toApiImportRow(raw, controller);
      if ((apiRow['shotCode'] ?? '').toString().isNotEmpty) {
        out.add(apiRow);
      }
    }
    return out;
  }

  List<String> _splitCsvLine(String line) {
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

  String _normalizeHeader(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll('.', '');
  }

  dynamic _pickAny(Map<String, dynamic> row, List<String> keys) {
    for (final k in keys) {
      if (row.containsKey(k) && row[k] != null) return row[k];
    }
    return null;
  }

  String? _toIsoDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) {
      return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    }
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    }
    return text;
  }

  int _toIntValue(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim()) ?? 0;
  }

  double _toDoubleValue(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0;
  }

  Map<String, dynamic> _toApiImportRow(
    Map<String, dynamic> row,
    ProjectController controller,
  ) {
    final shotCode =
        (_pickAny(row, ['shot_id', 'shot', 'shotcode', 'shot_id_code']) ??
                _pickAny(row, ['shot_code']) ??
                '')
            .toString()
            .trim();
    final statusRaw = (_pickAny(row, ['status']) ?? 'Awaiting Approval')
        .toString()
        .trim();
    final status = AppConstants.shotStatuses.contains(statusRaw)
        ? statusRaw
        : 'Awaiting Approval';

    return {
      'showId': controller.selectedShowId,
      'department': controller.selectedDepartment,
      'shotCode': shotCode,
      'frameIn': _toIntValue(_pickAny(row, ['frame_in', 'framein'])),
      'frameOut': _toIntValue(_pickAny(row, ['frame_out', 'frameout'])),
      'supervisorBid': _toDoubleValue(
        _pickAny(row, ['supervisor_bid', 'supervisorbid']),
      ),
      'clientBid': _toDoubleValue(_pickAny(row, ['client_bid', 'clientbid'])),
      'clientEta': _toIsoDate(_pickAny(row, ['client_eta', 'eta'])),
      'notes': (_pickAny(row, ['notes', 'description']) ?? '').toString(),
      'status': status,
    };
  }

  Future<void> _saveImportedRows(ProjectController controller) async {
    setState(() => _isSavingImport = true);
    try {
      final response = await controller.bulkUpsertShots(_importDraftRows);
      if (!mounted) return;
      if (response == null) {
        final message = controller.error ?? 'Unable to save imported data';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return;
      }
      final created = response['created'] ?? 0;
      final updated = response['updated'] ?? 0;
      final errors =
          ((response['errors'] as List<dynamic>?) ?? const []).length;
      setState(() => _importDraftRows.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved imported rows. Created: $created, Updated: $updated, Errors: $errors',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingImport = false);
    }
  }

  String _fmtDate(DateTime? d) => d == null
      ? '—'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
            const SizedBox(height: 8),
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
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
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
            const SizedBox(height: 8),
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
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
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
  late final TextEditingController _frameIn;
  late final TextEditingController _frameOut;
  late final TextEditingController _supBid;
  late final TextEditingController _cliBid;
  late final TextEditingController _notes;
  late final TextEditingController _description;
  late final TextEditingController _clientEta;
  late final TextEditingController _dueDate;
  late final List<String> _accessibleDepartments;
  late String _department;
  late String _status;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.shot;
    _code = TextEditingController(text: s?.shotCode ?? '');
    _frameIn = TextEditingController(text: s != null ? '${s.frameIn}' : '');
    _frameOut = TextEditingController(text: s != null ? '${s.frameOut}' : '');
    _supBid = TextEditingController(
      text: s != null ? '${s.supervisorBid}' : '',
    );
    _cliBid = TextEditingController(text: s != null ? '${s.clientBid}' : '');
    _notes = TextEditingController(text: s?.notes ?? '');
    _description = TextEditingController(text: s?.description ?? '');
    _clientEta = TextEditingController(
      text: s?.clientEta != null
          ? '${s!.clientEta!.year.toString().padLeft(4, '0')}-${s.clientEta!.month.toString().padLeft(2, '0')}-${s.clientEta!.day.toString().padLeft(2, '0')}'
          : '',
    );
    _dueDate = TextEditingController(
      text: s?.dueDate != null
          ? '${s!.dueDate!.year.toString().padLeft(4, '0')}-${s.dueDate!.month.toString().padLeft(2, '0')}-${s.dueDate!.day.toString().padLeft(2, '0')}'
          : '',
    );
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
  }

  @override
  void dispose() {
    _code.dispose();
    _frameIn.dispose();
    _frameOut.dispose();
    _supBid.dispose();
    _cliBid.dispose();
    _notes.dispose();
    _description.dispose();
    _clientEta.dispose();
    _dueDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.of(context).size.width;
    final dialogWidth = availableWidth < 560 ? availableWidth * 0.9 : 420.0;

    return AlertDialog(
      title: Text(widget.shot == null ? 'New Shot' : 'Edit Shot'),
      content: SizedBox(
        width: dialogWidth,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                CustomTextField(
                  controller: _code,
                  labelText: 'Shot code',
                  prefixIcon: Icons.confirmation_number_outlined,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                CustomDropdown<String>(
                  labelText: 'Department',
                  value: _department,
                  items: _accessibleDepartments,
                  itemToString: (d) => d,
                  onChanged: (v) => setState(() => _department = v!),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: dialogWidth > 390
                          ? (dialogWidth - 12) / 2
                          : dialogWidth,
                      child: CustomTextField(
                        controller: _frameIn,
                        labelText: 'Frame In',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(
                      width: dialogWidth > 390
                          ? (dialogWidth - 12) / 2
                          : dialogWidth,
                      child: CustomTextField(
                        controller: _frameOut,
                        labelText: 'Frame Out',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: dialogWidth > 390
                          ? (dialogWidth - 12) / 2
                          : dialogWidth,
                      child: CustomTextField(
                        controller: _supBid,
                        labelText: 'Supervisor Bid',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(
                      width: dialogWidth > 390
                          ? (dialogWidth - 12) / 2
                          : dialogWidth,
                      child: CustomTextField(
                        controller: _cliBid,
                        labelText: 'Client Bid',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                CustomDropdown<String>(
                  labelText: 'Status',
                  value: _status,
                  items: AppConstants.shotStatuses,
                  itemToString: (s) => s,
                  onChanged: (v) {
                    if (v != null) setState(() => _status = v);
                  },
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: dialogWidth > 390
                          ? (dialogWidth - 12) / 2
                          : dialogWidth,
                      child: CustomTextField(
                        controller: _clientEta,
                        labelText: 'Client ETA',
                        isDateField: true,
                        onDateTap: _pickClientEta,
                      ),
                    ),
                    SizedBox(
                      width: dialogWidth > 390
                          ? (dialogWidth - 12) / 2
                          : dialogWidth,
                      child: CustomTextField(
                        controller: _dueDate,
                        labelText: 'Due Date',
                        isDateField: true,
                        onDateTap: _pickDueDate,
                      ),
                    ),
                  ],
                ),
                CustomTextField(
                  controller: _notes,
                  labelText: 'Notes',
                  maxLines: 2,
                ),
                CustomTextField(
                  controller: _description,
                  labelText: 'Description',
                  maxLines: 2,
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
      'frameIn': int.tryParse(_frameIn.text) ?? 0,
      'frameOut': int.tryParse(_frameOut.text) ?? 0,
      'supervisorBid': double.tryParse(_supBid.text) ?? 0,
      'clientBid': double.tryParse(_cliBid.text) ?? 0,
      'status': _status,
      'clientEta': _clientEta.text.trim().isEmpty
          ? null
          : _clientEta.text.trim(),
      'dueDate': _dueDate.text.trim().isEmpty ? null : _dueDate.text.trim(),
      'notes': _notes.text.trim(),
      'description': _description.text.trim(),
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

  Future<void> _pickClientEta(BuildContext context) async {
    final dateStr = _clientEta.text.trim();
    DateTime initialDate = DateTime.now();
    try {
      if (dateStr.isNotEmpty) {
        initialDate = DateTime.parse(dateStr);
      }
    } catch (_) {
      // Use default date if parse fails
    }

    if (!mounted) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      final formatted =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() => _clientEta.text = formatted);
    }
  }

  Future<void> _pickDueDate(BuildContext context) async {
    final dateStr = _dueDate.text.trim();
    DateTime initialDate = DateTime.now();
    try {
      if (dateStr.isNotEmpty) {
        initialDate = DateTime.parse(dateStr);
      }
    } catch (_) {
      // Use default date if parse fails
    }

    if (!mounted) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      final formatted =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() => _dueDate.text = formatted);
    }
  }
}
