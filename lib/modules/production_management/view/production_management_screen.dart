import 'dart:convert';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_controller.dart';
import '../../../core/services/production_service.dart';
import '../../../core/utils/excel_export_utils.dart';
import '../../../core/utils/size_config.dart';
import '../../../shared/widgets/custom_dropdown.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/dynamic_data_table.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/loading_widget.dart';

/// Status values accepted by the backend `shots.status` ENUM (also used for
/// the grid's Status column, the create dialog and import normalization).
const List<String> _gridStatusOptions = [
  'Hold',
  'Approved',
  'Awaiting Approval',
  'Approved Internal',
];

/// The "All" placeholder used by the single-select Department filter in the
/// filter dialog (mirrors the Projects module's Data Source section).
const String _allDepartmentOption = 'All';

/// Production Management screen.
///
/// Shows the full 20-column grid matching the "excel Jan - dec format"
/// template. Cells are editable via double-click; the Sync button persists
/// edited cells to the backend, and Export Excel downloads the template
/// format (title + meta + header + data rows).
class ProductionManagementScreen extends StatefulWidget {
  const ProductionManagementScreen({super.key});

  @override
  State<ProductionManagementScreen> createState() =>
      _ProductionManagementScreenState();
}

class _ProductionManagementScreenState
    extends State<ProductionManagementScreen> {
  final ProductionService _productionService = ProductionService();

  // ─── Grid data & pagination ────────────────────────────────────────────────
  List<Map<String, dynamic>> _rows = [];
  bool _isLoading = true;
  String? _loadError;
  bool _isSyncing = false;
  bool _isExporting = false;
  int _page = 0;
  static const int _rowsPerPage = 10;

  // Show/hide the spreadsheet-style cell borders on the grid (toggled via the
  // "Cell Borders" checkbox in the toolbar). On by default to match the Excel
  // template look.
  bool _showCellBorders = true;

  // ─── Inline editing state ─────────────────────────────────────────────────
  // Key: "shotId|fieldKey". Tracks which cell is currently showing a TextField.
  String? _editingCellKey;
  // shotId -> {fieldKey: newValue} — cells edited but not yet synced.
  final Map<String, Map<String, dynamic>> _pendingEdits = {};

  // ─── Filter state (mirrors the Projects screen flow) ─────────────────────
  // Freeform text filters (substring, case-insensitive).
  String _shotIdFilter = '';
  String _clientForRefFilter = '';
  String _clientFilter = '';
  String _showFilter = '';
  String _reviewNotesFilter = '';
  String _framesFilter = '';
  String _shotsReceivedDateFilter = '';
  String _wipEtaFilter = '';
  String _etaFilter = '';
  String _deliveredOnFilter = '';
  String _flEtaFilter = '';
  String _shotMandaysFilter = '';
  String _approvedClientMdFilter = '';
  String _flMandaysFilter = '';

  // Chip-based filters (multi-select from unique values).
  Set<String> _statusChips = {};
  Set<String> _tasksChips = {};
  Set<String> _coordinatorChips = {};
  Set<String> _workStationChips = {};
  Set<String> _monthChips = {};

  // Single-select department filter (mirrors the Projects filter dialog's
  // "Data Source" section). The grid stores the department in its `tasks`
  // column; "All" shows every row, a specific department narrows to it.
  String _departmentFilter = _allDepartmentOption;

  // ── Filtered-grid cache: recomputed ONLY when rows or any filter changes,
  //    reused across page flips (same pattern as the Projects grid). ──
  List<Map<String, dynamic>>? _cachedFilteredRows;
  String _filterSignature = '';

  // ── Page-change feedback: brief "Parsing…" overlay while the grid flips
  //    pages so heavy table rebuilds are never silent (Projects flow). ──
  bool _isGridChanging = false;

  // ─── Import state (mirrors the Projects screen flow) ──────────────────────
  final TextEditingController _csvPasteController = TextEditingController();
  final List<Map<String, dynamic>> _importDraftRows = [];
  final List<String> _importFeedback = [];
  bool _isImporting = false;
  bool _isSavingImport = false;
  // In-tree parsing loader state (NO dialog/navigator — see
  // [_withParsingLoader]).
  bool _showParsingOverlay = false;
  ValueNotifier<String>? _parsingStatus;
  int _previewPage = 0;
  List<Map<String, dynamic>>? _cachedImportPreviewRows;
  int _cachedImportPreviewLength = -1;

  @override
  void initState() {
    super.initState();
    _loadGrid();
  }

  Future<void> _loadGrid() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final response = await _productionService.getProductionGrid();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response['success'] == true) {
        _rows = List<Map<String, dynamic>>.from(response['rows'] ?? []);
        // Rows changed → filtered cache must be rebuilt.
        _cachedFilteredRows = null;
        _filterSignature = '';
      } else {
        _loadError = response['error'] ?? 'Failed to load production grid';
      }
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  int get _totalPages => _rowsPerPage > 0
      ? (_filteredRows.length / _rowsPerPage).ceil().clamp(1, 1 << 31)
      : 1;

  bool get _hasPendingEdits => _pendingEdits.isNotEmpty;

  int get _pendingEditCount =>
      _pendingEdits.values.fold<int>(0, (sum, updates) => sum + updates.length);

  String? _cellKey(String shotId, String fieldKey) => '$shotId|$fieldKey';

  dynamic _displayValue(Map<String, dynamic> row, String fieldKey) {
    final shotId = row['shotId'];
    final pending = _pendingEdits[shotId]?[fieldKey];
    if (pending != null) return pending;
    final value = row[fieldKey];
    if (value == null || value.toString().trim().isEmpty) return null;
    return value;
  }

  void _startEditing(String shotId, String fieldKey) {
    setState(() => _editingCellKey = _cellKey(shotId, fieldKey));
  }

  void _commitEdit(String shotId, String fieldKey, String newValue) {
    setState(() {
      _editingCellKey = null;
      // Only treat as a pending edit if the value actually changed.
      final index = _rows.indexWhere((r) => r['shotId'] == shotId);
      final current = index == -1
          ? null
          : _displayValue(_rows[index], fieldKey);
      final normalized = newValue.trim();
      final changed = (current ?? '').toString() != normalized;
      if (changed) {
        _pendingEdits.putIfAbsent(shotId, () => {})[fieldKey] = normalized;
        // Reflect the new value in the local row so the grid shows it.
        if (index != -1) {
          _rows[index][fieldKey] = normalized;
        }
        // Row values changed → filtered cache must be rebuilt.
        _cachedFilteredRows = null;
      }
    });
  }

  void _cancelEditing() {
    if (_editingCellKey != null) {
      setState(() => _editingCellKey = null);
    }
  }

  // ─── Filtering (Projects screen flow) ─────────────────────────────────────
  /// Signature of everything that affects the grid's filtered rows.
  /// Page changes are deliberately NOT included — the filtered list is reused
  /// across page flips, only the visible slice changes.
  String _buildFilterSignature() {
    String join(Set<String> s) =>
        s.isEmpty ? '' : (s.toList()..sort()).join(',');
    return [
      _rows.length,
      _departmentFilter,
      _shotIdFilter,
      _clientForRefFilter,
      _clientFilter,
      _showFilter,
      _reviewNotesFilter,
      _framesFilter,
      _shotsReceivedDateFilter,
      _wipEtaFilter,
      _etaFilter,
      _deliveredOnFilter,
      _flEtaFilter,
      _shotMandaysFilter,
      _approvedClientMdFilter,
      _flMandaysFilter,
      join(_statusChips),
      join(_tasksChips),
      join(_coordinatorChips),
      join(_workStationChips),
      join(_monthChips),
    ].join('|');
  }

  /// Filtered rows — computed once per signature change and cached.
  List<Map<String, dynamic>> get _filteredRows {
    final signature = _buildFilterSignature();
    if (_filterSignature != signature || _cachedFilteredRows == null) {
      _filterSignature = signature;
      _cachedFilteredRows = _rows
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

            return (_departmentFilter == _allDepartmentOption ||
                    (row['tasks'] ?? '').toString().toLowerCase() ==
                        _departmentFilter.toLowerCase()) &&
                contains('shotCode', _shotIdFilter) &&
                contains('clientForRef', _clientForRefFilter) &&
                contains('client', _clientFilter) &&
                contains('show', _showFilter) &&
                contains('reviewNotes', _reviewNotesFilter) &&
                contains('frames', _framesFilter) &&
                contains('shotsReceivedDate', _shotsReceivedDateFilter) &&
                contains('wipEta', _wipEtaFilter) &&
                contains('eta', _etaFilter) &&
                contains('deliveredOn', _deliveredOnFilter) &&
                contains('flEta', _flEtaFilter) &&
                contains('shotMandays', _shotMandaysFilter) &&
                contains('approvedClientMd', _approvedClientMdFilter) &&
                contains('flMandays', _flMandaysFilter) &&
                chipMatch('status', _statusChips) &&
                chipMatch('tasks', _tasksChips) &&
                chipMatch('coordinator', _coordinatorChips) &&
                chipMatch('workStation', _workStationChips) &&
                chipMatch('month', _monthChips);
          })
          .toList(growable: false);
    }
    return _cachedFilteredRows!;
  }

  int get _activeFilterCount {
    var count = 0;
    void inc(String s) {
      if (s.trim().isNotEmpty) count++;
    }

    inc(_shotIdFilter);
    inc(_clientForRefFilter);
    inc(_clientFilter);
    inc(_showFilter);
    inc(_reviewNotesFilter);
    inc(_framesFilter);
    inc(_shotsReceivedDateFilter);
    inc(_wipEtaFilter);
    inc(_etaFilter);
    inc(_deliveredOnFilter);
    inc(_flEtaFilter);
    inc(_shotMandaysFilter);
    inc(_approvedClientMdFilter);
    inc(_flMandaysFilter);
    if (_departmentFilter != _allDepartmentOption) count++;
    count +=
        _statusChips.length +
        _tasksChips.length +
        _coordinatorChips.length +
        _workStationChips.length +
        _monthChips.length;
    return count;
  }

  /// Column-header / mobile filter sheet entry point (single-select per
  /// column, same wiring as the Projects grid).
  void _applyColumnFilter(String fieldKey, dynamic value) {
    setState(() {
      _page = 0;
      final v = value is String ? value : value.toString();
      switch (fieldKey) {
        case 'shotCode':
          _shotIdFilter = v;
          break;
        case 'clientForRef':
          _clientForRefFilter = v;
          break;
        case 'client':
          _clientFilter = v;
          break;
        case 'show':
          _showFilter = v;
          break;
        case 'reviewNotes':
          _reviewNotesFilter = v;
          break;
        case 'frames':
          _framesFilter = v;
          break;
        case 'shotsReceivedDate':
          _shotsReceivedDateFilter = v;
          break;
        case 'wipEta':
          _wipEtaFilter = v;
          break;
        case 'eta':
          _etaFilter = v;
          break;
        case 'deliveredOn':
          _deliveredOnFilter = v;
          break;
        case 'flEta':
          _flEtaFilter = v;
          break;
        case 'shotMandays':
          _shotMandaysFilter = v;
          break;
        case 'approvedClientMd':
          _approvedClientMdFilter = v;
          break;
        case 'flMandays':
          _flMandaysFilter = v;
          break;
        case 'status':
          _statusChips = v.isEmpty ? {} : {v};
          break;
        case 'tasks':
          _tasksChips = v.isEmpty ? {} : {v};
          break;
        case 'coordinator':
          _coordinatorChips = v.isEmpty ? {} : {v};
          break;
        case 'workStation':
          _workStationChips = v.isEmpty ? {} : {v};
          break;
        case 'month':
          _monthChips = v.isEmpty ? {} : {v};
          break;
        default:
          break;
      }
    });
  }

  /// Opens the full filter dialog (chip sub-pages + freeform search).
  Future<void> _showFilterDialog(BuildContext context) async {
    final result = await showDialog<_ProductionFilterResult>(
      context: context,
      builder: (_) => _ProductionFilterDialog(
        rows: _rows,
        initialDepartment: _departmentFilter,
        initialShotId: _shotIdFilter,
        initialClientForRef: _clientForRefFilter,
        initialClient: _clientFilter,
        initialShow: _showFilter,
        initialReviewNotes: _reviewNotesFilter,
        initialFrames: _framesFilter,
        initialShotsReceivedDate: _shotsReceivedDateFilter,
        initialWipEta: _wipEtaFilter,
        initialEta: _etaFilter,
        initialDeliveredOn: _deliveredOnFilter,
        initialFlEta: _flEtaFilter,
        initialShotMandays: _shotMandaysFilter,
        initialApprovedClientMd: _approvedClientMdFilter,
        initialFlMandays: _flMandaysFilter,
        initialStatusChips: _statusChips,
        initialTasksChips: _tasksChips,
        initialCoordinatorChips: _coordinatorChips,
        initialWorkStationChips: _workStationChips,
        initialMonthChips: _monthChips,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _page = 0;
      _shotIdFilter = result.shotId;
      _clientForRefFilter = result.clientForRef;
      _clientFilter = result.client;
      _showFilter = result.show;
      _reviewNotesFilter = result.reviewNotes;
      _framesFilter = result.frames;
      _shotsReceivedDateFilter = result.shotsReceivedDate;
      _wipEtaFilter = result.wipEta;
      _etaFilter = result.eta;
      _deliveredOnFilter = result.deliveredOn;
      _flEtaFilter = result.flEta;
      _shotMandaysFilter = result.shotMandays;
      _approvedClientMdFilter = result.approvedClientMd;
      _flMandaysFilter = result.flMandays;
      _departmentFilter = result.department;
      _statusChips = result.statusChips;
      _tasksChips = result.tasksChips;
      _coordinatorChips = result.coordinatorChips;
      _workStationChips = result.workStationChips;
      _monthChips = result.monthChips;
    });
  }

  // ─── Sync edited cells to the server ──────────────────────────────────────
  Future<void> _syncEdits() async {
    if (!_hasPendingEdits || _isSyncing) return;

    setState(() => _isSyncing = true);
    try {
      final rows = _pendingEdits.entries
          .map((entry) => {'shotId': entry.key, 'updates': entry.value})
          .toList();

      final response = await _productionService.syncProductionGrid(rows);
      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _pendingEdits.clear();
          _editingCellKey = null;
        });
        // Refresh from server so values match exactly (dates, decimals, etc).
        await _loadGrid();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Synced ${response['updated'] ?? rows.length} row(s) successfully.',
            ),
          ),
        );
      } else {
        final errors = response['errors'] as List? ?? [];
        final msg = errors.isNotEmpty
            ? 'Sync failed: ${errors.length} row(s) had errors.'
            : (response['error'] ?? 'Sync failed');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  // ─── Excel export (mirrors the template format) ──────────────────────────
  Future<void> _exportAsExcel() async {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rows available to export.')),
      );
      return;
    }

    const totalCols = 20;
    const lastCol = totalCols - 1;

    setState(() => _isExporting = true);
    try {
      final excel = Excel.createExcel();
      final sheetName = excel.getDefaultSheet() ?? 'Production';
      final sheet = excel[sheetName];
      final titleStyle = ExcelExportUtils.titleCellStyle();
      final labelStyle = ExcelExportUtils.metaLabelStyle();
      final valueStyle = ExcelExportUtils.metaValueStyle();
      final headerStyle = ExcelExportUtils.tableHeaderStyle();
      final dataStyle = ExcelExportUtils.dataCellStyle();

      ExcelExportUtils.setColumnWidths(sheet, [
        8,
        16,
        10,
        18,
        16,
        14,
        18,
        14,
        14,
        22,
        10,
        14,
        24,
        14,
        16,
        14,
        14,
        14,
        14,
        14,
      ]);

      // ---- Title row ----
      final titleRow = sheet.maxRows;
      final titleCells = List<CellValue>.filled(totalCols, TextCellValue(''));
      titleCells[0] = TextCellValue('Production Management Grid');
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
      metaLabels[0] = TextCellValue('TOTAL ROWS');
      metaLabels[1] = TextCellValue('LAST SYNCED');
      metaLabels[2] = TextCellValue('PENDING EDITS');
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
      metaValues[0] = IntCellValue(_rows.length);
      metaValues[1] = TextCellValue(
        ExcelExportUtils.formatDate(DateTime.now()),
      );
      metaValues[2] = IntCellValue(_pendingEditCount);
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

      // ---- Table header row (exact template headers) ----
      final headerRow = sheet.maxRows;
      sheet.appendRow([
        TextCellValue('S No'),
        TextCellValue('Co ordinator'),
        TextCellValue('Month'),
        TextCellValue('Shots Received Date'),
        TextCellValue('Client for Ref'),
        TextCellValue('Client'),
        TextCellValue('Show'),
        TextCellValue('WIP ETA'),
        TextCellValue('ETA'),
        TextCellValue('Shot ID'),
        TextCellValue('Frames'),
        TextCellValue('Tasks'),
        TextCellValue('Review Notes'),
        TextCellValue('Status'),
        TextCellValue('Delivered on'),
        TextCellValue('Work station'),
        TextCellValue('Shot man-days'),
        TextCellValue('Approved Client MD'),
        TextCellValue('FL ETA'),
        TextCellValue('FL Man-days'),
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
      for (var i = 0; i < _rows.length; i++) {
        final row = _rows[i];
        final dataRowIndex = sheet.maxRows;
        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(_cellText(row['coordinator'])),
          TextCellValue(_cellText(row['month'])),
          TextCellValue(_cellText(row['shotsReceivedDate'])),
          TextCellValue(_cellText(row['clientForRef'])),
          TextCellValue(_cellText(row['client'])),
          TextCellValue(_cellText(row['show'])),
          TextCellValue(_cellText(row['wipEta'])),
          TextCellValue(_cellText(row['eta'])),
          TextCellValue(_cellText(row['shotCode'])),
          _numberCell(row['frames']),
          TextCellValue(_cellText(row['tasks'])),
          TextCellValue(_cellText(row['reviewNotes'])),
          TextCellValue(_cellText(row['status'])),
          TextCellValue(_cellText(row['deliveredOn'])),
          TextCellValue(_cellText(row['workStation'])),
          _decimalCell(row['shotMandays']),
          _decimalCell(row['approvedClientMd']),
          TextCellValue(_cellText(row['flEta'])),
          _decimalCell(row['flMandays']),
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
        prefix: 'production_management',
        department: 'grid',
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

  String _cellText(dynamic value) {
    if (value == null) return '-';
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  CellValue _numberCell(dynamic value) {
    final n = value is num ? value : num.tryParse(value?.toString() ?? '');
    return n != null ? IntCellValue(n.toInt()) : TextCellValue('-');
  }

  CellValue _decimalCell(dynamic value) {
    final n = value is num ? value : num.tryParse(value?.toString() ?? '');
    return n != null ? DoubleCellValue(n.toDouble()) : TextCellValue('-');
  }

  // ─── Import: pick & parse an Excel/CSV file (auto-saves) ─────────────────
  Future<void> _pickAndParseExcel() async {
    if (_isImporting || _isSavingImport) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'xlsm', 'xlsb', 'ods', 'csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) return;

      setState(() => _isImporting = true);
      final status = ValueNotifier<String>('Parsing file…');
      final parsed = await _withParsingLoader(
        context: context,
        message: 'Parsing & importing…',
        status: status,
        task: () async {
          final rows = await _parseGridFileRowsAsync(
            bytes,
            (file.extension ?? 'xlsx').toLowerCase(),
            _gridStatusOptions,
            onProgress: (n) => status.value = 'Parsing… $n rows',
          );
          if (rows.isNotEmpty) {
            status.value = 'Uploading ${rows.length} rows…';
          }
          return _saveParsedRowsAsync(
            rows,
            ApiConstants.baseUrl,
            ApiConstants.productionGridBulkUpsert,
            ApiController.instance.getToken(),
            onChunk: (done, total) =>
                status.value = 'Uploading… chunk $done of $total',
          );
        },
      );
      status.dispose();
      if (!mounted) return;

      final total = parsed['total'] as int? ?? 0;
      final created = parsed['created'] as int? ?? 0;
      final updated = parsed['updated'] as int? ?? 0;
      final errors = (parsed['errors'] as List?) ?? const [];
      final notes = (parsed['notes'] as List?) ?? const [];
      final preview = (parsed['preview'] as List?) ?? const [];

      setState(() {
        _isImporting = false;
        _importDraftRows
          ..clear()
          ..addAll(preview.cast<Map<String, dynamic>>());
        _previewPage = 0;
        _resetImportPreviewCache();
        _importFeedback
          ..clear()
          ..addAll(notes.map((n) => n.toString()).where((n) => n.isNotEmpty));
        for (final e in errors) {
          final err = e is Map
              ? e['error']?.toString() ?? e.toString()
              : e.toString();
          if (err.isNotEmpty) _importFeedback.add(err);
        }
      });

      final message = errors.isEmpty
          ? 'Saved $total rows to the server (created: $created, updated: $updated)'
          : 'Saved ${total - errors.length} of $total rows '
                '(created: $created, updated: $updated, errors: ${errors.length})';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      // Refresh the grid so imported rows appear.
      await _loadGrid();
      if (!mounted) return;
      _showImportFeedback();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  // ─── Import: paste CSV text for review ───────────────────────────────────
  Future<void> _openPasteCsvDialog() async {
    if (_isImporting || _isSavingImport) return;
    _csvPasteController.clear();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paste CSV'),
        content: SizedBox(
          width: SizeConfig.screenWidth(dialogContext) * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste rows with headers, e.g.:\n'
                'Co ordinator,Month,Shots Received Date,Client,Show,'
                'Shot ID,Frames,Tasks,Status',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _csvPasteController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Shot ID,Client,Show,Tasks,Status,...',
                  border: OutlineInputBorder(),
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
    if (ok != true || !mounted) return;

    setState(() => _isImporting = true);
    try {
      final status = ValueNotifier<String>('Parsing data…');
      final rows = await _withParsingLoader(
        context: context,
        message: 'Parsing data…',
        status: status,
        task: () => _parseGridCsvTextRowsAsync(
          _csvPasteController.text,
          _gridStatusOptions,
          onProgress: (n) => status.value = 'Parsing… $n rows',
        ),
      );
      status.dispose();
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _importDraftRows
          ..clear()
          ..addAll(rows);
        _previewPage = 0;
        _resetImportPreviewCache();
        _importFeedback.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${rows.length} rows for review.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV parse failed: $e')));
    }
  }

  // ─── Import: save reviewed draft rows in chunks ──────────────────────────
  Future<void> _saveImportedRows() async {
    if (_isSavingImport || _importDraftRows.isEmpty) return;
    setState(() => _isSavingImport = true);
    var created = 0;
    var updated = 0;
    final errors = <String>[];
    final notes = <String>[];
    const chunkSize = 100;

    try {
      for (var i = 0; i < _importDraftRows.length; i += chunkSize) {
        final chunk = _importDraftRows.sublist(
          i,
          (i + chunkSize).clamp(0, _importDraftRows.length),
        );
        final response = await _productionService.bulkUpsertProductionGrid(
          chunk,
        );
        if (response['success'] == true) {
          created += response['created'] as int? ?? 0;
          updated += response['updated'] as int? ?? 0;
          final chunkErrors = (response['errors'] as List?) ?? const [];
          for (final e in chunkErrors) {
            final err = e is Map
                ? e['error']?.toString() ?? e.toString()
                : e.toString();
            if (err.isNotEmpty) errors.add(err);
          }
          // Informational notes (e.g. auto-created clients/shows).
          final chunkNotes = (response['notes'] as List?) ?? const [];
          for (final n in chunkNotes) {
            final note = n.toString();
            if (note.isNotEmpty) notes.add(note);
          }
        } else {
          errors.add(
            response['error']?.toString() ??
                'Chunk ${i ~/ chunkSize + 1} failed',
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _isSavingImport = false;
        _importDraftRows.clear();
        _previewPage = 0;
        _resetImportPreviewCache();
        _importFeedback
          ..clear()
          ..addAll(notes)
          ..addAll(errors);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errors.isEmpty
                ? 'Saved ${created + updated} rows '
                      '(created: $created, updated: $updated)'
                : 'Saved ${created + updated} rows with ${errors.length} error(s).',
          ),
        ),
      );
      await _loadGrid();
      if (!mounted) return;
      _showImportFeedback();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingImport = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  // ─── Import: feedback dialog (errors / notes from the last save) ─────────
  void _showImportFeedback() {
    if (_importFeedback.isEmpty || !mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import feedback'),
        content: SizedBox(
          width: SizeConfig.screenWidth(dialogContext) * 0.9,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: SizeConfig.screenHeight(dialogContext) * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _importFeedback.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('• ${_importFeedback[i]}'),
              ),
            ),
          ),
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

  // ─── Import preview cache (Projects flow) ────────────────────────────────
  void _resetImportPreviewCache() {
    _cachedImportPreviewRows = null;
    _cachedImportPreviewLength = -1;
  }

  List<Map<String, dynamic>> _buildImportPreviewRows() {
    if (_cachedImportPreviewRows != null &&
        _cachedImportPreviewLength == _importDraftRows.length) {
      return _cachedImportPreviewRows!;
    }
    final rows = _importDraftRows.map(_gridPreviewRowT).toList(growable: false);
    _cachedImportPreviewRows = rows;
    _cachedImportPreviewLength = _importDraftRows.length;
    return rows;
  }

  /// Read-only preview of the draft import rows (all 20 template columns).
  Widget _importPreviewTable(BuildContext context) {
    final previewRows = _buildImportPreviewRows();

    return GlassContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: SizeConfig.scaleHeight(context, 6),
              horizontal: SizeConfig.scaleWidth(context, 12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Import preview — ${previewRows.length} row(s)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                TextButton.icon(
                  onPressed: _isSavingImport ? null : _saveImportedRows,
                  icon: _isSavingImport
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(
                    _isSavingImport ? 'Saving…' : 'Save Imported Data',
                  ),
                ),
              ],
            ),
          ),
          _paginationBar(context, _previewPage, previewRows.length, (p) {
            setState(() => _previewPage = p);
          }),
          DynamicDataTable(
            currentPage: _previewPage,
            onPageChanged: (p) => setState(() => _previewPage = p),
            minColumnWidth: SizeConfig.scaleWidth(context, 40),
            columnSpacing: SizeConfig.scaleWidth(context, 12),
            dataRowMinHeight: MediaQuery.of(context).size.height * 48 / 768,
            dataRowMaxHeight: MediaQuery.of(context).size.height * 62 / 768,
            fields: _buildImportPreviewFields(context),
            rows: previewRows,
            rowsPerPage: _rowsPerPage,
            showCellBorders: true,
            // Sit flush against the container's green border (no gap).
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  /// Read-only fields for the import preview table.
  List<DynamicTableField> _buildImportPreviewFields(BuildContext context) {
    return [
      DynamicTableField(
        key: 'sNo',
        label: 'S No',
        numeric: true,
        filterRequired: false,
      ),
      _previewField(context, 'coordinator', 'Co ordinator', 190),
      _previewField(context, 'month', 'Month', 120),
      _previewField(context, 'shotsReceivedDate', 'Shots Received Date', 350),
      _previewField(context, 'clientForRef', 'Client for Ref', 190),
      _previewField(context, 'client', 'Client', 200),
      _previewField(context, 'show', 'Show', 230),
      _previewField(context, 'wipEta', 'WIP ETA', 150),
      _previewField(context, 'eta', 'ETA', 180),
      _previewField(context, 'shotCode', 'Shot ID', 200),
      _previewField(context, 'frames', 'Frames', 90, numeric: true),
      _previewField(context, 'tasks', 'Tasks', 100),
      _previewField(context, 'reviewNotes', 'Review Notes', 220),
      _previewField(context, 'status', 'Status', 130),
      _previewField(context, 'deliveredOn', 'Delivered on', 120),
      _previewField(context, 'workStation', 'Work station', 120),
      _previewField(
        context,
        'shotMandays',
        'Shot man-days',
        110,
        numeric: true,
      ),
      _previewField(
        context,
        'approvedClientMd',
        'Approved Client MD',
        130,
        numeric: true,
      ),
      _previewField(context, 'flEta', 'FL ETA', 110),
      _previewField(context, 'flMandays', 'FL Man-days', 110, numeric: true),
    ];
  }

  DynamicTableField _previewField(
    BuildContext context,
    String key,
    String label,
    double width, {
    bool numeric = false,
  }) {
    return DynamicTableField(
      key: key,
      label: label,
      width: SizeConfig.scaleWidth(context, width),
      numeric: numeric,
      builder: (context, value, row, rowIndex) {
        final text = value == null || value.toString().trim().isEmpty
            ? '-'
            : value.toString();
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: SizeConfig.scaleWidth(context, 4),
            vertical: SizeConfig.scaleHeight(context, 4),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: TextStyle(fontSize: SizeConfig.fontSize(context, 12)),
          ),
        );
      },
    );
  }

  // ─── Manual creation ─────────────────────────────────────────────────────
  void _openCreateMenu() {
    if (_isSyncing || _isSavingImport || _isImporting) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('New Grid Row'),
              subtitle: const Text('Manually add a shot to the grid'),
              onTap: () {
                Navigator.pop(dialogContext);
                _openNewRowDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _openNewRowDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _NewGridRowDialog(service: _productionService),
    );
    if (created == true && mounted) {
      await _loadGrid();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Grid row created.')));
    }
  }

  // ─── Toolbar ──────────────────────────────────────────────────────────────
  Widget _toolbar(BuildContext context) {
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
            fixedSize: SizeConfig.buttonFixedSize(context, 170, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                SizeConfig.scaleWidth(context, 2),
              ),
            ),
          ),
          onPressed: (_isSyncing || !_hasPendingEdits) ? null : _syncEdits,
          icon: _isSyncing
              ? SizeConfig.loadingIndicator(size: 14, stroke: 2)
              : const Icon(Icons.sync_outlined),
          label: Text(
            _pendingEditCount > 0 ? 'Sync ($_pendingEditCount)' : 'Sync',
          ),
        ),
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
          onPressed: _isExporting ? null : _exportAsExcel,
          icon: _isExporting
              ? SizeConfig.loadingIndicator(size: 14, stroke: 2)
              : const Icon(Icons.download_outlined),
          label: const Text('Export Excel'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            fixedSize: SizeConfig.buttonFixedSize(context, 150, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                SizeConfig.scaleWidth(context, 2),
              ),
            ),
          ),
          onPressed: _isImporting || _isSavingImport
              ? null
              : _openPasteCsvDialog,
          icon: _isImporting
              ? SizeConfig.loadingIndicator(size: 14, stroke: 2)
              : const Icon(Icons.content_paste_outlined),
          label: const Text('Paste CSV'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            fixedSize: SizeConfig.buttonFixedSize(context, 150, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                SizeConfig.scaleWidth(context, 2),
              ),
            ),
          ),
          onPressed: _isImporting || _isSavingImport
              ? null
              : _pickAndParseExcel,
          icon: _isImporting
              ? SizeConfig.loadingIndicator(size: 14, stroke: 2)
              : const Icon(Icons.upload_file_outlined),
          label: const Text('Import File'),
        ),
        if (_importDraftRows.isNotEmpty)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: Colors.white,
              fixedSize: SizeConfig.buttonFixedSize(context, 170, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  SizeConfig.scaleWidth(context, 2),
                ),
              ),
            ),
            onPressed: _isSavingImport ? null : _saveImportedRows,
            icon: _isSavingImport
                ? SizeConfig.loadingIndicator(size: 14, stroke: 2)
                : const Icon(Icons.save_outlined),
            label: Text(
              _isSavingImport
                  ? 'Saving…'
                  : 'Save Imported Data (${_importDraftRows.length})',
            ),
          ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            fixedSize: SizeConfig.buttonFixedSize(context, 150, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                SizeConfig.scaleWidth(context, 2),
              ),
            ),
          ),
          onPressed: _isLoading ? null : _loadGrid,
          icon: const Icon(Icons.refresh_outlined),
          label: const Text('Refresh'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            fixedSize: SizeConfig.buttonFixedSize(context, 170, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                SizeConfig.scaleWidth(context, 2),
              ),
            ),
          ),
          onPressed: _isLoading || _isSyncing || _isExporting
              ? null
              : () => _showFilterDialog(context),
          icon: Icon(
            Icons.filter_alt_outlined,
            color: _activeFilterCount > 0 ? AppColors.brandGreen : null,
          ),
          label: Text(
            _activeFilterCount > 0
                ? 'Filters ($_activeFilterCount)'
                : 'Filters',
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            fixedSize: Size(
              SizeConfig.scaleWidth(context, 150),
              MediaQuery.of(context).size.height * 40 / 768,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                SizeConfig.scaleWidth(context, 0),
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

  // ─── Grid fields (all 20 template columns) ───────────────────────────────
  List<DynamicTableField> _buildFields(BuildContext context) {
    return [
      DynamicTableField(
        key: 'sNo',
        label: 'S No',
        // width: SizeConfig.scaleWidth(context, 20),
        numeric: true,
        filterRequired: false,
      ),
      _editableField(context, 'coordinator', 'Co ordinator', 190),
      _editableField(context, 'month', 'Month', 120),
      _editableField(
        context,
        'shotsReceivedDate',
        'Shots Received Date',
        350,
        isDate: true,
      ),
      _editableField(context, 'clientForRef', 'Client for Ref', 190),
      DynamicTableField(
        key: 'client',
        label: 'Client',
        width: SizeConfig.scaleWidth(context, 200),
      ),
      DynamicTableField(
        key: 'show',
        label: 'Show',
        width: SizeConfig.scaleWidth(context, 230),
      ),
      _editableField(context, 'wipEta', 'WIP ETA', 150, isDate: true),
      _editableField(context, 'eta', 'ETA', 180, isDate: true),
      DynamicTableField(
        key: 'shotCode',
        label: 'Shot ID',
        width: SizeConfig.scaleWidth(context, 200),
      ),
      _editableField(context, 'frames', 'Frames', 90, numeric: true),
      _editableField(context, 'tasks', 'Tasks', 100),
      _editableField(context, 'reviewNotes', 'Review Notes', 220),
      _editableField(
        context,
        'status',
        'Status',
        150,
        options: _gridStatusOptions,
      ),
      _editableField(context, 'deliveredOn', 'Delivered on', 120, isDate: true),
      _editableField(context, 'workStation', 'Work station', 120),
      _editableField(
        context,
        'shotMandays',
        'Shot man-days',
        110,
        numeric: true,
      ),
      _editableField(
        context,
        'approvedClientMd',
        'Approved Client MD',
        130,
        numeric: true,
      ),
      _editableField(context, 'flEta', 'FL ETA', 110, isDate: true),
      _editableField(context, 'flMandays', 'FL Man-days', 110, numeric: true),
    ];
  }

  DynamicTableField _editableField(
    BuildContext context,
    String key,
    String label,
    double width, {
    bool numeric = false,
    bool isDate = false,
    List<String>? options,
  }) {
    return DynamicTableField(
      key: key,
      label: label,
      width: SizeConfig.scaleWidth(context, width),
      numeric: numeric,
      builder: (context, value, row, rowIndex) {
        final shotId = row['shotId']?.toString() ?? '';
        final display = _displayValue(row, key);
        return _GridEditableCell(
          fieldKey: key,
          shotId: shotId,
          displayValue: display,
          isEditing: _editingCellKey == _cellKey(shotId, key),
          isDirty: _pendingEdits[shotId]?[key] != null,
          numeric: numeric,
          isDate: isDate,
          options: options,
          onStartEdit: () => _startEditing(shotId, key),
          onCommit: (newValue) => _commitEdit(shotId, key, newValue),
          onCancel: _cancelEditing,
        );
      },
    );
  }

  // ─── Main grid ────────────────────────────────────────────────────────────
  Widget _grid(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: SizeConfig.screenWidth(context),
        height: SizeConfig.scaleHeight(context, 400),
        child: const LoadingWidget(message: 'Loading production grid...'),
      );
    }

    if (_loadError != null) {
      return EmptyStateWidget(
        icon: Icons.error_outline,
        title: 'Failed to load grid',
        description: _loadError!,
      );
    }

    if (_rows.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.grid_on_outlined,
        title: 'No production data',
        description: 'No shots available for the production grid.',
      );
    }

    final filteredRows = _filteredRows;
    if (filteredRows.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.filter_alt_off_outlined,
        title: 'No matching rows',
        description: 'No shots match the active filters.',
      );
    }

    return GlassContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _paginationBar(context, _page, filteredRows.length, _changeGridPage),
          _withGridParsingOverlay(
            isLoading: _isGridChanging,
            child: DynamicDataTable(
              currentPage: _page,
              onPageChanged: _changeGridPage,
              minColumnWidth: SizeConfig.scaleWidth(context, 40),
              columnSpacing: SizeConfig.scaleWidth(context, 12),
              dataRowMinHeight: MediaQuery.of(context).size.height * 28 / 768,
              dataRowMaxHeight: MediaQuery.of(context).size.height * 32 / 768,
              fields: _buildFields(context),
              rows: filteredRows,
              onFilterChanged: _applyColumnFilter,
              rowsPerPage: _rowsPerPage,
              showCellBorders: _showCellBorders,
              // Sit flush against the container's green border (no gap).
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paginationBar(
    BuildContext context,
    int currentPage,
    int totalRows,
    ValueChanged<int> onPageChanged,
  ) {
    final totalPages = _totalPages;
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

  /// Flips the grid page with a one-frame "Parsing…" overlay so the table
  /// rebuild is visible feedback instead of a silent freeze (Projects flow).
  void _changeGridPage(int page) {
    if (_isGridChanging || page == _page) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      // Called mid-build (DynamicDataTable internal page clamp) — defer.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _changeGridPage(page);
      });
      return;
    }
    setState(() => _isGridChanging = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _page = page);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _isGridChanging = false);
      });
    });
  }

  /// Overlays a spinner over the grid/screen while work is in progress.
  /// Used for grid page flips ("Parsing…") and while import data is being
  /// parsed ("Parsing data…").
  Widget _withGridParsingOverlay({
    required bool isLoading,
    required Widget child,
    String message = 'Parsing…',
  }) {
    if (!isLoading) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.18),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  SizedBox(height: SizeConfig.scaleHeight(context, 10)),
                  Text(message),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<T> _withParsingLoader<T>({
    required BuildContext context,
    required String message,
    required Future<T> Function() task,
    ValueNotifier<String>? status,
    Duration minVisible = const Duration(milliseconds: 1000),
  }) async {
    final statusNotifier = status ?? ValueNotifier<String>(message);
    if (mounted) {
      setState(() {
        _showParsingOverlay = true;
        _parsingStatus = statusNotifier;
      });
    }
    // Let the overlay paint and start animating before heavy work begins.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final stopwatch = Stopwatch()..start();
    try {
      return await task();
    } finally {
      // Guarantee the loader is visible for at least [minVisible], even when
      // the work completes almost instantly (small pastes, fast machines).
      final elapsed = stopwatch.elapsed;
      if (elapsed < minVisible) {
        await Future<void>.delayed(minVisible - elapsed);
      }
      if (status == null) statusNotifier.dispose();
      // Detach the overlay before returning. The caller disposes [status]
      // immediately after this future completes; ValueListenableBuilder
      // unsubscribing from an already-disposed ValueNotifier is a no-op, and
      // `mounted` guards the case where this screen was disposed mid-task
      // (then the whole tree is gone and there is nothing left to hide).
      if (mounted) {
        setState(() {
          _showParsingOverlay = false;
          _parsingStatus = null;
        });
      }
    }
  }

  /// The in-tree modal scrim + spinner used by [_withParsingLoader]. Drawn
  /// inside this screen's own [Stack], so it needs no navigator and can
  /// never pop a route (see [_withParsingLoader]).
  Widget _buildParsingOverlay(
    BuildContext context,
    ValueNotifier<String> status,
  ) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: GlassContainer(
            child: Padding(
              padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 28)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  SizedBox(height: SizeConfig.scaleHeight(context, 18)),
                  ValueListenableBuilder<String>(
                    valueListenable: status,
                    builder: (statusContext, text, _) => Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: SizeConfig.fontSize(statusContext, 14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The parsing loader is drawn as an in-tree overlay (a Stack child) so
    // it never touches the navigator — see [_withParsingLoader].
    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.brandGreen,
            foregroundColor: Colors.white,
            onPressed: (_isSyncing || _isSavingImport || _isImporting)
                ? null
                : _openCreateMenu,
            icon: const Icon(Icons.add),
            label: const Text('Create'),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: SizeConfig.scaleHeight(context, 40),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _toolbar(context),
                      if (_importDraftRows.isNotEmpty) ...[
                        SizedBox(height: SizeConfig.scaleHeight(context, 20)),
                        _importPreviewTable(context),
                      ],
                      SizedBox(height: SizeConfig.scaleHeight(context, 20)),
                      _grid(context),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_showParsingOverlay && _parsingStatus != null)
          _buildParsingOverlay(context, _parsingStatus!),
      ],
    );
  }
}

/// A single editable grid cell.
///
/// Displays the value normally; on double-click it swaps to an editor:
///  - [options] != null  → a compact dropdown (used by the Status column)
///  - [isDate]           → opens a date picker dialog directly
///  - otherwise          → a compact [TextField]
/// Commits on Enter/focus-loss (text), selection (dropdown) or pick (date),
/// and highlights while dirty (pending sync).
class _GridEditableCell extends StatefulWidget {
  final String fieldKey;
  final String shotId;
  final dynamic displayValue;
  final bool isEditing;
  final bool isDirty;
  final bool numeric;
  final bool isDate;
  final List<String>? options;
  final VoidCallback onStartEdit;
  final ValueChanged<String> onCommit;
  final VoidCallback onCancel;

  const _GridEditableCell({
    required this.fieldKey,
    required this.shotId,
    required this.displayValue,
    required this.isEditing,
    required this.isDirty,
    required this.numeric,
    this.isDate = false,
    this.options,
    required this.onStartEdit,
    required this.onCommit,
    required this.onCancel,
  });

  @override
  State<_GridEditableCell> createState() => _GridEditableCellState();
}

class _GridEditableCellState extends State<_GridEditableCell> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _initialText);
    _focusNode = FocusNode()..addListener(_onFocusChange);
    if (widget.isEditing && widget.options == null && !widget.isDate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  String get _initialText {
    final value = widget.displayValue;
    if (value == null) return '';
    return value.toString();
  }

  /// Parses the cell's value into a [DateTime], or null when empty/invalid.
  DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  /// Formats [date] as an ISO `yyyy-MM-dd` string (matches the backend's
  /// `to_iso` output so unchanged dates are no-ops on sync).
  String _formatIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Opens a calendar dialog; commits the picked ISO date, or an empty
  /// string when the user clears the value (backend stores NULL).
  Future<void> _pickDate() async {
    final initial = _parseDate(_initialText) ?? DateTime.now();
    String? result;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select date'),
        contentPadding: EdgeInsets.zero,
        // CalendarDatePicker uses a lazy Viewport for its month grid, which
        // cannot report intrinsic dimensions; a fixed box is required so
        // AlertDialog's internal IntrinsicWidth doesn't try to measure it.
        content: SizedBox(
          width: 320,
          height: 400,
          child: CalendarDatePicker(
            initialDate: initial,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            onDateChanged: (d) => result = _formatIsoDate(d),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              result = null;
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          if (_initialText.isNotEmpty)
            TextButton(
              onPressed: () {
                result = '';
                Navigator.pop(dialogContext);
              },
              child: const Text('Clear'),
            ),
          TextButton(
            onPressed: () {
              result ??= _formatIsoDate(initial);
              Navigator.pop(dialogContext);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    widget.onCommit(result!);
  }

  /// Compact dropdown editor for option-based columns (e.g. Status).
  Widget _buildOptionEditor(BuildContext context, ColorScheme scheme) {
    final current = widget.displayValue?.toString() ?? '';
    return CustomDropdown<String>(
      compact: true,
      labelText: widget.fieldKey,
      value: widget.options!.contains(current) ? current : null,
      items: widget.options!,
      itemToString: (v) => v,
      onChanged: (v) {
        if (v != null) widget.onCommit(v);
      },
    );
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && widget.isEditing) {
      widget.onCommit(_controller.text);
    }
  }

  @override
  void didUpdateWidget(covariant _GridEditableCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing &&
        !oldWidget.isEditing &&
        widget.options == null &&
        !widget.isDate) {
      _controller.text = _initialText;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (widget.isEditing) {
      // Status (and any future option column): inline dropdown instead of
      // a free-text field so only valid values can be entered.
      if (widget.options != null) {
        return _buildOptionEditor(context, scheme);
      }
      return TextField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: widget.numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: SizeConfig.fontSize(context, 12),
          color: scheme.onSurface,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: SizeConfig.scaleWidth(context, 6),
            vertical: SizeConfig.scaleHeight(context, 6),
          ),
          filled: true,
          fillColor: scheme.primaryContainer.withValues(alpha: 0.45),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              SizeConfig.scaleWidth(context, 0),
            ),
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              SizeConfig.scaleWidth(context, 0),
            ),
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              SizeConfig.scaleWidth(context, 0),
            ),
            borderSide: BorderSide(color: scheme.primary, width: 2),
          ),
        ),
        onSubmitted: (value) => widget.onCommit(value),
        onTapOutside: (_) => widget.onCommit(_controller.text),
      );
    }

    return Tooltip(
      message: widget.isDate
          ? 'Double-click to pick date'
          : 'Double-click to edit',
      waitDuration: const Duration(milliseconds: 600),
      // Keep the hint out of the semantics tree so it never merges into the
      // cell's label (cells must read as their value only).
      excludeFromSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.isDate ? _pickDate : widget.onStartEdit,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: SizeConfig.scaleWidth(context, 4),
            vertical: SizeConfig.scaleHeight(context, 4),
          ),
          decoration: widget.isDirty
              ? BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(
                    SizeConfig.scaleWidth(context, 4),
                  ),
                )
              : null,
          child: Text(
            widget.displayValue == null ? '-' : widget.displayValue.toString(),
            textAlign: TextAlign.center,
            // Columns are sized to their content in the scrollable table, so
            // the value always fits — never ellipsize with "...".
            softWrap: false,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontSize: SizeConfig.fontSize(context, 12),
              color: widget.isDirty ? Colors.amber.shade900 : scheme.onSurface,
              fontWeight: widget.isDirty ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Production grid filter dialog.
//
// Mirrors the Projects screen flow: a main list of filter tiles that open
// searchable chip sub-pages (Status / Tasks / Personnel / Months) plus a
// freeform Search sub-page for the remaining columns. Apply pops a
// [_ProductionFilterResult] back to the screen.
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable snapshot of every filter value, returned by the dialog.
class _ProductionFilterResult {
  final String shotId;
  final String clientForRef;
  final String client;
  final String show;
  final String reviewNotes;
  final String frames;
  final String shotsReceivedDate;
  final String wipEta;
  final String eta;
  final String deliveredOn;
  final String flEta;
  final String shotMandays;
  final String approvedClientMd;
  final String flMandays;
  final String department;
  final Set<String> statusChips;
  final Set<String> tasksChips;
  final Set<String> coordinatorChips;
  final Set<String> workStationChips;
  final Set<String> monthChips;

  const _ProductionFilterResult({
    required this.department,
    required this.shotId,
    required this.clientForRef,
    required this.client,
    required this.show,
    required this.reviewNotes,
    required this.frames,
    required this.shotsReceivedDate,
    required this.wipEta,
    required this.eta,
    required this.deliveredOn,
    required this.flEta,
    required this.shotMandays,
    required this.approvedClientMd,
    required this.flMandays,
    required this.statusChips,
    required this.tasksChips,
    required this.coordinatorChips,
    required this.workStationChips,
    required this.monthChips,
  });
}

/// A chip multi-select group shown inside a filter sub-page.
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

class _ProductionFilterDialog extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final String initialDepartment;
  final String initialShotId;
  final String initialClientForRef;
  final String initialClient;
  final String initialShow;
  final String initialReviewNotes;
  final String initialFrames;
  final String initialShotsReceivedDate;
  final String initialWipEta;
  final String initialEta;
  final String initialDeliveredOn;
  final String initialFlEta;
  final String initialShotMandays;
  final String initialApprovedClientMd;
  final String initialFlMandays;
  final Set<String> initialStatusChips;
  final Set<String> initialTasksChips;
  final Set<String> initialCoordinatorChips;
  final Set<String> initialWorkStationChips;
  final Set<String> initialMonthChips;

  const _ProductionFilterDialog({
    required this.rows,
    required this.initialDepartment,
    required this.initialShotId,
    required this.initialClientForRef,
    required this.initialClient,
    required this.initialShow,
    required this.initialReviewNotes,
    required this.initialFrames,
    required this.initialShotsReceivedDate,
    required this.initialWipEta,
    required this.initialEta,
    required this.initialDeliveredOn,
    required this.initialFlEta,
    required this.initialShotMandays,
    required this.initialApprovedClientMd,
    required this.initialFlMandays,
    required this.initialStatusChips,
    required this.initialTasksChips,
    required this.initialCoordinatorChips,
    required this.initialWorkStationChips,
    required this.initialMonthChips,
  });

  @override
  State<_ProductionFilterDialog> createState() =>
      _ProductionFilterDialogState();
}

class _ProductionFilterDialogState extends State<_ProductionFilterDialog> {
  late String _selectedDepartment;
  late final Map<String, TextEditingController> _controllers;

  Set<String> _statusChips = {};
  Set<String> _tasksChips = {};
  Set<String> _coordinatorChips = {};
  Set<String> _workStationChips = {};
  Set<String> _monthChips = {};

  // Unique value lists extracted from the grid rows (computed after first
  // frame so the dialog opens instantly, like the Projects dialog).
  List<String> _statuses = [];
  List<String> _tasks = [];
  List<String> _coordinators = [];
  List<String> _workStations = [];
  List<String> _months = [];
  bool _isLoadingValues = true;

  // Sub-page navigation: null = main list.
  String? _subPageKey;

  final TextEditingController _subSearchCtrl = TextEditingController();
  String _subQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedDepartment = widget.initialDepartment;
    _controllers = {
      'shotId': TextEditingController(text: widget.initialShotId),
      'clientForRef': TextEditingController(text: widget.initialClientForRef),
      'client': TextEditingController(text: widget.initialClient),
      'show': TextEditingController(text: widget.initialShow),
      'reviewNotes': TextEditingController(text: widget.initialReviewNotes),
      'frames': TextEditingController(text: widget.initialFrames),
      'shotsReceivedDate': TextEditingController(
        text: widget.initialShotsReceivedDate,
      ),
      'wipEta': TextEditingController(text: widget.initialWipEta),
      'eta': TextEditingController(text: widget.initialEta),
      'deliveredOn': TextEditingController(text: widget.initialDeliveredOn),
      'flEta': TextEditingController(text: widget.initialFlEta),
      'shotMandays': TextEditingController(text: widget.initialShotMandays),
      'approvedClientMd': TextEditingController(
        text: widget.initialApprovedClientMd,
      ),
      'flMandays': TextEditingController(text: widget.initialFlMandays),
    };
    _statusChips = {...widget.initialStatusChips};
    _tasksChips = {...widget.initialTasksChips};
    _coordinatorChips = {...widget.initialCoordinatorChips};
    _workStationChips = {...widget.initialWorkStationChips};
    _monthChips = {...widget.initialMonthChips};

    _subSearchCtrl.addListener(() {
      setState(() => _subQuery = _subSearchCtrl.text);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _statuses = _unique('status');
        _tasks = _unique('tasks');
        _coordinators = _unique('coordinator');
        _workStations = _unique('workStation');
        _months = _unique('month');
        _isLoadingValues = false;
      });
    });
  }

  @override
  void dispose() {
    _subSearchCtrl.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _unique(String key) {
    final seen = <String>{};
    for (final row in widget.rows) {
      final v = (row[key] ?? '').toString().trim();
      if (v.isNotEmpty) seen.add(v);
    }
    return seen.toList()..sort();
  }

  int get _textFilterCount {
    var count = 0;
    for (final c in _controllers.values) {
      if (c.text.trim().isNotEmpty) count++;
    }
    return count;
  }

  void _clearAll() {
    for (final c in _controllers.values) {
      c.clear();
    }
    setState(() {
      _selectedDepartment = _allDepartmentOption;
      _statusChips = {};
      _tasksChips = {};
      _coordinatorChips = {};
      _workStationChips = {};
      _monthChips = {};
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      _ProductionFilterResult(
        department: _selectedDepartment,
        shotId: _controllers['shotId']!.text,
        clientForRef: _controllers['clientForRef']!.text,
        client: _controllers['client']!.text,
        show: _controllers['show']!.text,
        reviewNotes: _controllers['reviewNotes']!.text,
        frames: _controllers['frames']!.text,
        shotsReceivedDate: _controllers['shotsReceivedDate']!.text,
        wipEta: _controllers['wipEta']!.text,
        eta: _controllers['eta']!.text,
        deliveredOn: _controllers['deliveredOn']!.text,
        flEta: _controllers['flEta']!.text,
        shotMandays: _controllers['shotMandays']!.text,
        approvedClientMd: _controllers['approvedClientMd']!.text,
        flMandays: _controllers['flMandays']!.text,
        statusChips: _statusChips,
        tasksChips: _tasksChips,
        coordinatorChips: _coordinatorChips,
        workStationChips: _workStationChips,
        monthChips: _monthChips,
      ),
    );
  }

  String get _subPageTitle {
    switch (_subPageKey) {
      case 'status':
        return 'Status';
      case 'tasks':
        return 'Tasks';
      case 'personnel':
        return 'Personnel';
      case 'months':
        return 'Months';
      case 'search':
        return 'Search';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          if (_subPageKey != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _subPageKey = null),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(child: Text(_subPageTitle)),
          if (_subPageKey == null)
            TextButton(onPressed: _clearAll, child: const Text('Clear All')),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: _isLoadingValues
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: _subPageKey == null
                    ? _buildMainList(context)
                    : _buildSubPageBody(context),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandGreen,
            foregroundColor: Colors.white,
          ),
          onPressed: _apply,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildMainList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Data Source (inline single-select chips, same as Projects) ──
        _labeledChipRow(
          'Department',
          [_allDepartmentOption, ...AppConstants.pipelineDepartments],
          _selectedDepartment,
          (v) => setState(() => _selectedDepartment = v),
        ),
        const Divider(height: 24),
        _filterListTile(
          'Status',
          subtitle: 'Filter by shot status',
          activeCount: _statusChips.length,
          onTap: () => setState(() => _subPageKey = 'status'),
        ),
        _filterListTile(
          'Tasks',
          subtitle: 'Filter by task / department',
          activeCount: _tasksChips.length,
          onTap: () => setState(() => _subPageKey = 'tasks'),
        ),
        _filterListTile(
          'Personnel',
          subtitle: 'Coordinator & work station',
          activeCount: _coordinatorChips.length + _workStationChips.length,
          onTap: () => setState(() => _subPageKey = 'personnel'),
        ),
        _filterListTile(
          'Months',
          subtitle: 'Filter by month',
          activeCount: _monthChips.length,
          onTap: () => setState(() => _subPageKey = 'months'),
        ),
        _filterListTile(
          'Search',
          subtitle: 'Shot ID, client, show, notes, dates & numbers',
          activeCount: _textFilterCount,
          hasText: _textFilterCount > 0,
          onTap: () => setState(() => _subPageKey = 'search'),
        ),
      ],
    );
  }

  Widget _buildSubPageBody(BuildContext context) {
    switch (_subPageKey) {
      case 'status':
        return _buildChipSubPageBody([
          _ChipFieldGroup(
            label: 'Status',
            allItems: _statuses,
            selected: _statusChips,
            onChanged: (v) => setState(() => _statusChips = v),
          ),
        ]);
      case 'tasks':
        return _buildChipSubPageBody([
          _ChipFieldGroup(
            label: 'Tasks',
            allItems: _tasks,
            selected: _tasksChips,
            onChanged: (v) => setState(() => _tasksChips = v),
          ),
        ]);
      case 'personnel':
        return _buildChipSubPageBody([
          _ChipFieldGroup(
            label: 'Coordinator',
            allItems: _coordinators,
            selected: _coordinatorChips,
            onChanged: (v) => setState(() => _coordinatorChips = v),
          ),
          _ChipFieldGroup(
            label: 'Work station',
            allItems: _workStations,
            selected: _workStationChips,
            onChanged: (v) => setState(() => _workStationChips = v),
          ),
        ]);
      case 'months':
        return _buildChipSubPageBody([
          _ChipFieldGroup(
            label: 'Month',
            allItems: _months,
            selected: _monthChips,
            onChanged: (v) => setState(() => _monthChips = v),
          ),
        ]);
      case 'search':
        return _buildSearchBody(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildChipSubPageBody(List<_ChipFieldGroup> groups) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _subSearchCtrl,
          decoration: InputDecoration(
            hintText: 'Search values…',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                SizeConfig.scaleWidth(context, 8),
              ),
            ),
          ),
        ),
        SizedBox(height: SizeConfig.scaleHeight(context, 12)),
        for (final group in groups) ...[
          if (groups.length > 1)
            _buildGroupHeader(group.label, group.selected.length),
          _buildChipGridInline(
            _filteredItems(group.allItems),
            group.selected,
            group.onChanged,
          ),
          if (group != groups.last)
            SizedBox(height: SizeConfig.scaleHeight(context, 16)),
        ],
      ],
    );
  }

  Widget _buildGroupHeader(String label, int selectedCount) {
    return Padding(
      padding: EdgeInsets.only(bottom: SizeConfig.scaleHeight(context, 6)),
      child: Text(
        selectedCount > 0 ? '$label ($selectedCount selected)' : label,
        style: TextStyle(
          fontSize: SizeConfig.fontSize(context, 13),
          fontWeight: FontWeight.w600,
          color: selectedCount > 0 ? AppColors.brandGreen : null,
        ),
      ),
    );
  }

  List<String> _filteredItems(List<String> items) {
    final q = _subQuery.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((i) => i.toLowerCase().contains(q)).toList();
  }

  Widget _buildChipGridInline(
    List<String> items,
    Set<String> selected,
    ValueChanged<Set<String>> onChanged,
  ) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No matching values'),
      );
    }
    return Wrap(
      spacing: SizeConfig.scaleWidth(context, 8),
      runSpacing: SizeConfig.scaleHeight(context, 8),
      children: [
        for (final item in items)
          FilterChip(
            label: Text(item),
            selected: selected.contains(item),
            onSelected: (on) {
              final next = Set<String>.from(selected);
              if (on) {
                next.add(item);
              } else {
                next.remove(item);
              }
              onChanged(next);
            },
            selectedColor: AppColors.brandGreen,
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: selected.contains(item) ? Colors.white : null,
            ),
            side: selected.contains(item)
                ? const BorderSide(color: AppColors.brandGreen)
                : null,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _buildSearchBody(BuildContext context) {
    const fields = <(String, String)>[
      ('shotId', 'Shot ID'),
      ('clientForRef', 'Client for Ref'),
      ('client', 'Client'),
      ('show', 'Show'),
      ('reviewNotes', 'Review Notes'),
      ('frames', 'Frames'),
      ('shotMandays', 'Shot man-days'),
      ('approvedClientMd', 'Approved Client MD'),
      ('flMandays', 'FL Man-days'),
      ('shotsReceivedDate', 'Shots Received Date'),
      ('wipEta', 'WIP ETA'),
      ('eta', 'ETA'),
      ('deliveredOn', 'Delivered on'),
      ('flEta', 'FL ETA'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Type part of any value — rows match as a case-insensitive substring.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        SizedBox(height: SizeConfig.scaleHeight(context, 12)),
        for (final (key, label) in fields) ...[
          TextField(
            controller: _controllers[key],
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 10)),
        ],
      ],
    );
  }

  Widget _filterListTile(
    String title, {
    String? subtitle,
    required int activeCount,
    bool hasText = false,
    required VoidCallback onTap,
  }) {
    final isActive = activeCount > 0 || hasText;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          color: isActive ? AppColors.brandGreen : null,
          fontWeight: isActive ? FontWeight.w600 : null,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: TextStyle(color: isActive ? AppColors.brandGreen : null),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (activeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.brandGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$activeCount',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _labeledChipRow(
    String label,
    List<String> items,
    String? selected,
    ValueChanged<String> onSelect,
  ) {
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
              return Padding(
                padding: const EdgeInsets.all(3),
                child: FilterChip(
                  label: Text(
                    item,
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

// ─────────────────────────────────────────────────────────────────────────────
// Manual creation dialog — mirrors the Projects `_ShotDialog` pattern, but
// collects the 20 production-grid template fields. The show is resolved on
// the backend from the client/show names (or a showId), so this dialog needs
// no client/show picker state.
// ─────────────────────────────────────────────────────────────────────────────

class _NewGridRowDialog extends StatefulWidget {
  final ProductionService service;

  const _NewGridRowDialog({required this.service});

  @override
  State<_NewGridRowDialog> createState() => _NewGridRowDialogState();
}

class _NewGridRowDialogState extends State<_NewGridRowDialog> {
  final _formKey = GlobalKey<FormState>();

  final _client = TextEditingController();
  final _show = TextEditingController();
  final _shotCode = TextEditingController();
  final _coordinator = TextEditingController();
  final _clientForRef = TextEditingController();
  final _frames = TextEditingController();
  final _reviewNotes = TextEditingController();
  final _workStation = TextEditingController();
  final _shotMandays = TextEditingController();
  final _approvedClientMd = TextEditingController();
  final _flMandays = TextEditingController();

  final _shotsReceivedDate = TextEditingController();
  final _wipEta = TextEditingController();
  final _eta = TextEditingController();
  final _deliveredOn = TextEditingController();
  final _flEta = TextEditingController();

  String _tasks = AppConstants.pipelineDepartments.first;
  String _month = AppConstants.months.first;
  String _status = 'Awaiting Approval';

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _client.dispose();
    _show.dispose();
    _shotCode.dispose();
    _coordinator.dispose();
    _clientForRef.dispose();
    _frames.dispose();
    _reviewNotes.dispose();
    _workStation.dispose();
    _shotMandays.dispose();
    _approvedClientMd.dispose();
    _flMandays.dispose();
    _shotsReceivedDate.dispose();
    _wipEta.dispose();
    _eta.dispose();
    _deliveredOn.dispose();
    _flEta.dispose();
    super.dispose();
  }

  String _fmtDateInput(DateTime? d) {
    if (d == null) return '';
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate(
    BuildContext context,
    TextEditingController ctrl,
  ) async {
    final dateStr = ctrl.text.trim();
    DateTime initialDate = DateTime.now();
    try {
      if (dateStr.isNotEmpty) initialDate = DateTime.parse(dateStr);
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final body = <String, dynamic>{
      'client': _client.text.trim(),
      'show': _show.text.trim(),
      'shotCode': _shotCode.text.trim(),
      'tasks': _tasks,
      'coordinator': _coordinator.text.trim(),
      'month': _month,
      'shotsReceivedDate': _shotsReceivedDate.text.trim(),
      'clientForRef': _clientForRef.text.trim(),
      'wipEta': _wipEta.text.trim(),
      'eta': _eta.text.trim(),
      'frames': _frames.text.trim(),
      'reviewNotes': _reviewNotes.text.trim(),
      'status': _status,
      'deliveredOn': _deliveredOn.text.trim(),
      'workStation': _workStation.text.trim(),
      'shotMandays': _shotMandays.text.trim(),
      'approvedClientMd': _approvedClientMd.text.trim(),
      'flEta': _flEta.text.trim(),
      'flMandays': _flMandays.text.trim(),
    };

    final response = await widget.service.createProductionGridRow(body);
    if (!mounted) return;
    if (response['success'] == true) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = response['error']?.toString() ?? 'Failed to create row';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.of(context).size.width;
    final dialogWidth = availableWidth < 760 ? availableWidth * 0.95 : 680.0;
    final halfWidth = (dialogWidth - 16) / 2;

    return AlertDialog(
      title: const Text('New Grid Row'),
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
                // Row 1: Client + Show (resolved server-side)
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _client,
                        labelText: 'Client',
                        prefixIcon: Icons.business_outlined,
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _show,
                        labelText: 'Show',
                        prefixIcon: Icons.movie_outlined,
                      ),
                    ),
                  ],
                ),
                // Row 2: Shot code + Tasks (department)
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _shotCode,
                        labelText: 'Shot ID *',
                        prefixIcon: Icons.confirmation_number_outlined,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomDropdown<String>(
                        labelText: 'Tasks',
                        value: _tasks,
                        items: AppConstants.pipelineDepartments,
                        itemToString: (d) => d,
                        onChanged: (v) {
                          if (v != null) setState(() => _tasks = v);
                        },
                      ),
                    ),
                  ],
                ),
                // Row 3: Coordinator + Status
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _coordinator,
                        labelText: 'Co ordinator',
                        prefixIcon: Icons.person_outline,
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomDropdown<String>(
                        labelText: 'Status',
                        value: _status,
                        items: _gridStatusOptions,
                        itemToString: (s) => s,
                        onChanged: (v) {
                          if (v != null) setState(() => _status = v);
                        },
                      ),
                    ),
                  ],
                ),
                // Row 4: Month + Frames
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomDropdown<String>(
                        labelText: 'Month',
                        value: _month,
                        items: AppConstants.months,
                        itemToString: (m) => m,
                        onChanged: (v) {
                          if (v != null) setState(() => _month = v);
                        },
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _frames,
                        labelText: 'Frames',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                // Row 5: Shots Received Date + Client for Ref
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _shotsReceivedDate,
                        labelText: 'Shots Received Date',
                        isDateField: true,
                        onDateTap: (ctx) => _pickDate(ctx, _shotsReceivedDate),
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _clientForRef,
                        labelText: 'Client for Ref',
                        prefixIcon: Icons.tag_outlined,
                      ),
                    ),
                  ],
                ),
                // Row 6: WIP ETA + ETA
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _wipEta,
                        labelText: 'WIP ETA',
                        isDateField: true,
                        onDateTap: (ctx) => _pickDate(ctx, _wipEta),
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _eta,
                        labelText: 'ETA',
                        isDateField: true,
                        onDateTap: (ctx) => _pickDate(ctx, _eta),
                      ),
                    ),
                  ],
                ),
                // Row 7: Delivered on + Work station
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _deliveredOn,
                        labelText: 'Delivered on',
                        isDateField: true,
                        onDateTap: (ctx) => _pickDate(ctx, _deliveredOn),
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _workStation,
                        labelText: 'Work station',
                        prefixIcon: Icons.desktop_windows_outlined,
                      ),
                    ),
                  ],
                ),
                // Row 8: Shot man-days + Approved Client MD
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _shotMandays,
                        labelText: 'Shot man-days',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _approvedClientMd,
                        labelText: 'Approved Client MD',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                // Row 9: FL ETA + FL Man-days
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _flEta,
                        labelText: 'FL ETA',
                        isDateField: true,
                        onDateTap: (ctx) => _pickDate(ctx, _flEta),
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: CustomTextField(
                        controller: _flMandays,
                        labelText: 'FL Man-days',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                // Row 10: Review Notes
                SizedBox(
                  width: dialogWidth,
                  child: CustomTextField(
                    controller: _reviewNotes,
                    labelText: 'Review Notes',
                    prefixIcon: Icons.notes_outlined,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandGreen,
            foregroundColor: Colors.white,
          ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Import parsing helpers (main-thread friendly).
//
// These mirror the Projects screen's top-level helpers but map raw rows onto
// the 20 production-grid template columns (client, show, shot ID, frames,
// tasks/department, status, etc.). They are top-level and chunk their work
// with event-loop yields so the loader spinner stays responsive while
// parsing on the UI thread (web-safe — no `compute()`/isolate needed).
// ─────────────────────────────────────────────────────────────────────────────

String _normalizeHeaderT(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll(' ', '_')
      .replaceAll('-', '_')
      .replaceAll('.', '');
}

/// Words that identify an import header cell (used to locate the header row).
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

/// Locates the real header row in an Excel sheet. Falls back to row 0.
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
  if (nonEmptyCount <= 2) return matches > 0 && matches == nonEmptyCount;
  final matchRatio = matches / nonEmptyCount;
  return nonEmptyCount >= 4 && matchRatio >= 0.6;
}

/// Direct header → field mapping for the concern template. Keys are the
/// normalized template headers (lowercase, spaces/dashes → underscores);
/// values are the grid API field names.
const Map<String, String> _gridTemplateFieldMap = {
  'co_ordinator': 'coordinator',
  'month': 'month',
  'shots_received_date': 'shotsReceivedDate',
  'client_for_ref': 'clientForRef',
  'client': 'client',
  'show': 'show',
  'wip_eta': 'wipEta',
  'eta': 'eta',
  'shot_id': 'shotCode',
  'frames': 'frames',
  'tasks': 'tasks',
  'review_notes': 'reviewNotes',
  'status': 'status',
  'delivered_on': 'deliveredOn',
  'work_station': 'workStation',
  'shot_man_days': 'shotMandays',
  'approved_client_md': 'approvedClientMd',
  'fl_eta': 'flEta',
  'fl_man_days': 'flMandays',
};

/// Template column order fallback (col_N keys set by the parsers):
/// 0:S No 1:Co ordinator 2:Month 3:Shots Received Date 4:Client for Ref
/// 5:Client 6:Show 7:WIP ETA 8:ETA 9:Shot ID 10:Frames 11:Tasks
/// 12:Review Notes 13:Status 14:Delivered on 15:Work station
/// 16:Shot man-days 17:Approved Client MD 18:FL ETA 19:FL Man-days
const Map<String, int> _gridFieldColumnIndex = {
  'coordinator': 1,
  'month': 2,
  'shotsReceivedDate': 3,
  'clientForRef': 4,
  'client': 5,
  'show': 6,
  'wipEta': 7,
  'eta': 8,
  'shotCode': 9,
  'frames': 10,
  'tasks': 11,
  'reviewNotes': 12,
  'status': 13,
  'deliveredOn': 14,
  'workStation': 15,
  'shotMandays': 16,
  'approvedClientMd': 17,
  'flEta': 18,
  'flMandays': 19,
};

/// Maps one raw import row onto the production-grid API shape. Every field
/// is read directly from the matching concern template header; when a header
/// is missing, the template column position (col_N) is used as a fallback.
Map<String, dynamic> _toGridApiRowT(
  Map<String, dynamic> row,
  List<String> gridStatuses,
) {
  dynamic valueFor(String field) {
    // 1) Direct header lookup (normalized template header name).
    for (final entry in _gridTemplateFieldMap.entries) {
      if (entry.value != field) continue;
      final headerValue = row[entry.key];
      if (headerValue != null && headerValue.toString().trim().isNotEmpty) {
        return headerValue;
      }
    }
    // 2) Positional fallback (col_N keys set by the parsers).
    final col = _gridFieldColumnIndex[field];
    if (col != null) {
      final colValue = row['col_$col'];
      if (colValue != null && colValue.toString().trim().isNotEmpty) {
        return colValue;
      }
    }
    return null;
  }

  String str(String field) => (valueFor(field) ?? '').toString().trim();

  final statusRaw = str('status');
  final status = gridStatuses.contains(statusRaw)
      ? statusRaw
      : 'Awaiting Approval';

  return {
    'client': str('client'),
    'show': str('show'),
    'shotCode': str('shotCode'),
    'tasks': str('tasks').toUpperCase(),
    'coordinator': str('coordinator'),
    'month': str('month'),
    'shotsReceivedDate': _toIsoDateT(valueFor('shotsReceivedDate')),
    'clientForRef': str('clientForRef'),
    'wipEta': _toIsoDateT(valueFor('wipEta')),
    'eta': _toIsoDateT(valueFor('eta')),
    'frames': _toIntValueT(valueFor('frames')),
    'reviewNotes': str('reviewNotes'),
    'status': status,
    'deliveredOn': _toIsoDateT(valueFor('deliveredOn')),
    'workStation': str('workStation'),
    'shotMandays': _toDoubleValueT(valueFor('shotMandays')),
    'approvedClientMd': _toDoubleValueT(valueFor('approvedClientMd')),
    'flEta': _toIsoDateT(valueFor('flEta')),
    'flMandays': _toDoubleValueT(valueFor('flMandays')),
  };
}

/// Compact display row for the import preview table (all 20 columns).
Map<String, dynamic> _gridPreviewRowT(Map<String, dynamic> row) {
  String s(String key) => (row[key] ?? '').toString().trim();
  return <String, dynamic>{
    'coordinator': s('coordinator'),
    'month': s('month'),
    'shotsReceivedDate': s('shotsReceivedDate'),
    'clientForRef': s('clientForRef'),
    'client': s('client'),
    'show': s('show'),
    'wipEta': s('wipEta'),
    'eta': s('eta'),
    'shotCode': s('shotCode'),
    'frames': s('frames'),
    'tasks': s('tasks'),
    'reviewNotes': s('reviewNotes'),
    'status': s('status'),
    'deliveredOn': s('deliveredOn'),
    'workStation': s('workStation'),
    'shotMandays': s('shotMandays'),
    'approvedClientMd': s('approvedClientMd'),
    'flEta': s('flEta'),
    'flMandays': s('flMandays'),
  };
}

/// Number of rows processed between event-loop yields while parsing.
/// Keeps the UI thread (and the loader spinner) responsive on web, where
/// parsing runs on the main isolate.
const int _importYieldEvery = 40;

Future<void> _importYield() => Future<void>.delayed(Duration.zero);

/// Parses pasted CSV text into grid API rows, locating the header row,
/// mapping every column and de-duplicating shot codes. Yields to the event
/// loop every [_importYieldEvery] rows.
Future<List<Map<String, dynamic>>> _parseGridCsvTextRowsAsync(
  String csvText,
  List<String> gridStatuses, {
  void Function(int parsedRows)? onProgress,
}) async {
  final lines = const LineSplitter().convert(csvText.trim());
  if (lines.length < 2) return const [];

  final headerIndex = _findHeaderRowIndexLinesT(lines);
  final headers = _splitCsvLineT(
    lines[headerIndex],
  ).map(_normalizeHeaderT).toList(growable: false);
  final headerLabels = headers.where((h) => h.isNotEmpty).toSet();
  final out = <Map<String, dynamic>>[];
  final seenShotCodes = <String>{};
  var processed = 0;

  for (var i = headerIndex + 1; i < lines.length; i++) {
    if (++processed % _importYieldEvery == 0) {
      await _importYield();
      onProgress?.call(out.length);
    }
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
    final apiRow = _toGridApiRowT(raw, gridStatuses);
    final code = (apiRow['shotCode'] ?? '').toString().trim();
    if (code.isEmpty) continue;
    if (seenShotCodes.contains(code)) continue;
    seenShotCodes.add(code);
    out.add(apiRow);
  }
  return out;
}

/// Parses Excel bytes into grid API rows, yielding to the event loop around
/// the workbook decode and every [_importYieldEvery] data rows.
Future<List<Map<String, dynamic>>> _parseGridExcelRowsAsync(
  Uint8List bytes,
  List<String> gridStatuses, {
  void Function(int parsedRows)? onProgress,
}) async {
  await _importYield();
  final excel = Excel.decodeBytes(bytes);
  await _importYield();
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
  var processed = 0;
  for (var i = headerIndex + 1; i < rows.length; i++) {
    if (++processed % _importYieldEvery == 0) {
      await _importYield();
      onProgress?.call(out.length);
    }
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
    final apiRow = _toGridApiRowT(raw, gridStatuses);
    final code = (apiRow['shotCode'] ?? '').toString().trim();
    if (code.isEmpty) continue;
    if (seenShotCodes.contains(code)) continue;
    seenShotCodes.add(code);
    out.add(apiRow);
  }
  return out;
}

/// Parses CSV bytes into grid API rows, yielding to the event loop every
/// [_importYieldEvery] rows.
Future<List<Map<String, dynamic>>> _parseGridCsvRowsAsync(
  Uint8List bytes,
  List<String> gridStatuses, {
  void Function(int parsedRows)? onProgress,
}) async {
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
  var processed = 0;
  for (var i = headerIndex + 1; i < lines.length; i++) {
    if (++processed % _importYieldEvery == 0) {
      await _importYield();
      onProgress?.call(out.length);
    }
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
    final apiRow = _toGridApiRowT(raw, gridStatuses);
    final code = (apiRow['shotCode'] ?? '').toString().trim();
    if (code.isEmpty) continue;
    if (seenShotCodes.contains(code)) continue;
    seenShotCodes.add(code);
    out.add(apiRow);
  }
  return out;
}

/// Parses an imported file's bytes (Excel or CSV) into grid API rows,
/// yielding to the event loop while doing so.
Future<List<Map<String, dynamic>>> _parseGridFileRowsAsync(
  Uint8List bytes,
  String extension,
  List<String> gridStatuses, {
  void Function(int parsedRows)? onProgress,
}) async {
  if (extension == 'xlsx' ||
      extension == 'xls' ||
      extension == 'xlsm' ||
      extension == 'xlsb' ||
      extension == 'ods') {
    return _parseGridExcelRowsAsync(
      bytes,
      gridStatuses,
      onProgress: onProgress,
    );
  }
  if (extension == 'csv') {
    return _parseGridCsvRowsAsync(bytes, gridStatuses, onProgress: onProgress);
  }
  throw Exception('Unsupported format: .$extension');
}

/// HTTP POST to the grid bulk-upsert endpoint using `package:http`
/// directly (independent of the `ApiController` singleton).
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

/// Uploads parsed grid rows to the bulk-upsert endpoint in 100-row chunks
/// (async HTTP — naturally yields between chunks). Returns a summary map:
/// total / created / updated / errors / notes / preview.
Future<Map<String, dynamic>> _saveParsedRowsAsync(
  List<Map<String, dynamic>> rows,
  String baseUrl,
  String endpoint,
  String? token, {
  void Function(int chunkDone, int chunkTotal)? onChunk,
}) async {
  var created = 0;
  var updated = 0;
  final errors = <String>[];
  final notes = <String>[];
  const chunkSize = 100;
  final chunkTotal = (rows.length / chunkSize).ceil();
  var chunkDone = 0;
  for (var i = 0; i < rows.length; i += chunkSize) {
    final end = (i + chunkSize).clamp(0, rows.length);
    final resp = await _postBulkUpsertT(
      baseUrl,
      endpoint,
      token,
      rows.sublist(i, end),
    );
    created += (resp['created'] as int?) ?? 0;
    updated += (resp['updated'] as int?) ?? 0;
    chunkDone++;
    onChunk?.call(chunkDone, chunkTotal);
    for (final e in (resp['errors'] as List<dynamic>?) ?? const <dynamic>[]) {
      if (errors.length < 100) errors.add(e.toString());
    }
    for (final n in (resp['notes'] as List<dynamic>?) ?? const <dynamic>[]) {
      if (notes.length < 100) notes.add(n.toString());
    }
  }

  // Cap the preview — the table paginates this client-side.
  const previewCap = 60;
  final preview = <Map<String, dynamic>>[];
  final limit = rows.length < previewCap ? rows.length : previewCap;
  for (var i = 0; i < limit; i++) {
    preview.add(_gridPreviewRowT(rows[i]));
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
