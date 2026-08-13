import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// DateRangePicker provides a user-friendly interface for selecting date ranges.
/// Wraps Flutter's showDateRangePicker and provides styling consistent with the app theme.
class DateRangePicker extends StatefulWidget {
  final DateTimeRange? initialDateRange;
  final void Function(DateTimeRange?)
  onDateRangeChanged; // Callback when date range is selected
  final DateTime? firstDate; // Earliest selectable date
  final DateTime? lastDate; // Latest selectable date
  final String? hintText; // Hint text to display
  final String? labelText; // Label for the field
  final EdgeInsets padding;

  const DateRangePicker({
    super.key,
    this.initialDateRange,
    required this.onDateRangeChanged,
    this.firstDate,
    this.lastDate,
    this.hintText,
    this.labelText = 'Select Date Range',
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  State<DateRangePicker> createState() => _DateRangePickerState();
}

class _DateRangePickerState extends State<DateRangePicker> {
  late DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _selectedDateRange = widget.initialDateRange;
  }

  String _formatDateRange(DateTimeRange? range) {
    if (range == null) {
      return widget.hintText ?? 'Select date range...';
    }
    final start = '${range.start.day}/${range.start.month}/${range.start.year}';
    final end = '${range.end.day}/${range.end.month}/${range.end.year}';
    return '$start - $end';
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final firstDate = widget.firstDate ?? DateTime(now.year - 5);
    final lastDate = widget.lastDate ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: _selectedDateRange,
      builder: (BuildContext context, Widget? child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.brandGreen,
              surface: isDark
                  ? AppColors.darkCardFill
                  : AppColors.lightCardFill,
              onSurface: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      widget.onDateRangeChanged(picked);
    }
  }

  void _clearDateRange() {
    setState(() => _selectedDateRange = null);
    widget.onDateRangeChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.labelText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                widget.labelText!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ),
          GestureDetector(
            onTap: _selectDateRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark
                      ? AppColors.darkCardBorder
                      : AppColors.lightCardBorder,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color: isDark
                    ? AppColors.darkCardFill
                    : AppColors.lightCardFill,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _formatDateRange(_selectedDateRange),
                      style: TextStyle(
                        fontSize: 13,
                        color: _selectedDateRange != null
                            ? (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary)
                            : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: AppColors.brandGreen,
                  ),
                ],
              ),
            ),
          ),
          if (_selectedDateRange != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _clearDateRange,
                  icon: Icon(
                    Icons.clear,
                    size: 16,
                    color: AppColors.brandGreen,
                  ),
                  label: Text(
                    'Clear',
                    style: TextStyle(fontSize: 12, color: AppColors.brandGreen),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
