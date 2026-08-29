import 'package:flutter/material.dart';
import '../../core/utils/size_config.dart';

/// Type-aware cell comparator used by grid sorting across the app.
///
/// Handles numbers (including comma-separated thousands), ISO dates, and
/// falls back to a case-insensitive string comparison. Nulls sort first in
/// ascending order.
int compareCellValues(dynamic a, dynamic b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  if (a is num && b is num) return a.compareTo(b);
  if (a is DateTime && b is DateTime) return a.compareTo(b);
  final sa = a.toString().trim();
  final sb = b.toString().trim();
  if (sa.isEmpty && sb.isEmpty) return 0;
  if (sa.isEmpty) return -1;
  if (sb.isEmpty) return 1;
  final na = num.tryParse(sa.replaceAll(',', ''));
  final nb = num.tryParse(sb.replaceAll(',', ''));
  if (na != null && nb != null) return na.compareTo(nb);
  final da = DateTime.tryParse(sa);
  final db = DateTime.tryParse(sb);
  if (da != null && db != null) return da.compareTo(db);
  return sa.toLowerCase().compareTo(sb.toLowerCase());
}

/// Tappable grid column header showing a sort arrow on every column.
///
/// Tapping toggles ascending / descending. The active sorted column shows a
/// filled up/down arrow in the theme primary color; every other column shows
/// a neutral unfold-more affordance so it is obvious each column is sortable.
class SortableHeader extends StatelessWidget {
  final String label;
  final bool isSorted;
  final bool sortAscending;
  final VoidCallback onTap;
  final TextStyle? style;
  final bool center;
  final bool wrap;
  final double iconSize;

  const SortableHeader({
    super.key,
    required this.label,
    required this.isSorted,
    required this.sortAscending,
    required this.onTap,
    this.style,
    this.center = false,
    this.wrap = false,
    this.iconSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = isSorted
        ? (sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
        : Icons.unfold_more;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: center
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                label,
                textAlign: center ? TextAlign.center : TextAlign.start,
                softWrap: wrap,
                overflow: TextOverflow.visible,
                style: style,
              ),
            ),
            SizedBox(width: SizeConfig.scaleWidth(context, 3)),
            Icon(
              icon,
              size: SizeConfig.iconSize(context, iconSize),
              color: isSorted ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
