import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vfxpick_pipeline/shared/widgets/custom_dropdown.dart';
import 'package:vfxpick_pipeline/shared/widgets/custom_text_field.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/models/shot_model.dart';
import '../../../core/services/task_service.dart';
import '../../../shared/widgets/dynamic_data_table.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/teams_controller.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final List<Map<String, dynamic>> _importDraftRows = [];
  final TextEditingController _csvPasteController = TextEditingController();

  bool _exporting = false;
  bool _isImporting = false;
  bool _isSavingImport = false;
  String _importDepartmentFilter = '';
  String _importNameFilter = '';
  String _importEmailFilter = '';
  String _importRoleFilter = '';
  String _importLevelFilter = '';

  // Main table filters
  String _deptFilter = '';
  String _nameFilter = '';
  String _roleFilter = '';
  String _levelFilter = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeamController>().loadTeams();
    });
  }

  @override
  void dispose() {
    _csvPasteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TeamController>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brandGreen,
        foregroundColor: Colors.white,
        onPressed: () => _addMember(context, controller),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Member'),
      ),
      body: _body(context, controller),
    );
  }

  Widget _body(BuildContext context, TeamController controller) {
    if (controller.isLoading && controller.teams.isEmpty) {
      return const LoadingWidget(message: 'Loading teams...');
    }
    if (controller.teams.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.groups_outlined,
        title: 'No teams',
        description: 'No artists found for your accessible departments.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => controller.loadTeams(),
      child: ListView(
        children: [
          GlassContainer(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _exporting
                      ? null
                      : () => _exportTeamsAsExcel(controller),
                  icon: _exporting
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
                OutlinedButton.icon(
                  onPressed: _isImporting
                      ? null
                      : () => _pickAndParseImportFile(controller),
                  icon: _isImporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: const Text('Import File'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    foregroundColor: Colors.white,
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
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_importDraftRows.isNotEmpty) ...[
            _importPreviewTable(),
            const SizedBox(height: 12),
          ],
          _membersTable(controller),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _membersTable(TeamController controller) {
    bool _matches(String value, String query) {
      if (query.trim().isEmpty) return true;
      return value.toLowerCase().contains(query.trim().toLowerCase());
    }

    final allRows = <Map<String, dynamic>>[];
    for (final department in controller.teams) {
      for (final member in department.members) {
        allRows.add({
          'department': department.department,
          'name': member.name,
          'role': member.role,
          'level': member.level ?? '-',
          'member': member,
        });
      }
    }

    final rows = allRows
        .where((row) {
          return _matches(row['department'] as String, _deptFilter) &&
              _matches(row['name'] as String, _nameFilter) &&
              _matches(row['role'] as String, _roleFilter) &&
              _matches(row['level'] as String, _levelFilter);
        })
        .toList(growable: false);

    return GlassContainer(
      child: DynamicDataTable(
        fields: [
          const DynamicTableField(
            key: 'department',
            label: 'Department',
            width: 140,
          ),
          const DynamicTableField(key: 'name', label: 'Name', width: 200),
          const DynamicTableField(key: 'role', label: 'Role', width: 150),
          const DynamicTableField(key: 'level', label: 'Level', width: 110),
          DynamicTableField(
            key: 'actions',
            label: 'Actions',
            width: 220,
            filterRequired: false,
            builder: (context, value, row, rowIndex) {
              final member = row['member'];
              if (member is! TeamMember) {
                return const SizedBox.shrink();
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Assign task',
                    onPressed: () => _assignTask(context, member),
                    icon: const Icon(Icons.add_task_outlined),
                  ),
                  IconButton(
                    tooltip: 'Edit member',
                    onPressed: () => _editMember(context, controller, member),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Remove member',
                    onPressed: () => _removeMember(context, controller, member),
                    icon: const Icon(Icons.person_remove_alt_1_outlined),
                  ),
                ],
              );
            },
          ),
        ],
        rows: rows,
        headingRowHeight: 44,
        dataRowMinHeight: 50,
        dataRowMaxHeight: 58,
        columnSpacing: 16,
        onFilterChanged: (fieldKey, value) {
          setState(() {
            final v = value?.toString() ?? '';
            switch (fieldKey) {
              case 'department':
                _deptFilter = v;
                break;
              case 'name':
                _nameFilter = v;
                break;
              case 'role':
                _roleFilter = v;
                break;
              case 'level':
                _levelFilter = v;
                break;
            }
          });
        },
        empty: const EmptyStateWidget(
          icon: Icons.groups_outlined,
          title: 'No team members',
          description: 'No artists found for your accessible departments.',
        ),
      ),
    );
  }

  Future<void> _assignTask(BuildContext context, TeamMember member) async {
    final assigned = await showDialog<bool>(
      context: context,
      builder: (_) => _AssignTaskDialog(member: member),
    );
    if (assigned == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task assigned to ${member.name}')),
      );
    }
  }

  Future<void> _editMember(
    BuildContext context,
    TeamController controller,
    TeamMember member,
  ) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _EditMemberDialog(
        member: member,
        controller: controller,
        roleOptions: controller.roleOptions,
        departmentOptions: controller.departmentOptions,
      ),
    );
    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${member.name} updated')));
    }
  }

  Future<void> _removeMember(
    BuildContext context,
    TeamController controller,
    TeamMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove member'),
        content: Text(
          'Remove ${member.name} from the team? '
          'Their assigned shots will be unassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.priorityHigh,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final err = await controller.removeMember(member.userId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err == null ? '${member.name} removed' : 'Failed: $err'),
      ),
    );
  }

  Future<void> _exportTeamsAsExcel(TeamController controller) async {
    if (controller.teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No team data available to export.')),
      );
      return;
    }

    setState(() => _exporting = true);
    try {
      final excel = Excel.createExcel();
      final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
      final sheet = excel[sheetName];

      sheet.appendRow([
        TextCellValue('department'),
        TextCellValue('name'),
        TextCellValue('role'),
        TextCellValue('level'),
        TextCellValue('user_id'),
      ]);

      for (final department in controller.teams) {
        for (final member in department.members) {
          sheet.appendRow([
            TextCellValue(department.department),
            TextCellValue(member.name),
            TextCellValue(member.role),
            TextCellValue(member.level ?? ''),
            TextCellValue(member.userId),
          ]);
        }
      }

      final bytes = excel.encode();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Unable to generate Excel file');
      }

      final fileName =
          'teams_${DateTime.now().toIso8601String().replaceAll(':', '-')}.xlsx';
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
        setState(() => _exporting = false);
      }
    }
  }

  Widget _importPreviewTable() {
    final rows = List<Map<String, dynamic>>.generate(_importDraftRows.length, (
      i,
    ) {
      final row = _importDraftRows[i];
      return {
        'department': (row['department'] ?? '').toString(),
        'name': (row['name'] ?? '').toString(),
        'email': (row['email'] ?? '').toString(),
        'role': (row['role'] ?? '').toString(),
        'level': (row['level'] ?? '').toString(),
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

          return contains('department', _importDepartmentFilter) &&
              contains('name', _importNameFilter) &&
              contains('email', _importEmailFilter) &&
              contains('role', _importRoleFilter) &&
              contains('level', _importLevelFilter);
        })
        .toList(growable: false);

    return GlassContainer(
      child: Column(
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
            height: 250,
            headingRowHeight: 40,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 52,
            fields: const [
              DynamicTableField(
                key: 'department',
                label: 'Department',
                width: 140,
              ),
              DynamicTableField(key: 'name', label: 'Name', width: 160),
              DynamicTableField(key: 'email', label: 'Email', width: 220),
              DynamicTableField(key: 'role', label: 'Role', width: 130),
              DynamicTableField(key: 'level', label: 'Level', width: 110),
            ],
            rows: filteredRows,
            onFilterChanged: (fieldKey, value) {
              setState(() {
                final v = value is String ? value : value.toString();
                switch (fieldKey) {
                  case 'department':
                    _importDepartmentFilter = v;
                    break;
                  case 'name':
                    _importNameFilter = v;
                    break;
                  case 'email':
                    _importEmailFilter = v;
                    break;
                  case 'role':
                    _importRoleFilter = v;
                    break;
                  case 'level':
                    _importLevelFilter = v;
                    break;
                  default:
                    break;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndParseImportFile(TeamController controller) async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
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
      final rows = _parseImportRows(bytes, extension);
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

  Future<void> _openPasteCsvDialog(TeamController controller) async {
    _csvPasteController.clear();
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paste Team CSV Data'),
        content: SizedBox(
          width: MediaQuery.of(dialogContext).size.width < 700
              ? MediaQuery.of(dialogContext).size.width * 0.92
              : 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Headers: name,email,department,role,level',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              // TextField(
              //   controller: _csvPasteController,
              //   minLines: 8,
              //   maxLines: 14,
              //   decoration: const InputDecoration(
              //     border: OutlineInputBorder(),
              //     hintText: 'name,email,department,role,level',
              //   ),
              // ),
              CustomTextField(
                controller: _csvPasteController,
                labelText: 'CSV Data',
                maxLines: 14,
                hintText: 'name,email,department,role,level',
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
      final rows = _parseCsvTextRows(_csvPasteController.text);
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

  List<Map<String, dynamic>> _parseImportRows(
    Uint8List bytes,
    String extension,
  ) {
    if (extension == 'xlsx') {
      return _parseExcelRows(bytes);
    }
    if (extension == 'csv') {
      return _parseCsvRows(bytes);
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

  List<Map<String, dynamic>> _parseExcelRows(Uint8List bytes) {
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
      final apiRow = _toApiImportRow(raw);
      if ((apiRow['name'] ?? '').toString().isNotEmpty &&
          (apiRow['email'] ?? '').toString().isNotEmpty) {
        out.add(apiRow);
      }
    }
    return out;
  }

  List<Map<String, dynamic>> _parseCsvRows(Uint8List bytes) {
    final csv = utf8.decode(bytes, allowMalformed: true);
    return _parseCsvTextRows(csv);
  }

  List<Map<String, dynamic>> _parseCsvTextRows(String csvText) {
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
      final apiRow = _toApiImportRow(raw);
      if ((apiRow['name'] ?? '').toString().isNotEmpty &&
          (apiRow['email'] ?? '').toString().isNotEmpty) {
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

  Map<String, dynamic> _toApiImportRow(Map<String, dynamic> row) {
    final teamController = context.read<TeamController>();
    final roleOptions = teamController.roleOptions;
    final departmentOptions = teamController.departmentOptions;

    final roleRaw =
        (_pickAny(row, ['role', 'user_role']) ?? AppConstants.roleArtist)
            .toString()
            .trim();
    final role = roleOptions.firstWhere(
      (r) => r.toLowerCase() == roleRaw.toLowerCase(),
      orElse: () =>
          roleOptions.isNotEmpty ? roleOptions.first : AppConstants.roleArtist,
    );

    final departmentRaw =
        (_pickAny(row, ['department', 'dept']) ??
                (departmentOptions.isNotEmpty
                    ? departmentOptions.first
                    : AppConstants.pipelineDepartments.first))
            .toString()
            .trim();
    final department = departmentOptions.firstWhere(
      (d) => d.toLowerCase() == departmentRaw.toLowerCase(),
      orElse: () => departmentOptions.isNotEmpty
          ? departmentOptions.first
          : AppConstants.pipelineDepartments.first,
    );

    final levelRaw = (_pickAny(row, ['level', 'artist_level']) ?? '')
        .toString()
        .trim();
    final level = AppConstants.artistLevels.contains(levelRaw)
        ? levelRaw
        : null;

    return {
      'name': (_pickAny(row, ['name', 'full_name']) ?? '').toString().trim(),
      'email': (_pickAny(row, ['email', 'mail']) ?? '').toString().trim(),
      'department': department,
      'role': role,
      if (role == AppConstants.roleArtist && level != null) 'level': level,
    };
  }

  Future<void> _saveImportedRows(TeamController controller) async {
    setState(() => _isSavingImport = true);
    try {
      final response = await controller.importMembers(_importDraftRows);
      if (!mounted) return;
      final created = response['created'] ?? 0;
      final errors =
          ((response['errors'] as List<dynamic>?) ?? const []).length;
      setState(() => _importDraftRows.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported members. Created: $created, Errors: $errors'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingImport = false);
    }
  }

  Future<void> _addMember(
    BuildContext context,
    TeamController controller,
  ) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _MemberDialog(
        controller: controller,
        roleOptions: controller.roleOptions,
        departmentOptions: controller.departmentOptions,
      ),
    );
    if (added == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Team member added')));
    }
  }
}

class _AssignTaskDialog extends StatefulWidget {
  final TeamMember member;
  const _AssignTaskDialog({required this.member});

  @override
  State<_AssignTaskDialog> createState() => _AssignTaskDialogState();
}

class _AssignTaskDialogState extends State<_AssignTaskDialog> {
  final TaskService _taskService = TaskService();
  final TextEditingController _bid = TextEditingController();
  List<ShotModel> _shots = [];
  String? _selectedShotId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadShots();
  }

  @override
  void dispose() {
    _bid.dispose();
    super.dispose();
  }

  Future<void> _loadShots() async {
    try {
      final resp = await _taskService.getDepartmentShots(
        department: widget.member.department,
      );
      final all = ((resp['shots'] as List<dynamic>?) ?? const [])
          .map((e) => ShotModel.fromJson(e as Map<String, dynamic>))
          .toList();
      // Only shots that are not yet assigned to anybody.
      _shots = all
          .where((s) => s.artistId == null || s.artistId!.isEmpty)
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_selectedShotId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _taskService.assignShot(_selectedShotId!, {
        'artistId': widget.member.userId,
        'artistBid': double.tryParse(_bid.text) ?? 0,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign task to ${widget.member.name}'),
      content: SizedBox(
        width: 380,
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
                  if (_shots.isEmpty)
                    const Text(
                      'No unassigned shots available in this department.',
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedShotId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Shot'),
                      items: _shots
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.shotId,
                              child: Text(
                                '${s.shotCode}  \u2022  ${s.showName ?? ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedShotId = v),
                    ),
                    // TextField(
                    //   controller: _bid,
                    //   keyboardType: TextInputType.number,
                    //   decoration: const InputDecoration(
                    //     labelText: 'Artist bid (mandays)',
                    //   ),
                    // ),
                    CustomTextField(
                      controller: _bid,
                      keyboardType: TextInputType.number,
                      labelText: 'Artist bid (mandays)',
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving || _selectedShotId == null ? null : _save,
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
}

// ─── Edit Member Dialog ───────────────────────────────────────────────────

class _EditMemberDialog extends StatefulWidget {
  final TeamMember member;
  final TeamController controller;
  final List<String> roleOptions;
  final List<String> departmentOptions;
  const _EditMemberDialog({
    required this.member,
    required this.controller,
    required this.roleOptions,
    required this.departmentOptions,
  });

  @override
  State<_EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends State<_EditMemberDialog> {
  late final TextEditingController _name;
  String _department = AppConstants.pipelineDepartments.first;
  List<String> _accessibleDepartments = AppConstants.pipelineDepartments;
  String _role = AppConstants.roleArtist;
  String? _level;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.member.name);
    final roleSource = widget.roleOptions.isNotEmpty
        ? widget.roleOptions
        : AppConstants.userRoles;
    _role = roleSource.contains(widget.member.role)
        ? widget.member.role
        : roleSource.first;
    _level = widget.member.level;

    final user = context.read<AuthController>().currentUser;
    final role = user?.role ?? '';
    final userDept = user?.department ?? '';
    final allDepartments = widget.departmentOptions.isNotEmpty
        ? widget.departmentOptions
        : AppConstants.pipelineDepartments;
    if (AppConstants.broadAccessRoles.contains(role)) {
      _accessibleDepartments = allDepartments;
    } else if (allDepartments.contains(userDept)) {
      _accessibleDepartments = [userDept];
    } else {
      _accessibleDepartments = allDepartments;
    }
    _department = _accessibleDepartments.contains(widget.member.department)
        ? widget.member.department
        : _accessibleDepartments.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _isArtist => _role == AppConstants.roleArtist;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await widget.controller.editMember(widget.member.userId, {
      'name': name,
      'department': _department,
      'role': _role,
      if (_isArtist && _level != null) 'level': _level,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: const Center(child: Text('Edit Team Member')),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isDark ? AppColors.brandGreen : AppColors.darkBg,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              CustomTextField(controller: _name, labelText: 'Full name'),
              CustomDropdown(
                labelText: 'Department',
                value: _department,
                items: _accessibleDepartments,
                onChanged: (v) =>
                    setState(() => _department = v ?? _department),
                itemToString: (v) => v,
              ),
              CustomDropdown(
                labelText: 'Role',
                value: _role,
                items: widget.roleOptions.isNotEmpty
                    ? widget.roleOptions
                    : AppConstants.userRoles,
                onChanged: (v) => setState(() => _role = v ?? _role),
                itemToString: (v) => v,
              ),
              if (_isArtist)
                CustomDropdown(
                  labelText: 'Level',
                  value: _level,
                  items: AppConstants.artistLevels,
                  onChanged: (v) => setState(() => _level = v),
                  itemToString: (v) => v,
                ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
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
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ─── Add Member Dialog ────────────────────────────────────────────────────

class _MemberDialog extends StatefulWidget {
  final TeamController controller;
  final List<String> roleOptions;
  final List<String> departmentOptions;
  const _MemberDialog({
    required this.controller,
    required this.roleOptions,
    required this.departmentOptions,
  });

  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  String _department = AppConstants.pipelineDepartments.first;
  List<String> _accessibleDepartments = AppConstants.pipelineDepartments;
  String _role = AppConstants.roleArtist;
  String? _level = AppConstants.artistLevels.first;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().currentUser;
    final role = user?.role ?? '';
    final userDept = user?.department ?? '';
    final allDepartments = widget.departmentOptions.isNotEmpty
        ? widget.departmentOptions
        : AppConstants.pipelineDepartments;
    if (AppConstants.broadAccessRoles.contains(role)) {
      _accessibleDepartments = allDepartments;
    } else if (allDepartments.contains(userDept)) {
      _accessibleDepartments = [userDept];
    } else {
      _accessibleDepartments = allDepartments;
    }
    _department = _accessibleDepartments.first;
    _role = widget.roleOptions.isNotEmpty
        ? widget.roleOptions.first
        : AppConstants.roleArtist;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _isArtist => _role == AppConstants.roleArtist;

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty || email.isEmpty) {
      setState(() => _error = 'Name and email are required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await widget.controller.addMember({
      'name': name,
      'email': email,
      'department': _department,
      'role': _role,
      if (_isArtist && _level != null) 'level': _level,
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

  @override
  Widget build(BuildContext context) {
    final isdark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: Center(child: const Text('Add Team Member')),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isdark ? AppColors.brandGreen : AppColors.darkBg,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              // TextField(
              //   controller: _name,
              //   decoration: const InputDecoration(
              //     labelText: 'Full name',
              //     border: OutlineInputBorder(),
              //   ),
              // ),
              // TextField(
              //   controller: _email,
              //   keyboardType: TextInputType.emailAddress,
              //   decoration: const InputDecoration(
              //     labelText: 'Email',
              //     border: OutlineInputBorder(),
              //   ),
              // ),
              CustomTextField(controller: _name, labelText: 'Full name'),
              CustomTextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                labelText: 'Email',
              ),
              // DropdownButtonFormField<String>(
              //   initialValue: _department,
              //   decoration: const InputDecoration(
              //     labelText: 'Department',
              //     border: OutlineInputBorder(),
              //   ),
              //   items: AppConstants.pipelineDepartments
              //       .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              //       .toList(),
              //   onChanged: (v) =>
              //       setState(() => _department = v ?? _department),
              // ),
              CustomDropdown(
                labelText: 'Department',
                value: _department,
                items: _accessibleDepartments,
                onChanged: (v) =>
                    setState(() => _department = v ?? _department),
                itemToString: (v) => v,
              ),
              // DropdownButtonFormField<String>(
              //   initialValue: _role,
              //   decoration: const InputDecoration(
              //     labelText: 'Role',
              //     border: OutlineInputBorder(),
              //   ),
              //   items: AppConstants.userRoles
              //       .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              //       .toList(),
              //   onChanged: (v) => setState(() => _role = v ?? _role),
              // ),
              CustomDropdown(
                labelText: 'Role',
                value: _role,
                items: widget.roleOptions.isNotEmpty
                    ? widget.roleOptions
                    : AppConstants.userRoles,
                onChanged: (v) => setState(() => _role = v ?? _role),
                itemToString: (v) => v,
              ),
              if (_isArtist)
                CustomDropdown(
                  labelText: 'Level',
                  items: AppConstants.artistLevels,
                  onChanged: (v) => setState(() => _level = v),
                  itemToString: (v) => v,
                ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
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
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
