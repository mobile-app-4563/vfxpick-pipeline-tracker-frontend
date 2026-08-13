import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/size_config.dart';
import '../../core/models/todays_pickout_model.dart';
import 'gradient_box_border.dart';
import 'shot_chat_dialog.dart';

/// TodaysPickoutWidget displays a shot card with priority highlighting.
/// Tapping the card opens a shot chat dialog or navigation action.
class TodaysPickoutWidget extends StatelessWidget {
  final TodaysPickoutModel pickout;
  final void Function()? onTap; // Custom action instead of default chat dialog
  final void Function()? onTapChat; // Action when chat icon is tapped

  const TodaysPickoutWidget({
    super.key,
    required this.pickout,
    this.onTap,
    this.onTapChat,
  });

  /// Get color based on priority rank
  Color _getPriorityColor() {
    switch (pickout.priorityRank) {
      case 1:
        return AppColors.priorityCritical; // Red for critical
      case 2:
        return AppColors.priorityHigh; // Orange for high
      case 3:
        return AppColors.priorityMedium; // Amber for medium
      default:
        return AppColors.priorityLow; // Blue for low
    }
  }

  /// Format date for display
  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ShotChatDialog(
        shotId: pickout.shot.shotId,
        shotCode: pickout.shot.shotCode,
      ),
    );
    onTapChat?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = _getPriorityColor();

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
        onTap: onTap ?? () => _showChatDialog(context),
        child: Container(
          padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 12)),
          child: Row(
            children: [
              // Priority badge
              Container(
                width: SizeConfig.scaleWidth(context, 4),
                height: SizeConfig.scaleHeight(context, 60),
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(
                    SizeConfig.scaleWidth(context, 2),
                  ),
                ),
              ),
              SizeConfig.sizedBoxW(context, 12),
              // Shot details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Shot Code + Priority
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            pickout.shot.shotCode,
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
                            pickout.priorityLabel,
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(context, 10),
                              fontWeight: FontWeight.bold,
                              color: priorityColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(context, 4)),
                    // Row 2: Show + Department
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            pickout.shot.showName ?? 'N/A',
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
                            color: AppColors.brandGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              SizeConfig.scaleWidth(context, 3),
                            ),
                          ),
                          child: Text(
                            pickout.shot.department,
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(context, 10),
                              fontWeight: FontWeight.w500,
                              color: AppColors.brandGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(context, 4)),
                    // Row 3: Priority reason + Due Date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          pickout.priorityReason,
                          style: TextStyle(
                            fontSize: SizeConfig.fontSize(context, 11),
                            color: priorityColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Text(
                          'Due: ${_formatDate(pickout.shot.dueDate)}',
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
              SizeConfig.sizedBoxW(context, 12),
              // Chat icon
              GestureDetector(
                onTap: () => _showChatDialog(context),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: SizeConfig.iconSize(context, 20),
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
