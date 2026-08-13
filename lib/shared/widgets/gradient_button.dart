import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/size_config.dart';

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final double borderRadius;
  final bool isLoading;
  final double? width;
  final double height;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.borderRadius = 8.0,
    this.isLoading = false,
    this.width,
    this.height = 48.0,
    this.icon,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.width != null
            ? SizeConfig.scaleWidth(context, widget.width!)
            : null,
        height: SizeConfig.scaleHeight(context, widget.height),
        transform: _isHovered && !isDisabled
            ? (Matrix4.identity()..scale(1.03))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            SizeConfig.scaleWidth(context, widget.borderRadius),
          ),
          gradient: isDisabled
              ? LinearGradient(
                  colors: [
                    Colors.grey.withOpacity(0.5),
                    Colors.grey.withOpacity(0.3),
                  ],
                )
              : AppColors.brandGradient,
          boxShadow: _isHovered && !isDisabled
              ? [
                  BoxShadow(
                    color: AppColors.brandGreen.withOpacity(0.4),
                    blurRadius: SizeConfig.scaleWidth(context, 12),
                    offset: Offset(0, SizeConfig.scaleHeight(context, 4)),
                  ),
                ]
              : [],
        ),
        child: ElevatedButton(
          onPressed: isDisabled ? null : widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                SizeConfig.scaleWidth(context, widget.borderRadius),
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: SizeConfig.scaleWidth(context, 16),
            ),
          ),
          child: widget.isLoading
              ? SizeConfig.loadingIndicator(size: 20, stroke: 2)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        color: Colors.white,
                        size: SizeConfig.iconSize(context, 18),
                      ),
                      SizeConfig.sizedBoxW(context, 8),
                    ],
                    Text(
                      widget.text,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: SizeConfig.fontSize(context, 15),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
