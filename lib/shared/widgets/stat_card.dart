import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/size_config.dart';
import 'glass_container.dart';

class StatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? trend;
  final bool isTrendPositive;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor = AppColors.brandGreen,
    this.trend,
    this.isTrendPositive = true,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovered
            ? (Matrix4.identity()..translate(0, -6, 0))
            : Matrix4.identity(),
        child: GlassContainer(
          padding: SizeConfig.paddingAll(context, 20),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 12)),
                decoration: BoxDecoration(
                  color: widget.iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.iconColor.withOpacity(0.3),
                    width: SizeConfig.scaleWidth(context, 1.5),
                  ),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.iconColor,
                  size: SizeConfig.iconSize(context, 26),
                ),
              ),
              SizeConfig.sizedBoxW(context, 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: SizeConfig.fontSize(context, 13),
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(context, 6)),
                    Text(
                      widget.value,
                      style: TextStyle(
                        fontSize: SizeConfig.fontSize(context, 26),
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (widget.trend != null) ...[
                      SizedBox(height: SizeConfig.scaleHeight(context, 4)),
                      Row(
                        children: [
                          Icon(
                            widget.isTrendPositive
                                ? Icons.trending_up
                                : Icons.trending_down,
                            size: SizeConfig.iconSize(context, 14),
                            color: widget.isTrendPositive
                                ? Colors.green
                                : Colors.red,
                          ),
                          SizeConfig.sizedBoxW(context, 4),
                          Text(
                            widget.trend!,
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(context, 12),
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
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
