import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/production_concern_model.dart';
import '../../core/utils/size_config.dart';
import 'gradient_box_border.dart';

/// ProductionPickoutWidget displays a production concern card with the same
/// priority highlighting used by [TodaysPickoutWidget] for shot pickouts.
class ProductionPickoutWidget extends StatelessWidget {
  final ProductionConcernModel concern;
  final VoidCallback? onTap; // Custom action when the card is tapped

  const ProductionPickoutWidget({super.key, required this.concern, this.onTap});

  /// Get color based on priority rank (same mapping as shot pickouts)
  Color _getPriorityColor() {
    switch (concern.priorityRank) {
      case 1:
        return AppColors.priorityCritical; // Deep red for critical
      case 2:
        return AppColors.priorityHigh; // Red for high
      case 3:
        return AppColors.priorityMedium; // Amber for medium
      default:
        return AppColors.priorityLow; // Blue for low
    }
  }

  /// Get color based on concern status
  Color _getStatusColor() {
    switch (concern.status.toLowerCase()) {
      case 'open':
        return Colors.blue;
      case 'in progress':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'on hold':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  /// Format date for display
  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Show/shot reference shown under the concern type
  String get _reference {
    final shotId = concern.shotId;
    if (shotId != null && shotId.isNotEmpty) {
      return 'Shot: $shotId';
    }
    return 'Show: ${concern.showId}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = _getPriorityColor();
    final statusColor = _getStatusColor();

    return Card(
      margin: SizeConfig.paddingSymmetric(context, horizontal: 16, vertical: 8),
      elevation: 0,
      color: isDark ? AppColors.darkCardFill : AppColors.lightCardFill,
      shape: GradientBoxBorder(
        gradient: AppColors.brandGradient,
        width: SizeConfig.scaleWidth(context, 1),
        borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 8)),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 12)),
          child: Row(
            children: [
              // Priority badge
              Container(
                width: SizeConfig.scaleWidth(context, 4),
                height: SizeConfig.scaleHeight(context, 76),
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(
                    SizeConfig.scaleWidth(context, 2),
                  ),
                ),
              ),
              SizeConfig.sizedBoxW(context, 12),
              // Concern details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Concern type + Priority label
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            concern.concernType ?? 'Concern',
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(context, 14),
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: SizeConfig.paddingSymmetric(
                            context,
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(
                              SizeConfig.scaleWidth(context, 4),
                            ),
                            border: Border.all(
                              color: priorityColor,
                              width: SizeConfig.scaleWidth(context, 0.5),
                            ),
                          ),
                          child: Text(
                            concern.priorityLabel,
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(context, 10),
                              fontWeight: FontWeight.bold,
                              color: priorityColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(context, 2)),
                    // Row 2: Description
                    Text(
                      concern.concernDescription ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SizeConfig.fontSize(context, 11),
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(context, 4)),
                    // Row 3: Reference + Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _reference,
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(context, 12),
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizeConfig.sizedBoxW(context, 8),
                        Container(
                          padding: SizeConfig.paddingSymmetric(
                            context,
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              SizeConfig.scaleWidth(context, 3),
                            ),
                          ),
                          child: Text(
                            concern.status,
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(context, 10),
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(context, 4)),
                    // Row 4: Priority reason + Due date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          concern.priorityReason,
                          style: TextStyle(
                            fontSize: SizeConfig.fontSize(context, 11),
                            color: priorityColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Text(
                          'Due: ${_formatDate(concern.dueDate)}',
                          style: TextStyle(
                            fontSize: SizeConfig.fontSize(context, 10),
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
