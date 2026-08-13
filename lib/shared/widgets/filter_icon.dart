import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/size_config.dart';

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

  List<FilterOption> get _dedupedOptions {
    final seen = <String>{};
    final unique = <FilterOption>[];
    for (final option in widget.options) {
      final key = option.value?.toString() ?? '';
      if (key.isEmpty || seen.add(key)) {
        unique.add(option);
      }
    }
    return unique;
  }

  Future<void> _showFilterDropdown() async {
    final options = _dedupedOptions;

    if (options.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No filter values'),
          content: const Text('There are no values to filter by yet.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    final shouldShowCustom = options.any((option) => option.needsQuery);

    final result = await showDialog<dynamic>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.label),
        content: SizedBox(
          width: SizeConfig.scaleWidth(context, 320),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (shouldShowCustom)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: SizeConfig.scaleHeight(context, 10),
                    ),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(ctx).pop('__custom__');
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Custom query'),
                    ),
                  ),
                if (options.isNotEmpty)
                  Wrap(
                    spacing: SizeConfig.scaleWidth(context, 8),
                    runSpacing: SizeConfig.scaleHeight(context, 8),
                    children: options
                        .map((option) {
                          final isSelected = option.isSelected;
                          return FilterChip(
                            label: Text(option.label),
                            selected: isSelected,
                            onSelected: (_) {
                              Navigator.of(ctx).pop(option.value);
                            },
                          );
                        })
                        .toList(growable: false),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          if (widget.options.any((opt) => opt.isSelected))
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop('__clear__');
              },
              child: const Text('Clear'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (result == null) return;
    if (result == '__clear__') {
      widget.onClear?.call();
      return;
    }
    if (result == '__custom__') {
      final TextEditingController inputController = TextEditingController();
      final customResult = await showDialog<String>(
        context: context,
        builder: (customCtx) => AlertDialog(
          title: const Text('Enter query'),
          content: TextField(
            controller: inputController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Type filter query'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(customCtx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(customCtx).pop(inputController.text.trim()),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (customResult != null && customResult.isNotEmpty) {
        widget.onFilterChanged(customResult);
      }
      return;
    }

    final idx = options.indexWhere((o) => o.value == result);
    if (idx != -1 && options[idx].needsQuery) {
      final TextEditingController inputController = TextEditingController();
      final customResult = await showDialog<String>(
        context: context,
        builder: (customCtx) => AlertDialog(
          title: const Text('Enter query'),
          content: TextField(
            controller: inputController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Type filter query'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(customCtx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(customCtx).pop(inputController.text.trim()),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (customResult != null && customResult.isNotEmpty) {
        widget.onFilterChanged(customResult);
      }
    } else {
      widget.onFilterChanged(result);
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
            size: SizeConfig.iconSize(context, 20),
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
