import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vfxpick_pipeline/shared/widgets/filter_icon.dart';

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

  const DynamicTableField({
    required this.key,
    required this.label,
    this.width,
    this.numeric = false,
    this.builder,
    this.filterOptions,
    this.filterRequired,
  });
}

class DynamicDataTable extends StatelessWidget {
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
  });

  double _estimatedWidth() {
    var total = 0.0;
    for (final field in fields) {
      total += field.width ?? _autoWidthForLabel(field.label);
    }
    total += math.max(0, fields.length - 1) * columnSpacing;
    return total + 32;
  }

  double _autoWidthForLabel(String label) {
    final estimated = (label.length * 9) + 40;
    return math.max(minColumnWidth, estimated.toDouble());
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
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                            padding: const EdgeInsets.only(bottom: 10),
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
                          padding: const EdgeInsets.only(bottom: 10),
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                for (final field in filterableFields) {
                                  draft[field.key] = '';
                                  onFilterChanged?.call(field.key, '');
                                }
                                Navigator.of(sheetContext).pop();
                              },
                              child: const Text('Clear'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                for (final field in filterableFields) {
                                  onFilterChanged?.call(
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
    if (fields.isEmpty) {
      return const SizedBox.shrink();
    }
    if (rows.isEmpty && empty != null) {
      return empty!;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < mobileBreakpoint;
        final filterableFields = fields
            .where((field) => field.filterRequired != false)
            .toList(growable: false);
        final estimatedWidth = width ?? _estimatedWidth();
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : estimatedWidth;
        final minWidth = math.max(viewportWidth, estimatedWidth);

        final table = DataTable(
          headingRowHeight: headingRowHeight,
          dataRowMinHeight: dataRowMinHeight,
          dataRowMaxHeight: dataRowMaxHeight,
          columnSpacing: columnSpacing,
          columns: fields
              .map(
                (field) => DataColumn(
                  numeric: field.numeric,
                  label: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: field.width ?? _autoWidthForLabel(field.label),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(field.label, textAlign: TextAlign.left),
                        if (!isMobile && field.filterRequired != false)
                          FilterIcon(
                            label: field.label,
                            options:
                                field.filterOptions != null &&
                                    field.filterOptions!.isNotEmpty
                                ? field.filterOptions!
                                : [
                                    FilterOption(
                                      label: 'Custom...',
                                      value: '__custom__',
                                      needsQuery: true,
                                    ),
                                  ],
                            onFilterChanged: (v) {
                              if (onFilterChanged != null) {
                                onFilterChanged!(field.key, v);
                              }
                            },
                            onClear: () {
                              if (onFilterChanged != null) {
                                onFilterChanged!(field.key, '');
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
          rows: List<DataRow>.generate(rows.length, (index) {
            final row = rows[index];
            return DataRow(
              cells: fields.map((field) {
                final value = row[field.key];
                Widget child;
                if (field.builder != null) {
                  child = field.builder!(context, value, row, index);
                } else {
                  child = Text(
                    (value ?? '—').toString(),
                    textAlign: field.numeric
                        ? TextAlign.center
                        : TextAlign.start,
                  );
                }

                child = ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: field.width ?? _autoWidthForLabel(field.label),
                  ),
                  child: child,
                );
                return DataCell(child);
              }).toList(),
            );
          }),
        );

        final horizontal = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth),
            child: table,
          ),
        );

        final content = Padding(padding: padding, child: horizontal);
        final shouldShowMobileFilterFab =
            isMobile &&
            enableMobileFilterFab &&
            onFilterChanged != null &&
            filterableFields.isNotEmpty;

        final tableWithMobileFilters = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (shouldShowMobileFilterFab)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
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
          ],
        );

        if (height != null) {
          return SizedBox(
            height: height,
            child: SingleChildScrollView(child: tableWithMobileFilters),
          );
        }
        return tableWithMobileFilters;
      },
    );
  }
}
