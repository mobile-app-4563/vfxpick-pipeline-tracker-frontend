/// ─── Content-driven column sizing ─────────────────────────────────────────────
///
/// The production grid used to hard-code a pixel width per column. That breaks
/// as soon as the data changes shape — once `Tasks` started holding
/// `ROTO, PAINT` it no longer fitted the 100px it was given, so the value was
/// clipped.
///
/// Instead every column is measured against its header and the values it
/// actually has to render, then given [gridColumnHorizontalPadding] on both
/// sides so text never touches the cell border. The result is clamped to
/// [gridColumnMinWidth]..[gridColumnMaxWidth], which keeps short numeric columns
/// tappable and stops one long review note from pushing the rest of the grid
/// off-screen.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Narrowest a column may become, so short numeric columns stay readable.
const double gridColumnMinWidth = 100;

/// Widest a column may become before its content wraps instead.
const double gridColumnMaxWidth = 340;

/// Horizontal breathing room added around a column's widest content.
const double gridColumnHorizontalPadding = 16;

/// Headers wrap onto two lines, so a long one is not allowed to stretch its
/// column past this width.
const double gridColumnMaxHeaderWidth = 180;

/// How many of a column's longest values get measured.
///
/// Character count is only a rough proxy for width — `iiii` and `MMMM` have the
/// same length but very different widths — so a few of the longest candidates
/// are measured rather than just one.
const int _sampleSize = 3;

/// Width that fits [label] and the widest of [values], plus horizontal padding.
///
/// Only the longest few entries of [values] are measured, which keeps the cost
/// at one cheap string-length pass per row plus a handful of text layouts per
/// column. Measuring every cell would be far too slow for a full grid.
///
/// Pass the same [minWidth] tuning used elsewhere when a column needs a
/// different floor (e.g. a numeric column can afford to be narrower).
double gridColumnWidth(
  BuildContext context, {
  required String label,
  Iterable<Object?> values = const <Object?>[],
  TextStyle? style,
  double minWidth = gridColumnMinWidth,
  double maxWidth = gridColumnMaxWidth,
  double horizontalPadding = gridColumnHorizontalPadding,
  double maxHeaderWidth = gridColumnMaxHeaderWidth,
}) {
  final direction = Directionality.of(context);
  final scaler = MediaQuery.textScalerOf(context);
  final cellStyle = style ?? DefaultTextStyle.of(context).style;

  // The table renders headers a weight heavier than the cells.
  final headerStyle = cellStyle.copyWith(fontWeight: FontWeight.w600);

  // Headers may wrap over two lines, so cap what they contribute instead of
  // letting "Shots Received Date" dictate a very wide column.
  var widest = math.min(
    _gridTextWidth(label, headerStyle, scaler, direction),
    maxHeaderWidth,
  );

  final longest = <String>[];
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) continue;
    longest.add(text);
    if (longest.length > _sampleSize) {
      longest.sort((a, b) => b.length.compareTo(a.length));
      longest.removeLast();
    }
  }

  for (final text in longest) {
    final width = _gridTextWidth(text, cellStyle, scaler, direction);
    if (width > widest) widest = width;
  }

  return (widest + horizontalPadding).clamp(minWidth, maxWidth);
}

double _gridTextWidth(
  String text,
  TextStyle style,
  TextScaler scaler,
  TextDirection direction,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
