import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/size_config.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Wrap(
        direction: Axis.vertical,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 8)),
            child: Container(
              padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 20)),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.02)
                    : Colors.black.withOpacity(0.02),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? AppColors.darkCardBorder
                      : AppColors.lightCardBorder,
                ),
              ),
              child: Icon(
                icon,
                size: SizeConfig.iconSize(context, 24),
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 5)),
          Text(
            title,
            style: TextStyle(
              fontSize: SizeConfig.fontSize(context, 14),
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 8)),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: SizeConfig.fontSize(context, 14),
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          if (actionLabel != null && onActionPressed != null) ...[
            SizedBox(height: SizeConfig.scaleHeight(context, 20)),
            ElevatedButton(
              onPressed: onActionPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    SizeConfig.scaleWidth(context, 8),
                  ),
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
