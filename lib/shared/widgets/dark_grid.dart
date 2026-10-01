import 'package:flutter/material.dart';

/// Uniform dark grid styling used by every data grid in the app.
///
/// The app is dark-only (there is no light/white theme switch any more), so
/// grids render directly on the surrounding dark surface. Every column header
/// and every data cell label is forced to pure white, and the header text is
/// centred in its column.
///
/// The surface colours are transparent so whatever dark background the grid
/// sits on (e.g. a `GlassContainer`) shows through, instead of the grid
/// painting its own sheet colour.
ThemeData darkGridTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      surface: Colors.transparent,
      surfaceContainerHighest: Colors.transparent,
      onSurface: Colors.white,
      onSurfaceVariant: Colors.white,
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      dataRowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      headingRowAlignment: MainAxisAlignment.center,
      headingTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      dataTextStyle: const TextStyle(color: Colors.white),
    ),
  );
}

/// Convenience wrapper around [darkGridTheme] — drop it around a grid so every
/// header and cell renders with white text on the dark theme.
class DarkGrid extends StatelessWidget {
  /// The grid (or grid area) to render on the dark theme.
  final Widget child;

  const DarkGrid({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Theme(data: darkGridTheme(context), child: child);
}

/// A [DataTable] whose heading row and data rows share the same transparent
/// (dark) background with white, centred content — the drop-in replacement for
/// screens that build a Material [DataTable] directly (instead of using
/// `DynamicDataTable`).
class DarkDataTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final double? dataRowMinHeight;
  final double? dataRowMaxHeight;
  final double? columnSpacing;
  final TableBorder? border;

  const DarkDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.dataRowMinHeight,
    this.dataRowMaxHeight,
    this.columnSpacing,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return DarkGrid(
      child: DataTable(
        headingRowColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        dataRowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        dataRowMinHeight: dataRowMinHeight ?? kMinInteractiveDimension,
        dataRowMaxHeight: dataRowMaxHeight ?? kMinInteractiveDimension,
        columnSpacing: columnSpacing ?? 56.0,
        border: border,
        columns: columns,
        rows: rows,
      ),
    );
  }
}
