import 'package:flutter/material.dart';
import '../../core/utils/size_config.dart';
import 'filter_icon.dart';

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

  DynamicTableField({
    required this.key,
    required this.label,
    this.width,
    this.numeric = false,
    this.builder,
    this.filterOptions,
    this.filterRequired,
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
  final double mobileBreakpoint;
  final int frozenColumnCount;
  final int rowsPerPage;
  final int? currentPage;
  final ValueChanged<int>? onPageChanged;

  const DynamicDataTable({
    super.key,
    required this.fields,
    required this.rows,
    this.width,
    this.height,
    this.minColumnWidth = 0,
    this.headingRowHeight = 44,
    this.dataRowMinHeight = 44,
    this.dataRowMaxHeight = 56,
    this.columnSpacing = 24,
    this.padding = const EdgeInsets.all(8),
    this.empty,
    this.onFilterChanged,
    this.enableMobileFilterFab = true,
    this.mobileBreakpoint = 900,
    this.frozenColumnCount = 0,
    this.rowsPerPage = 50,
    this.currentPage,
    this.onPageChanged,
  });

  @override
  State<DynamicDataTable> createState() => _DynamicDataTableState();
}

class _DynamicDataTableState extends State<DynamicDataTable> {
  int _internalPage = 0;

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

  List<Map<String, dynamic>> get _visibleRows {
    final page = _effectivePage;
    if (widget.rowsPerPage <= 0 || widget.rows.length <= widget.rowsPerPage) {
      return widget.rows;
    }
    final start = page * widget.rowsPerPage;
    final end = (start + widget.rowsPerPage).clamp(0, widget.rows.length);
    if (start >= widget.rows.length) {
      if (widget.currentPage != null && widget.onPageChanged != null) {
        widget.onPageChanged!(0);
        return widget.rows.take(widget.rowsPerPage).toList();
      }
      _internalPage = 0;
      return widget.rows.take(widget.rowsPerPage).toList();
    }
    return widget.rows.sublist(start, end);
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
            label: Row(
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

  /// Hand-icon dragger pill pinned under the table. Dragging it (or dragging
  /// anywhere on the table with the mouse) pans wide tables horizontally.
  Widget _buildSwipeHandle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: SizeConfig.scaleHeight(context, 4)),
      child: Center(
        child: MouseRegion(
          cursor: _isDragging
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.grab,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _setDragging(true),
            onHorizontalDragUpdate: (details) => _panTable(details.delta.dx),
            onHorizontalDragEnd: (_) => _setDragging(false),
            onHorizontalDragCancel: () => _setDragging(false),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: SizeConfig.scaleWidth(context, 12),
                vertical: SizeConfig.scaleHeight(context, 4),
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.back_hand,
                    size: SizeConfig.iconSize(context, 14),
                    color: scheme.onSurfaceVariant,
                  ),
                  SizedBox(width: SizeConfig.scaleWidth(context, 5)),
                  Text(
                    'Swipe',
                    style: TextStyle(
                      fontSize: SizeConfig.fontSize(context, 11),
                      color: scheme.onSurfaceVariant,
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
            isMobile &&
            widget.enableMobileFilterFab &&
            widget.onFilterChanged != null &&
            filterableFields.isNotEmpty;

        Widget buildContent() {
          // ── Frozen columns mode ──────────────────────────────────
          if (widget.frozenColumnCount > 0 &&
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
