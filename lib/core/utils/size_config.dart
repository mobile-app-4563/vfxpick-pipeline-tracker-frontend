import 'package:flutter/material.dart';

/// Centralized responsive sizing utility using MediaQuery.
///
/// All dimensions (padding, font sizes, icon sizes, widths, heights, etc.)
/// should be derived through this class to ensure a consistent responsive
/// layout across devices (mobile, tablet, desktop).
class SizeConfig {
  SizeConfig._();

  // ─── Breakpoints ───────────────────────────────────────────────────────────
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  // ─── Screen info helpers ───────────────────────────────────────────────────
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static double viewInsetsBottom(BuildContext context) =>
      MediaQuery.of(context).viewInsets.bottom;

  // ─── Device type checks ────────────────────────────────────────────────────
  static bool isMobile(BuildContext context) =>
      screenWidth(context) < mobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      screenWidth(context) >= mobileBreakpoint &&
      screenWidth(context) < tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      screenWidth(context) >= tabletBreakpoint;

  // ─── Responsive width / height (percentage-based) ──────────────────────────
  /// Returns a percentage of the screen width.
  static double width(BuildContext context, double percent) =>
      screenWidth(context) * percent;

  /// Returns a percentage of the screen height.
  static double height(BuildContext context, double percent) =>
      screenHeight(context) * percent;

  // ─── Scale a value relative to a reference width (1366 px) ─────────────────
  /// Scales a value proportionally to the screen width.
  static double scaleWidth(BuildContext context, double value) =>
      value * (screenWidth(context) / 1366);

  /// Scales a value proportionally to the screen height.
  static double scaleHeight(BuildContext context, double value) =>
      value * (screenHeight(context) / 768);

  // ─── Font sizing ───────────────────────────────────────────────────────────
  /// Returns a responsive font size that scales with screen width.
  static double fontSize(BuildContext context, double base) {
    final width = screenWidth(context);
    if (width < mobileBreakpoint) return base * 0.85;
    if (width < tabletBreakpoint) return base * 0.92;
    if (width > desktopBreakpoint) return base * 1.08;
    return base;
  }

  // ─── Padding / Margin ──────────────────────────────────────────────────────
  /// Responsive symmetric padding – scales with screen.
  static EdgeInsets paddingAll(BuildContext context, double value) =>
      EdgeInsets.all(scaleWidth(context, value));

  static EdgeInsets paddingSymmetric(
    BuildContext context, {
    double horizontal = 0,
    double vertical = 0,
  }) => EdgeInsets.symmetric(
    horizontal: scaleWidth(context, horizontal),
    vertical: scaleHeight(context, vertical),
  );

  static EdgeInsets paddingOnly(
    BuildContext context, {
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) => EdgeInsets.only(
    left: scaleWidth(context, left),
    top: scaleHeight(context, top),
    right: scaleWidth(context, right),
    bottom: scaleHeight(context, bottom),
  );

  // ─── Fixed-size widget helpers ────────────────────────────────────────────
  /// Responsive SizedBox with width.
  static Widget sizedBoxW(BuildContext context, double value) =>
      SizedBox(width: scaleWidth(context, value));

  /// Responsive SizedBox with height.
  static Widget sizedBoxH(BuildContext context, double value) =>
      SizedBox(height: scaleHeight(context, value));

  /// Responsive circular progress indicator size.
  static Widget loadingIndicator({double size = 20, double stroke = 2}) =>
      SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(strokeWidth: stroke),
      );

  // ─── Button sizing ─────────────────────────────────────────────────────────
  /// A responsive fixed Size for buttons.
  static Size buttonFixedSize(BuildContext context, double w, double h) =>
      Size(scaleWidth(context, w), scaleHeight(context, h));

  // ─── Border radius ─────────────────────────────────────────────────────────
  static BorderRadiusGeometry borderRadius(
    BuildContext context,
    double radius,
  ) => BorderRadius.circular(scaleWidth(context, radius));

  // ─── Icon sizing ───────────────────────────────────────────────────────────
  static double iconSize(BuildContext context, double base) =>
      scaleWidth(context, base);

  // ─── Clamped sizing (between min and max) ──────────────────────────────────
  static double clamped(
    BuildContext context,
    double base, {
    double? min,
    double? max,
  }) {
    final scaled = scaleWidth(context, base);
    if (min != null && scaled < min) return min;
    if (max != null && scaled > max) return max;
    return scaled;
  }

  // ─── Dynamic value based on device type ────────────────────────────────────
  static T deviceValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return desktop;
  }

  // ─── Content max-width constraint ──────────────────────────────────────────
  static double maxContentWidth(BuildContext context) =>
      deviceValue(context, mobile: double.infinity, desktop: 1200);

  // ─── Cross-axis count for grids ────────────────────────────────────────────
  static int gridColumns(
    BuildContext context, {
    int? mobileCols,
    int? tabletCols,
    int? desktopCols,
  }) {
    if (isMobile(context)) return mobileCols ?? 1;
    if (isTablet(context)) return tabletCols ?? 2;
    return desktopCols ?? 4;
  }

  // ─── Responsive padding for table / card content ──────────────────────────
  static EdgeInsets contentPadding(BuildContext context) =>
      EdgeInsets.symmetric(
        horizontal: scaleWidth(context, 16),
        vertical: scaleHeight(context, 12),
      );
}
