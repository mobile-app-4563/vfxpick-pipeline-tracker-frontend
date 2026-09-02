import 'package:flutter/material.dart';

import '../../core/utils/excel_date_utils.dart';
import '../../core/utils/size_config.dart';
import 'custom_dropdown.dart';

/// Short month names used to render date cells as "Aug 20" (no year).
const List<String> _monthAbbreviations = [
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

/// A single editable grid cell (shared by Production Management and Projects).
///
/// Displays the value normally; on double-click it swaps to an editor:
///  - [options] != null  → a compact dropdown (used by Status / Complexity)
///  - [isDate]           → opens a date picker dialog directly
///  - otherwise          → a compact [TextField]
/// Commits on Enter/focus-loss (text), selection (dropdown) or pick (date),
/// and highlights while dirty (pending sync).
///
/// The tooltip ("Double-click to edit" / "Double-click to pick date") is
/// intentionally excluded from the semantics tree so a cell always reads as
/// its value only.
class GridEditableCell extends StatefulWidget {
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

  const GridEditableCell({
    super.key,
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
  State<GridEditableCell> createState() => _GridEditableCellState();
}

class _GridEditableCellState extends State<GridEditableCell> {
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

  /// Text shown in the cell when not editing. Month-level dates (day == 1,
  /// i.e. the Excel template's `mmm-yy` cells) render as "May-25" exactly
  /// like Excel shows them; genuine day-level dates render as "Aug 20"
  /// (month + day, no year). The raw ISO value is kept in [_initialText] so
  /// double-click editing (date picker) still works from the full date.
  String get _displayText {
    final value = widget.displayValue;
    if (value == null) return '-';
    final text = value.toString().trim();
    if (text.isEmpty) return '-';
    if (widget.isDate) {
      final d = DateTime.tryParse(text);
      if (d != null) {
        if (d.day == 1) return monthYearLabel(d); // "May-25" like Excel
        return '${_monthAbbreviations[d.month - 1]} ${d.day}';
      }
    }
    return text;
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
    // Date cells skip the normal onStartEdit path (double-tap opens the
    // picker directly), so mark the cell as editing now.  Hosts like Projects
    // guard commits on the editing key; without this the guard fails and the
    // picked date is silently dropped.  onCommit clears the key afterwards.
    widget.onStartEdit();
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
  void didUpdateWidget(covariant GridEditableCell oldWidget) {
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
            _displayText,
            textAlign: TextAlign.center,
            // Wrap instead of overflowing: long values stay inside their
            // column and the table row grows in height to fit them, so cell
            // text never overlaps the neighboring cells. No maxLines — the
            // full value always stays visible.
            softWrap: true,
            overflow: TextOverflow.clip,
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
