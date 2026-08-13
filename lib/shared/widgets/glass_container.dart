import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/size_config.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final BoxBorder? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 0,
    this.blur = 12.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.alignment,
    this.border,
  });

  /// Creates a [GlassContainer] with responsive border radius.
  factory GlassContainer.responsive({
    Key? key,
    required BuildContext context,
    required Widget child,
    double borderRadius = 0,
    double blur = 12,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? width,
    double? height,
    AlignmentGeometry? alignment,
    BoxBorder? border,
  }) {
    return GlassContainer(
      key: key,
      borderRadius: SizeConfig.scaleWidth(context, 0),
      blur: blur,
      padding: padding,
      margin: margin,
      width: width != null ? SizeConfig.scaleWidth(context, width) : null,
      height: height != null ? SizeConfig.scaleHeight(context, height) : null,
      alignment: alignment,
      border: border,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = SizeConfig.scaleWidth(context, borderRadius);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          margin: margin,
          alignment: alignment,
          decoration: AppTheme.glassDecoration(
            isDark: isDark,
            borderRadius: radius,
            blur: blur,
            border: border,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ),
        ),
      ),
    );
  }
}
