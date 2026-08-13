import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/todays_pickout_model.dart';
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: isDark ? AppColors.darkCardFill : AppColors.lightCardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          width: 1,
        ),
      ),
      child: GestureDetector(
        onTap: onTap ?? () => _showChatDialog(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Priority badge
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
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
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: priorityColor,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            pickout.priorityLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: priorityColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Row 2: Show + Department
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            pickout.shot.showName ?? 'N/A',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            pickout.shot.department,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.brandGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Row 3: Priority reason + Due Date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          pickout.priorityReason,
                          style: TextStyle(
                            fontSize: 11,
                            color: priorityColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Text(
                          'Due: ${_formatDate(pickout.shot.dueDate)}',
                          style: TextStyle(
                            fontSize: 10,
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
              const SizedBox(width: 12),
              // Chat icon
              GestureDetector(
                onTap: () => _showChatDialog(context),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 20,
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
