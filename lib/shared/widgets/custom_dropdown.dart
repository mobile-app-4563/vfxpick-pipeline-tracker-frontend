import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/size_config.dart';

class CustomDropdown<T> extends StatefulWidget {
  final T? value;
  final List<T> items;
  final String labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final String? Function(T?)? validator;
  final void Function(T?)? onChanged;
  final String Function(T) itemToString;
  final bool compact;

  const CustomDropdown({
    super.key,
    required this.labelText,
    required this.items,
    required this.onChanged,
    required this.itemToString,
    this.value,
    this.hintText,
    this.prefixIcon,
    this.validator,
    this.compact = false,
  });

  @override
  State<CustomDropdown<T>> createState() => _CustomDropdownState<T>();
}

class _CustomDropdownState<T> extends State<CustomDropdown<T>> {
  T? _selectedValue;

  /// Returns the value that is guaranteed to be in [items], or null.
  T? get _safeValue {
    if (_selectedValue == null) return null;
    if (widget.items.contains(_selectedValue)) return _selectedValue;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant CustomDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _selectedValue = widget.value;
    }
  }

  InputDecoration _decoration(BuildContext context, bool isDark, bool compact) {
    return InputDecoration(
      hintText: widget.hintText,
      hintStyle: TextStyle(
        color: isDark
            ? AppColors.darkTextSecondary.withOpacity(0.5)
            : AppColors.lightTextSecondary.withOpacity(0.5),
        fontSize: SizeConfig.fontSize(context, compact ? 12 : 14),
      ),
      contentPadding: SizeConfig.paddingSymmetric(
        context,
        horizontal: compact ? 8 : 16,
        vertical: compact ? 10 : 14,
      ),
      prefixIcon: widget.prefixIcon != null
          ? Icon(
              widget.prefixIcon,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              size: SizeConfig.iconSize(context, 20),
            )
          : null,
      filled: true,
      fillColor: isDark
          ? Colors.white.withOpacity(0.03)
          : Colors.black.withOpacity(0.02),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 3)),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          width: SizeConfig.scaleWidth(context, 1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          SizeConfig.scaleWidth(context, compact ? 4 : 8),
        ),
        borderSide: const BorderSide(color: AppColors.brandGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          SizeConfig.scaleWidth(context, compact ? 4 : 8),
        ),
        borderSide: const BorderSide(color: AppColors.priorityHigh, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          SizeConfig.scaleWidth(context, compact ? 4 : 8),
        ),
        borderSide: BorderSide(
          color: AppColors.priorityHigh,
          width: SizeConfig.scaleWidth(context, 1.5),
        ),
      ),
    );
  }

  List<DropdownMenuItem<T>> _buildItems(
    BuildContext context,
    bool isDark,
    bool compact,
  ) {
    return widget.items.map((T item) {
      return DropdownMenuItem<T>(
        value: item,
        child: Text(
          widget.itemToString(item),
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
            fontSize: SizeConfig.fontSize(context, compact ? 12 : 14),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dropdown = DropdownButtonFormField<T>(
      value: _safeValue,
      items: _buildItems(context, isDark, widget.compact),
      onChanged: (T? newValue) {
        setState(() => _selectedValue = newValue);
        widget.onChanged?.call(newValue);
      },
      validator: widget.validator,
      style: TextStyle(
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        fontSize: SizeConfig.fontSize(context, widget.compact ? 12 : 14),
      ),
      dropdownColor: isDark ? AppColors.darkBg : Colors.white,
      decoration: _decoration(context, isDark, widget.compact),
    );

    if (widget.compact) return dropdown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.labelText,
          style: TextStyle(
            fontSize: SizeConfig.fontSize(context, 13),
            fontWeight: FontWeight.bold,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        SizedBox(height: SizeConfig.scaleHeight(context, 6)),
        dropdown,
      ],
    );
  }
}
