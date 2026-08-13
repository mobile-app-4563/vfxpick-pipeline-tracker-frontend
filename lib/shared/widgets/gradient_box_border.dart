import 'package:flutter/material.dart';

/// A [BoxBorder] that paints its edges using a [Gradient] shader.
///
/// This is a lightweight stand-in for the (currently unavailable) framework
/// `GradientBoxBorder`. It supports rounded rectangles and circles and can be
/// used anywhere a [BoxBorder] or [ShapeBorder] is accepted:
///
/// ```dart
/// BoxDecoration(border: GradientBoxBorder(gradient: myGradient, width: 1.5))
/// Card(shape: GradientBoxBorder(gradient: myGradient, width: 1))
/// AlertDialog(shape: GradientBoxBorder(gradient: myGradient, width: 2))
/// ```
class GradientBoxBorder extends BoxBorder {
  const GradientBoxBorder({
    required this.gradient,
    this.width = 1.0,
    this.borderRadius,
  });

  /// The gradient used to paint all four sides of the border.
  final Gradient gradient;

  /// The width of the border in logical pixels.
  final double width;

  /// The corner radius used when no [borderRadius] is provided to [paint]
  /// (e.g. when used as a [ShapeBorder] on a [Card] or [AlertDialog]).
  final BorderRadius? borderRadius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  bool get isUniform => true;

  @override
  BorderSide get top => BorderSide(width: width);

  @override
  BorderSide get bottom => BorderSide(width: width);

  @override
  GradientBoxBorder scale(double t) {
    return GradientBoxBorder(
      gradient: gradient,
      width: width * t,
      borderRadius: borderRadius,
    );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final radius = (borderRadius ?? BorderRadius.zero)
        .resolve(textDirection)
        .toRRect(rect);
    return Path()..addRRect(radius);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final radius = (borderRadius ?? BorderRadius.zero)
        .resolve(textDirection)
        .toRRect(rect)
        .deflate(width);
    return Path()..addRRect(radius);
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final paint = Paint()..shader = gradient.createShader(rect);

    if (shape == BoxShape.circle) {
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(rect.shortestSide / 2),
      );
      canvas.drawDRRect(rrect, rrect.deflate(width), paint);
      return;
    }

    final rrect = (borderRadius ?? this.borderRadius ?? BorderRadius.zero)
        .resolve(textDirection)
        .toRRect(rect);
    canvas.drawDRRect(rrect, rrect.deflate(width), paint);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GradientBoxBorder &&
        other.gradient == gradient &&
        other.width == width &&
        other.borderRadius == borderRadius;
  }

  @override
  int get hashCode => Object.hash(gradient, width, borderRadius);

  @override
  String toString() {
    return 'GradientBoxBorder(gradient: $gradient, width: $width, '
        'borderRadius: $borderRadius)';
  }
}
