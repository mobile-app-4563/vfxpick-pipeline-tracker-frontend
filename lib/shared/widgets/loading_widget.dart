import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class LoadingWidget extends StatefulWidget {
  final String? message;

  const LoadingWidget({super.key, this.message});

  @override
  State<LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? AppColors.darkCardBorder.withValues(alpha: 0.35)
        : AppColors.lightCardBorder.withValues(alpha: 0.75);
    final highlightColor = isDark
        ? AppColors.darkTextSecondary.withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.8);

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (bounds) {
                  final dx =
                      (bounds.width * 2) * _controller.value - bounds.width;
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [baseColor, highlightColor, baseColor],
                    stops: const [0.1, 0.5, 0.9],
                    transform: _SlideGradientTransform(translateX: dx),
                  ).createShader(bounds);
                },
                child: Column(
                  children: [
                    _bar(width: 220, height: 14, color: baseColor),
                    const SizedBox(height: 10),
                    _bar(width: 170, height: 14, color: baseColor),
                    const SizedBox(height: 10),
                    _bar(width: 250, height: 14, color: baseColor),
                  ],
                ),
              ),
              if (widget.message != null) ...[
                const SizedBox(height: 16),
                Text(
                  widget.message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _bar({
    required double width,
    required double height,
    required Color color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  final double translateX;

  const _SlideGradientTransform({required this.translateX});

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(translateX, 0, 0);
  }
}
