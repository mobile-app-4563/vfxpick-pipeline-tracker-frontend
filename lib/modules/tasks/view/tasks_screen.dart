import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vfxpick_pipeline/shared/widgets/custom_dropdown.dart';
import 'package:vfxpick_pipeline/shared/widgets/custom_text_field.dart';
import 'package:vfxpick_pipeline/shared/widgets/dynamic_data_table.dart';
import 'package:vfxpick_pipeline/shared/widgets/filter_icon.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/models/shot_model.dart';
import '../../../core/services/team_service.dart';
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
  final TextEditingController _csvPasteController = TextEditingController();
  bool _isArtist = false;
  bool _isBroadAccess = false;
  List<String> _accessibleDepartments = AppConstants.pipelineDepartments;
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = context.read<AuthController>().currentUser;
      final query = GoRouterState.of(context).uri.queryParameters;
      final dashboardDept = query['department'];
      _isArtist = user?.role == AppConstants.roleArtist;
      _isBroadAccess = AppConstants.broadAccessRoles.contains(user?.role);
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
  void dispose() {
    _csvPasteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TaskController>();
    if (_isArtist) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _actionBar(controller),
          const SizedBox(height: 12),
          Expanded(child: _ArtistPortal(controller: controller)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: const Text(
                'Select department.',
                style: TextStyle(fontSize: 16),
              ),
            ),
            _filters(context, controller),
          ],
        ),

        if (_importDraftRows.isNotEmpty) ...[
          const SizedBox(height: 12),
          _importPreviewTable(),
        ],

        const SizedBox(height: 12),
        Expanded(child: _DepartmentView(controller: controller)),
      ],
    );
  }

  Widget _actionBar(TaskController controller) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          ElevatedButton.icon(
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
            onPressed: _isImporting
                ? null
                : () => _openPasteCsvDialog(controller),
            icon: const Icon(Icons.content_paste_go_outlined),
            label: const Text('Paste CSV'),
          ),
        ],
      ),
    );
  }

  Widget _importActions(BuildContext context, TaskController controller) {
    final canImport = controller.selectedDepartment != null;

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
      ],
    );
  }

  Widget _filters(BuildContext context, TaskController controller) {
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
                  label: _clientNameFor,
                  enabled: canFilterClientShow,
                  onChanged: (v) async {
                    if (v != null) await controller.selectClient(v);
                  },
                ),
                _dropdown<String>(
                  hint: 'Show',
                  value: controller.selectedShowId,
                  items: controller.shows.map((s) => s.showId).toList(),
                  label: _showNameFor,
                  enabled: canFilterClientShow,
                  onChanged: (v) async {
                    if (v != null) await controller.selectShow(v);
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

  String _clientNameFor(String clientId) {
    final controller = context.read<TaskController>();
    for (final client in controller.clients) {
      if (client.clientId == clientId) return client.clientName;
    }
    return clientId;
  }

  String _showNameFor(String showId) {
    final controller = context.read<TaskController>();
    for (final show in controller.shows) {
      if (show.showId == showId) return show.showName;
    }
    return showId;
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
          TextCellValue(_fmtDate(shot.artistEta)),
          TextCellValue(_fmtDate(shot.clientEta)),
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

  Future<void> _openPasteCsvDialog(TaskController controller) async {
    _csvPasteController.clear();
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paste CSV Status Updates'),
        content: SizedBox(
          width: MediaQuery.of(dialogContext).size.width < 700
              ? MediaQuery.of(dialogContext).size.width * 0.92
              : 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isArtist
                    ? 'Headers: shot_id,artist_status'
                    : 'Headers: shot_id,supervisor_status,artist_status',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _csvPasteController,
                minLines: 8,
                maxLines: 14,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                  hintText: 'shot_id,supervisor_status,artist_status',
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
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (shouldImport != true) {
      return;
    }

    setState(() => _isImporting = true);
    try {
      final parsed = _parseCsv(_csvPasteController.text);
      setState(() {
        _importDraftRows
          ..clear()
          ..addAll(parsed);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${parsed.length} rows for review')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV import failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Widget _importPreviewTable() {
    final previewRows = List<Map<String, dynamic>>.generate(
      _importDraftRows.length,
      (index) {
        final row = _importDraftRows[index];
        return {
          'shot': (row['shot_id'] ?? row['shot_code'] ?? row['shot'] ?? '')
              .toString(),
          'supervisorStatus': (row['supervisor_status'] ?? '').toString(),
          'artistStatus': (row['artist_status'] ?? '').toString(),
        };
      },
    );

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
          DynamicDataTable(
            headingRowHeight: 40,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 52,
            fields: const [
              DynamicTableField(key: 'shot', label: 'Shot', width: 160),
              DynamicTableField(
                key: 'supervisorStatus',
                label: 'Supervisor Status',
                width: 180,
              ),
              DynamicTableField(
                key: 'artistStatus',
                label: 'Artist Status',
                width: 160,
              ),
            ],
            rows: previewRows,
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _parseCsv(String csvText) {
    final lines = const LineSplitter().convert(csvText.trim());
    if (lines.length < 2) {
      return const [];
    }

    final headers = _splitCsvLine(lines.first)
        .map(
          (h) =>
              h.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_'),
        )
        .toList(growable: false);

    final out = <Map<String, String>>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final values = _splitCsvLine(lines[i]);
      final row = <String, String>{};
      for (var c = 0; c < headers.length; c++) {
        if (headers[c].isEmpty) continue;
        row[headers[c]] = c < values.length ? values[c].trim() : '';
      }
      out.add(row);
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
}

String _fmtDate(DateTime? d) => d == null
    ? '—'
    : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _ArtistPortal extends StatefulWidget {
  final TaskController controller;
  const _ArtistPortal({required this.controller});

  @override
  State<_ArtistPortal> createState() => _ArtistPortalState();
}

class _ArtistPortalState extends State<_ArtistPortal> {
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
              _contains('${shot.frameIn} - ${shot.frameOut}', _framesFilter) &&
              _contains(shot.status, _clientStatusFilter) &&
              _contains(shot.artistStatus, _artistStatusFilter) &&
              _contains(
                shot.supervisorStatus ?? '—',
                _supervisorStatusFilter,
              ) &&
              _contains(_fmtDate(shot.artistEta), _artistEtaFilter) &&
              _contains(_fmtDate(shot.clientEta), _clientEtaFilter);
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
        'artistEta': _fmtDate(shot.artistEta),
        'clientEta': _fmtDate(shot.clientEta),
        'shot': shot,
      };
    });

    return RefreshIndicator(
      onRefresh: controller.loadArtistShots,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          GlassContainer(
            padding: const EdgeInsets.all(10),
            borderRadius: 2,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final searchWidth = constraints.maxWidth < 320
                    ? constraints.maxWidth
                    : 260.0;
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: searchWidth,
                      child: CustomTextField(
                        onChanged: (v) => setState(() => _shotIdFilter = v),
                        labelText: 'Search shot / show',
                        suffixIcon: Icons.search,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
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
          const SizedBox(height: 8),
          GlassContainer(
            padding: const EdgeInsets.all(8),
            child: DynamicDataTable(
              headingRowHeight: 42,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 56,
              fields: [
                const DynamicTableField(
                  key: 'sno',
                  label: 'S.No',
                  width: 60,
                  numeric: true,
                  filterRequired: false,
                ),
                const DynamicTableField(
                  key: 'shotId',
                  label: 'Shot ID',
                  width: 130,
                ),
                const DynamicTableField(key: 'show', label: 'Show', width: 140),
                const DynamicTableField(
                  key: 'frames',
                  label: 'Frames',
                  width: 120,
                ),
                DynamicTableField(
                  key: 'clientStatus',
                  label: 'Client Status',
                  width: 140,
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
                      width: 170,
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
                  width: 160,
                  filterOptions: _buildOptions(
                    AppConstants.supervisorStatuses,
                    _supervisorStatusFilter,
                  ),
                ),
                const DynamicTableField(
                  key: 'artistEta',
                  label: 'Artist ETA',
                  width: 130,
                ),
                const DynamicTableField(
                  key: 'clientEta',
                  label: 'Client ETA',
                  width: 130,
                ),
                DynamicTableField(
                  key: 'actions',
                  label: 'Actions',
                  width: 90,
                  filterRequired: false,
                  builder: (context, value, row, rowIndex) {
                    final shot = row['shot'] as ShotModel;
                    return IconButton(
                      tooltip: 'Chat',
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
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
          ),
        ],
      ),
    );
  }
}

class _DepartmentView extends StatefulWidget {
  final TaskController controller;
  const _DepartmentView({required this.controller});

  @override
  State<_DepartmentView> createState() => _DepartmentViewState();
}

class _DepartmentViewState extends State<_DepartmentView> {
  String _shotIdFilter = '';
  String _clientFilter = '';
  String _showFilter = '';
  String _frameInFilter = '';
  String _frameOutFilter = '';
  String _supervisorBidFilter = '';
  String _clientBidFilter = '';
  String _artistFilter = '';
  String _artistBidFilter = '';
  String _artistEtaFilter = '';
  String _supervisorStatusFilter = '';
  String _artistStatusFilter = '';

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

    final filteredShots = controller.departmentShots
        .where((shot) {
          return _contains(shot.shotCode, _shotIdFilter) &&
              _contains(
                shot.clientName ?? shot.clientId ?? '—',
                _clientFilter,
              ) &&
              _contains(shot.showName ?? '—', _showFilter) &&
              _contains(shot.frameIn, _frameInFilter) &&
              _contains(shot.frameOut, _frameOutFilter) &&
              _contains(
                shot.supervisorBid.toStringAsFixed(1),
                _supervisorBidFilter,
              ) &&
              _contains(shot.clientBid.toStringAsFixed(1), _clientBidFilter) &&
              _contains(shot.artistName ?? 'Unassigned', _artistFilter) &&
              _contains(shot.artistBid.toStringAsFixed(1), _artistBidFilter) &&
              _contains(_fmtDate(shot.artistEta), _artistEtaFilter) &&
              _contains(
                shot.supervisorStatus ?? '—',
                _supervisorStatusFilter,
              ) &&
              _contains(shot.artistStatus, _artistStatusFilter);
        })
        .toList(growable: false);

    final rows = filteredShots
        .map((shot) {
          return {
            'sno': filteredShots.indexOf(shot) + 1,
            'shotId': shot.shotCode,
            'client': shot.clientName ?? shot.clientId ?? '—',
            'show': shot.showName ?? '—',
            'frameIn': shot.frameIn,
            'frameOut': shot.frameOut,
            'supervisorBid': shot.supervisorBid.toStringAsFixed(1),
            'clientBid': shot.clientBid.toStringAsFixed(1),
            'artist': shot.artistName ?? 'Unassigned',
            'artistBid': shot.artistBid.toStringAsFixed(1),
            'artistEta': _fmtDate(shot.artistEta),
            'supervisorStatus': shot.supervisorStatus ?? '—',
            'artistStatus': shot.artistStatus,
            'shot': shot,
          };
        })
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () => controller.loadDepartmentShots(
        department: controller.selectedDepartment,
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          GlassContainer(
            padding: const EdgeInsets.all(8),
            child: DynamicDataTable(
              fields: [
                const DynamicTableField(
                  key: 'sno',
                  label: 'S.No',
                  width: 60,
                  numeric: true,
                  filterRequired: false,
                ),
                const DynamicTableField(
                  key: 'shotId',
                  label: 'Shot ID',
                  width: 120,
                ),
                const DynamicTableField(
                  key: 'client',
                  label: 'Client',
                  width: 160,
                ),
                const DynamicTableField(key: 'show', label: 'Show', width: 140),
                const DynamicTableField(
                  key: 'frameIn',
                  label: 'Frame In',
                  width: 100,
                  numeric: true,
                ),
                const DynamicTableField(
                  key: 'frameOut',
                  label: 'Frame Out',
                  width: 100,
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
                  key: 'artist',
                  label: 'Artist',
                  width: 150,
                ),
                const DynamicTableField(
                  key: 'artistBid',
                  label: 'Artist Bid',
                  width: 110,
                  numeric: true,
                ),
                const DynamicTableField(
                  key: 'artistEta',
                  label: 'Artist ETA',
                  width: 120,
                ),
                DynamicTableField(
                  key: 'supervisorStatus',
                  label: 'Supervisor Status',
                  width: 150,
                  filterOptions: _buildOptions(
                    AppConstants.supervisorStatuses,
                    _supervisorStatusFilter,
                  ),
                ),
                DynamicTableField(
                  key: 'artistStatus',
                  label: 'Artist Status',
                  width: 150,
                  filterOptions: _buildOptions(
                    AppConstants.artistStatuses,
                    _artistStatusFilter,
                  ),
                ),
                DynamicTableField(
                  key: 'actions',
                  label: 'Actions',
                  width: 140,
                  filterRequired: false,
                  builder: (context, value, row, rowIndex) {
                    final shot = row['shot'] as ShotModel;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Assign artist',
                          icon: const Icon(Icons.person_add_alt, size: 18),
                          onPressed: () => _assign(context, shot),
                        ),
                        IconButton(
                          tooltip: 'Chat',
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
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
                  final query = value is String ? value : value.toString();
                  switch (fieldKey) {
                    case 'shotId':
                      _shotIdFilter = query;
                      break;
                    case 'client':
                      _clientFilter = query;
                      break;
                    case 'show':
                      _showFilter = query;
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
                      _supervisorStatusFilter = query;
                      break;
                    case 'artistStatus':
                      _artistStatusFilter = query;
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
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
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
