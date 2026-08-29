import 'package:flutter/material.dart';
import '../../core/utils/size_config.dart';
import 'filter_icon.dart';
import 'sortable_header.dart';

typedef DynamicFieldBuilder =
    Widget Function(
      BuildContext context,
      dynamic value,
      Map<String, dynamic> row,
      int rowIndex,
    );

class DynamicTableField {
  final String key;
  final String label;
  final double? width;
  final bool numeric;
  final DynamicFieldBuilder? builder;
  final List<FilterOption>? filterOptions;
  final bool? filterRequired;

  /// When false the column header shows no sort arrow and tapping it does
  /// nothing — used for checkbox/selection columns.
  final bool sortable;

  DynamicTableField({
    required this.key,
    required this.label,
    this.width,
    this.numeric = false,
    this.builder,
    this.filterOptions,
    this.filterRequired,
    this.sortable = true,
  });
}

class DynamicDataTable extends StatefulWidget {
  final List<DynamicTableField> fields;
  final List<Map<String, dynamic>> rows;
  final double? width;
  final double? height;
  final double minColumnWidth;
  final double headingRowHeight;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;
  final double columnSpacing;
  final EdgeInsetsGeometry padding;
  final Widget? empty;
  final void Function(String fieldKey, dynamic value)? onFilterChanged;
  final bool enableMobileFilterFab;

  /// When true, the filter button is also shown on desktop-width layouts
  /// (not only below [mobileBreakpoint]) so hosts that have no other filter
  /// UI (e.g. dashboard, reports) still expose per-column filtering.
  final bool showDesktopFilterButton;
  final double mobileBreakpoint;
  final int frozenColumnCount;
  final int rowsPerPage;
  final int? currentPage;
  final ValueChanged<int>? onPageChanged;
  final bool fitToWidth;
  final bool showCellBorders;

  /// Called when a data row is double-tapped (plain-text cells only — cells
  /// with a custom [builder] keep their own interaction, e.g. dropdowns).
  final void Function(Map<String, dynamic> row, int rowIndex)? onRowDoubleTap;

  const DynamicDataTable({
    super.key,
    required this.fields,
    required this.rows,
    this.width,
    this.height,
    this.minColumnWidth = 0,
    this.headingRowHeight = 44,
    this.dataRowMinHeight = 44,
    this.dataRowMaxHeight = 30,
    this.columnSpacing = 24,
    this.padding = const EdgeInsets.all(8),
    this.empty,
    this.onFilterChanged,
    this.enableMobileFilterFab = true,
    this.showDesktopFilterButton = false,
    this.mobileBreakpoint = 900,
    this.frozenColumnCount = 0,
    this.rowsPerPage = 50,
    this.currentPage,
    this.onPageChanged,
    this.fitToWidth = false,
    this.showCellBorders = false,
    this.onRowDoubleTap,
  });

  @override
  State<DynamicDataTable> createState() => _DynamicDataTableState();
}

class _DynamicDataTableState extends State<DynamicDataTable> {
  int _internalPage = 0;

  // Column sorting state: the index (into widget.fields) of the active sort
  // column and its direction. Tapping a column header toggles ascending /
  // descending; tapping a different column starts ascending on it.
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Cached sorted row list — recomputed only when the source list, its
  // length, or the sort state changes, so repeated builds never re-sort the
  // full row list (sorting is O(n log n), but grid builds are frequent).
  List<Map<String, dynamic>>? _cachedSortedRows;
  List<Map<String, dynamic>>? _cachedSortedSource;
  int _cachedSortedSourceLength = -1;
  int? _cachedSortedIndex;
  bool _cachedSortedAscending = true;

  // Cached visible-page slice — recomputed only when the page, page size, or
  // the source row list (identity/length) changes, so repeated builds never
  // re-slice/re-parse the full row list (e.g. 10-row pages with hundreds of
  // rows only ever build 10 rows, and only once per page/filter change).
  List<Map<String, dynamic>>? _cachedVisibleRows;
  int _cachedVisiblePage = -1;
  int _cachedVisibleRowsPerPage = -1;
  List<Map<String, dynamic>>? _cachedVisibleSourceRows;
  int _cachedVisibleSourceLength = -1;

  final ScrollController _hScrollController = ScrollController();
  bool _isDragging = false;
  bool _hasOverflow = false;

  @override
  void initState() {
    super.initState();
    _hScrollController.addListener(_onScrollChanged);
  }

  @override
  void dispose() {
    _hScrollController.removeListener(_onScrollChanged);
    _hScrollController.dispose();
    super.dispose();
  }

  void _onScrollChanged() {
    // maxScrollExtent is only valid after layout and the listener can fire
    // during layout — defer the check so setState is never called mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hScrollController.hasClients) return;
      final has = _hScrollController.position.maxScrollExtent > 0;
      if (has != _hasOverflow) setState(() => _hasOverflow = has);
    });
  }

  void _panTable(double dx) {
    if (!_hScrollController.hasClients) return;
    final pos = _hScrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    _hScrollController.jumpTo(
      (pos.pixels - dx).clamp(0.0, pos.maxScrollExtent),
    );
  }

  void _setDragging(bool value) {
    if (_isDragging == value || !mounted) return;
    setState(() => _isDragging = value);
  }

  int get _effectivePage {
    if (widget.currentPage != null && widget.onPageChanged != null) {
      return widget.currentPage!;
    }
    return _internalPage;
  }

  int get _totalPages => widget.rowsPerPage > 0
      ? (widget.rows.length / widget.rowsPerPage).ceil()
      : 1;

  /// Applies the active column sort to [source], returning a cached sorted
  /// copy when sorting is active (null-safe, type-aware via [compareCellValues])
  /// or the original list when no sort column is selected.
  List<Map<String, dynamic>> _applySort(List<Map<String, dynamic>> source) {
    final index = _sortColumnIndex;
    final active =
        index != null &&
        index >= 0 &&
        index < widget.fields.length &&
        widget.fields[index].sortable;
    if (!active) {
      _cachedSortedRows = null;
      return source;
    }
    if (_cachedSortedRows != null &&
        identical(_cachedSortedSource, source) &&
        _cachedSortedSourceLength == source.length &&
        _cachedSortedIndex == index &&
        _cachedSortedAscending == _sortAscending) {
      return _cachedSortedRows!;
    }
    final field = widget.fields[index];
    final sorted = [...source]
      ..sort((a, b) {
        final cmp = compareCellValues(a[field.key], b[field.key]);
        return _sortAscending ? cmp : -cmp;
      });
    _cachedSortedRows = sorted;
    _cachedSortedSource = source;
    _cachedSortedSourceLength = source.length;
    _cachedSortedIndex = index;
    _cachedSortedAscending = _sortAscending;
    return sorted;
  }

  void _toggleSort(DynamicTableField field) {
    if (!field.sortable) return;
    final index = widget.fields.indexOf(field);
    if (index < 0) return;
    setState(() {
      if (_sortColumnIndex == index) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = index;
        _sortAscending = true;
      }
    });
  }

  bool _isFieldSorted(DynamicTableField field) {
    if (!field.sortable) return false;
    return _sortColumnIndex != null &&
        widget.fields.indexOf(field) == _sortColumnIndex;
  }

  List<Map<String, dynamic>> get _visibleRows {
    final page = _effectivePage;
    final source = _applySort(widget.rows);
    if (widget.rowsPerPage <= 0 || source.length <= widget.rowsPerPage) {
      return source;
    }

    // Cache the sliced page rows: repeated builds (page flips, filter
    // re-renders, cell-edit rebuilds) reuse the same page slice instead of
    // re-slicing the full list every time. Keyed on page + rowsPerPage + the
    // source list instance/length; any change invalidates the cache.
    if (_cachedVisibleRows != null &&
        _cachedVisiblePage == page &&
        _cachedVisibleRowsPerPage == widget.rowsPerPage &&
        _cachedVisibleSourceLength == source.length &&
        identical(_cachedVisibleSourceRows, source)) {
      return _cachedVisibleRows!;
    }

    final start = page * widget.rowsPerPage;
    final end = (start + widget.rowsPerPage).clamp(0, source.length);
    List<Map<String, dynamic>> visible;
    if (start >= source.length) {
      if (widget.currentPage != null && widget.onPageChanged != null) {
        widget.onPageChanged!(0);
        visible = source.take(widget.rowsPerPage).toList();
      } else {
        _internalPage = 0;
        visible = source.take(widget.rowsPerPage).toList();
      }
    } else {
      visible = source.sublist(start, end);
    }

    _cachedVisibleRows = visible;
    _cachedVisiblePage = page;
    _cachedVisibleRowsPerPage = widget.rowsPerPage;
    _cachedVisibleSourceRows = source;
    _cachedVisibleSourceLength = source.length;
    return visible;
  }

  @override
  void didUpdateWidget(covariant DynamicDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final externalControl =
        widget.currentPage != null && widget.onPageChanged != null;
    if (!externalControl &&
        oldWidget.rows.length != widget.rows.length &&
        _internalPage >= _totalPages) {
      _internalPage = (_totalPages - 1).clamp(0, _totalPages);
    }
  }

  String _initialFilterValueForField(DynamicTableField field) {
    if (field.filterOptions == null || field.filterOptions!.isEmpty) {
      return '';
    }
    final selected = field.filterOptions!.where((f) => f.isSelected);
    if (selected.isEmpty) {
      return '';
    }
    return selected.first.value.toString();
  }

  Widget _buildDataTableForFields(
    BuildContext context,
    List<DynamicTableField> tableFields,
    bool isMobile,
    List<Map<String, dynamic>> tableRows, {
    bool enableSwipe = true,
  }) {
    // Fit-to-width mode: stretch columns proportionally instead of using a
    // horizontal scroll view.
    if (widget.fitToWidth) {
      return _buildFitToWidthTable(context, tableFields, tableRows);
    }

    // Full cell borders + centered content (spreadsheet-style grid).
    if (widget.showCellBorders) {
      return _buildBorderedScrollableTable(
        context,
        tableFields,
        tableRows,
        enableSwipe: enableSwipe,
      );
    }

    final table = SingleChildScrollView(
      controller: enableSwipe ? _hScrollController : null,
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: widget.headingRowHeight,
        dataRowMinHeight: widget.dataRowMinHeight,
        dataRowMaxHeight: widget.dataRowMaxHeight,
        columnSpacing: widget.columnSpacing,
        columns: tableFields.map((field) {
          return DataColumn(
            numeric: field.numeric,
            label: field.sortable
                ? SortableHeader(
                    label: field.label,
                    isSorted: _isFieldSorted(field),
                    sortAscending: _sortAscending,
                    onTap: () => _toggleSort(field),
                    center: true,
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          field.label,
                          textAlign: TextAlign.center,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ],
                  ),
          );
        }).toList(),
        rows: List<DataRow>.generate(tableRows.length, (index) {
          final row = tableRows[index];
          return DataRow(
            cells: tableFields.map((field) {
              final value = row[field.key];
              Widget child;
              if (field.builder != null) {
                child = field.builder!(context, value, row, index);
              } else {
                final displayText =
                    (value == null || value.toString().trim().isEmpty)
                    ? '-'
                    : value.toString();
                child = Text(
                  displayText,
                  textAlign: TextAlign.center,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                );
                if (widget.onRowDoubleTap != null) {
                  child = GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: () => widget.onRowDoubleTap!(row, index),
                    child: child,
                  );
                }
              }
              return DataCell(child);
            }).toList(),
          );
        }),
      ),
    );

    if (!enableSwipe) return table;

    return MouseRegion(
      cursor: _isDragging
          ? SystemMouseCursors.grabbing
          : (_hasOverflow ? SystemMouseCursors.grab : SystemMouseCursors.basic),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => _setDragging(true),
        onHorizontalDragUpdate: (details) => _panTable(details.delta.dx),
        onHorizontalDragEnd: (_) => _setDragging(false),
        onHorizontalDragCancel: () => _setDragging(false),
        child: table,
      ),
    );
  }

  /// Renders the table stretched to the available width using proportional
  /// (flex) column widths — the table never scrolls horizontally.
  Widget _buildFitToWidthTable(
    BuildContext context,
    List<DynamicTableField> tableFields,
    List<Map<String, dynamic>> tableRows,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final headerStyle = TextStyle(
      fontSize: SizeConfig.fontSize(context, 12),
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    );
    final cellStyle = TextStyle(
      fontSize: SizeConfig.fontSize(context, 12),
      color: scheme.onSurface,
    );

    // Floor the flex weights so no column collapses to an unreadable width:
    // every column gets at least 35% of the average weight, keeping wide
    // columns proportional while narrow ones stay legible. The total flex
    // only grows, so the table can never overflow horizontally.
    final flexValues = tableFields
        .map((field) => (field.width ?? 100.0).toDouble())
        .toList(growable: false);
    final floor = flexValues.isEmpty
        ? 100.0
        : (flexValues.fold(0.0, (a, b) => a + b) / flexValues.length) * 0.35;
    final columnWidths = <int, TableColumnWidth>{
      for (var i = 0; i < tableFields.length; i++)
        i: FlexColumnWidth(flexValues[i] < floor ? floor : flexValues[i]),
    };

    final headerRow = TableRow(
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
      children: [
        for (final field in tableFields)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: SizeConfig.scaleWidth(context, 6),
              vertical: SizeConfig.scaleHeight(context, 8),
            ),
            child: field.sortable
                ? SortableHeader(
                    label: field.label,
                    isSorted: _isFieldSorted(field),
                    sortAscending: _sortAscending,
                    onTap: () => _toggleSort(field),
                    style: headerStyle,
                    center: true,
                    wrap: true,
                  )
                : Text(
                    field.label,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: headerStyle,
                  ),
          ),
      ],
    );

    final dataRows = <TableRow>[
      for (var index = 0; index < tableRows.length; index++)
        TableRow(
          children: [
            for (final field in tableFields)
              _buildFitToWidthCell(
                context,
                field,
                tableRows[index],
                index,
                cellStyle,
              ),
          ],
        ),
    ];

    return Table(
      columnWidths: columnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        left: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        right: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        horizontalInside: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
        verticalInside: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      children: [headerRow, ...dataRows],
    );
  }

  Widget _buildFitToWidthCell(
    BuildContext context,
    DynamicTableField field,
    Map<String, dynamic> row,
    int rowIndex,
    TextStyle cellStyle, {
    bool centerAll = false,
  }) {
    final value = row[field.key];
    Widget child;
    if (field.builder != null) {
      child = field.builder!(context, value, row, rowIndex);
    } else {
      final displayText = (value == null || value.toString().trim().isEmpty)
          ? '-'
          : value.toString();
      child = Text(
        displayText,
        textAlign: centerAll || !field.numeric
            ? TextAlign.center
            : TextAlign.right,
        // Never ellipsize — wrap so the full value stays visible.
        softWrap: true,
        style: cellStyle,
      );
    }
    final cell = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.scaleWidth(context, 6),
        vertical: SizeConfig.scaleHeight(context, 6),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: widget.dataRowMinHeight,
          // No max-height cap: rows grow to fit wrapped content so every
          // field is fully visible.
        ),
        child: child,
      ),
    );
    // Double-tap-to-edit on plain-text cells (builder cells like dropdowns
    // keep their own interactions).
    if (widget.onRowDoubleTap != null && field.builder == null) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: () => widget.onRowDoubleTap!(row, rowIndex),
        child: cell,
      );
    }
    return cell;
  }

  /// Spreadsheet-style grid: every cell gets a full border and all content is
  /// centered. Columns keep their configured widths (minColumnWidth floor) and
  /// the table scrolls horizontally when it overflows, with the same swipe/
  /// grab-to-pan behavior as the standard DataTable mode.
  Widget _buildBorderedScrollableTable(
    BuildContext context,
    List<DynamicTableField> tableFields,
    List<Map<String, dynamic>> tableRows, {
    bool enableSwipe = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.45);
    final headerStyle = TextStyle(
      fontSize: SizeConfig.fontSize(context, 12),
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    );
    final cellStyle = TextStyle(
      fontSize: SizeConfig.fontSize(context, 12),
      color: scheme.onSurface,
    );

    // Fixed column widths: prefer the field's configured width, falling back
    // to minColumnWidth. Never let a column shrink below minColumnWidth.
    final columnWidths = <int, TableColumnWidth>{
      for (var i = 0; i < tableFields.length; i++)
        i: FixedColumnWidth(
          (tableFields[i].width ?? widget.minColumnWidth) <
                  widget.minColumnWidth
              ? widget.minColumnWidth
              : (tableFields[i].width ?? widget.minColumnWidth),
        ),
    };

    final headerRow = TableRow(
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
      children: [
        for (final field in tableFields)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: SizeConfig.scaleWidth(context, 6),
              vertical: SizeConfig.scaleHeight(context, 8),
            ),
            child: field.sortable
                ? SortableHeader(
                    label: field.label,
                    isSorted: _isFieldSorted(field),
                    sortAscending: _sortAscending,
                    onTap: () => _toggleSort(field),
                    style: headerStyle,
                    center: true,
                    wrap: true,
                  )
                : Text(
                    field.label,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: headerStyle,
                  ),
          ),
      ],
    );

    final dataRows = <TableRow>[
      for (var index = 0; index < tableRows.length; index++)
        TableRow(
          children: [
            for (final field in tableFields)
              _buildFitToWidthCell(
                context,
                field,
                tableRows[index],
                index,
                cellStyle,
                centerAll: true,
              ),
          ],
        ),
    ];

    final table = SingleChildScrollView(
      controller: enableSwipe ? _hScrollController : null,
      scrollDirection: Axis.horizontal,
      child: Table(
        columnWidths: columnWidths,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        // Complete outer frame (all four sides) + internal grid lines, so the
        // table always renders as a fully-framed spreadsheet no matter how the
        // host screen wraps it (flush inside a GlassContainer like Production
        // Management, or padded inside a card).
        border: TableBorder(
          top: BorderSide(color: borderColor),
          bottom: BorderSide(color: borderColor),
          left: BorderSide(color: borderColor),
          right: BorderSide(color: borderColor),
          horizontalInside: BorderSide(color: borderColor),
          verticalInside: BorderSide(color: borderColor),
        ),
        children: [headerRow, ...dataRows],
      ),
    );

    if (!enableSwipe) return table;

    return MouseRegion(
      cursor: _isDragging
          ? SystemMouseCursors.grabbing
          : (_hasOverflow ? SystemMouseCursors.grab : SystemMouseCursors.basic),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => _setDragging(true),
        onHorizontalDragUpdate: (details) => _panTable(details.delta.dx),
        onHorizontalDragEnd: (_) => _setDragging(false),
        onHorizontalDragCancel: () => _setDragging(false),
        child: table,
      ),
    );
  }

  Future<void> _showMobileFilters(
    BuildContext context,
    List<DynamicTableField> filterableFields,
  ) {
    final draft = <String, String>{
      for (final field in filterableFields)
        field.key: _initialFilterValueForField(field),
    };

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  SizeConfig.scaleWidth(context, 16),
                  SizeConfig.scaleHeight(context, 16),
                  SizeConfig.scaleWidth(context, 16),
                  SizeConfig.scaleHeight(context, 16) + bottomInset,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: SizeConfig.fontSize(context, 18),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: SizeConfig.scaleHeight(context, 12)),
                      ...filterableFields.map((field) {
                        final options = field.filterOptions ?? const [];
                        final typedOptions = options
                            .where((opt) => !opt.needsQuery)
                            .toList(growable: false);
                        final useDropdown = typedOptions.isNotEmpty;

                        if (useDropdown) {
                          final currentValue = draft[field.key];
                          final validCurrent =
                              typedOptions.any(
                                (o) => o.value.toString() == currentValue,
                              )
                              ? currentValue
                              : null;
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: SizeConfig.scaleHeight(context, 10),
                            ),
                            child: DropdownButtonFormField<String>(
                              initialValue: validCurrent,
                              decoration: InputDecoration(
                                labelText: field.label,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: typedOptions
                                  .map(
                                    (o) => DropdownMenuItem<String>(
                                      value: o.value.toString(),
                                      child: Text(o.label),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                setModalState(() {
                                  draft[field.key] = value ?? '';
                                });
                              },
                            ),
                          );
                        }

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: SizeConfig.scaleHeight(context, 10),
                          ),
                          child: TextFormField(
                            initialValue: draft[field.key] ?? '',
                            decoration: InputDecoration(
                              labelText: field.label,
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (value) {
                              draft[field.key] = value;
                            },
                          ),
                        );
                      }),
                      SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                for (final field in filterableFields) {
                                  draft[field.key] = '';
                                  widget.onFilterChanged?.call(field.key, '');
                                }
                                Navigator.of(sheetContext).pop();
                              },
                              child: const Text('Clear'),
                            ),
                          ),
                          SizedBox(width: SizeConfig.scaleWidth(context, 10)),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                for (final field in filterableFields) {
                                  widget.onFilterChanged?.call(
                                    field.key,
                                    draft[field.key] ?? '',
                                  );
                                }
                                Navigator.of(sheetContext).pop();
                              },
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fields.isEmpty) {
      return const SizedBox.shrink();
    }
    if (widget.rows.isEmpty && widget.empty != null) {
      return widget.empty!;
    }

    final visibleRows = _visibleRows;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < widget.mobileBreakpoint;
        final filterableFields = widget.fields
            .where((field) => field.filterRequired != false)
            .toList(growable: false);
        final shouldShowMobileFilterFab =
            widget.onFilterChanged != null &&
            filterableFields.isNotEmpty &&
            ((isMobile && widget.enableMobileFilterFab) ||
                widget.showDesktopFilterButton);

        Widget buildContent() {
          // ── Frozen columns mode ──────────────────────────────────
          if (!widget.fitToWidth &&
              widget.frozenColumnCount > 0 &&
              widget.frozenColumnCount < widget.fields.length) {
            final frozenFieldsList = widget.fields
                .take(widget.frozenColumnCount)
                .toList();
            final scrollableFieldsList = widget.fields
                .skip(widget.frozenColumnCount)
                .toList();

            final frozenTable = _buildDataTableForFields(
              context,
              frozenFieldsList,
              isMobile,
              visibleRows,
              enableSwipe: false,
            );
            final scrollableTable = _buildDataTableForFields(
              context,
              scrollableFieldsList,
              isMobile,
              visibleRows,
            );

            return LayoutBuilder(
              builder: (ctx, outerConstraints) {
                final availableWidth = outerConstraints.maxWidth.isFinite
                    ? outerConstraints.maxWidth
                    : 800.0;
                final frozenW = availableWidth * 0.40;

                return SizedBox(
                  width: availableWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: frozenW,
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                              ),
                              child: frozenTable,
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: ClipRect(child: scrollableTable)),
                    ],
                  ),
                );
              },
            );
          }

          // ── Standard (no frozen columns) ─────────────────────────
          final table = _buildDataTableForFields(
            context,
            widget.fields,
            isMobile,
            visibleRows,
          );
          return ClipRect(child: table);
        }

        final content = Padding(padding: widget.padding, child: buildContent());

        final tableWithMobileFilters = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (shouldShowMobileFilterFab)
              Padding(
                padding: EdgeInsets.only(
                  bottom: SizeConfig.scaleHeight(context, 8),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    onPressed: () =>
                        _showMobileFilters(context, filterableFields),
                    child: const Icon(Icons.filter_alt_outlined),
                  ),
                ),
              ),

            content,
            // if (_hasOverflow) _buildSwipeHandle(context),
          ],
        );

        if (widget.height != null) {
          return SizedBox(
            height: widget.height,
            child: Column(
              children: [
                Flexible(
                  child: SingleChildScrollView(child: tableWithMobileFilters),
                ),
              ],
            ),
          );
        }
        return tableWithMobileFilters;
      },
    );
  }
}
