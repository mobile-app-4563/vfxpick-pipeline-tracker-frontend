import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// FilterOption represents a single filterable item in the dropdown
class FilterOption {
  final String label;
  final dynamic value;
  final bool isSelected;
  final bool needsQuery;

  const FilterOption({
    required this.label,
    required this.value,
    this.isSelected = false,
    this.needsQuery = false,
  });
}

/// FilterIcon displays a filter icon button that opens a dropdown menu.
/// Clicking an option calls onFilterChanged with the selected value(s).
class FilterIcon extends StatefulWidget {
  final String label; // Label shown above/beside the icon
  final List<FilterOption> options; // Available filter options
  final void Function(dynamic value)
  onFilterChanged; // Callback when filter is selected
  final void Function()? onClear; // Optional: callback to clear the filter
  final IconData icon; // Icon to display (default: Icons.filter_list)
  final Color?
  activeColor; // Color when filter is active (default: brand green)
  final EdgeInsets padding; // Padding around the icon button

  const FilterIcon({
    super.key,
    required this.label,
    required this.options,
    required this.onFilterChanged,
    this.onClear,
    this.icon = Icons.filter_list,
    this.activeColor,
    this.padding = const EdgeInsets.all(8),
  });

  @override
  State<FilterIcon> createState() => _FilterIconState();
}

class _FilterIconState extends State<FilterIcon> {
  final GlobalKey<State<Tooltip>> _tooltipKey = GlobalKey<State<Tooltip>>();

  Future<void> _showFilterDropdown() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    // Directly prompt when there is only a custom query filter option.
    if (widget.options.length == 1 && widget.options.first.needsQuery) {
      final TextEditingController inputController = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enter query'),
          content: TextField(
            controller: inputController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Type filter query'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(inputController.text.trim()),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (result != null && result.isNotEmpty) {
        widget.onFilterChanged(result);
      }
      return;
    }

    // Create dropdown items
    List<PopupMenuEntry<dynamic>> menuItems = [
      // Clear button if any option is selected
      if (widget.options.any((opt) => opt.isSelected))
        PopupMenuItem(
          value: '__clear__',
          child: Row(
            children: [
              Icon(Icons.clear, size: 18, color: AppColors.brandGreen),
              const SizedBox(width: 12),
              const Text('Clear Filter', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      // Divider if there are selected items
      if (widget.options.any((opt) => opt.isSelected)) const PopupMenuDivider(),
      // Filter options
      ...widget.options.map(
        (option) => PopupMenuItem(
          value: option.value,
          child: Row(
            children: [
              if (option.isSelected)
                Icon(Icons.check, size: 18, color: AppColors.brandGreen)
              else
                const SizedBox(width: 18),
              const SizedBox(width: 12),
              Text(
                option.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: option.isSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: option.isSelected
                      ? AppColors.brandGreen
                      : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    ];

    final value = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx + renderBox.size.width - 200,
        position.dy + renderBox.size.height + 8,
        position.dx + 20,
        0,
      ),
      items: menuItems,
    );
    if (!mounted) return;
    if (value != null) {
      if (value == '__clear__') {
        widget.onClear?.call();
      } else {
        final idx = widget.options.indexWhere((o) => o.value == value);
        if (idx != -1 && widget.options[idx].needsQuery) {
          final TextEditingController inputController =
              TextEditingController();
          final result = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Enter query'),
              content: TextField(
                controller: inputController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Type filter query',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(inputController.text.trim()),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          if (!mounted) return;
          if (result != null && result.isNotEmpty) {
            widget.onFilterChanged(result);
          }
        } else {
          widget.onFilterChanged(value);
        }
      }
    }
  }

  bool get _hasActiveFilter => widget.options.any((opt) => opt.isSelected);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = widget.activeColor ?? AppColors.brandGreen;

    return Tooltip(
      key: _tooltipKey,
      message: widget.label,
      child: Padding(
        padding: widget.padding,
        child: IconButton(
          icon: Icon(
            widget.icon,
            color: _hasActiveFilter
                ? activeColor
                : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
            size: 20,
          ),
          onPressed: () {
            _showFilterDropdown();
          },
          tooltip: '',
        ),
      ),
    );
  }
}
