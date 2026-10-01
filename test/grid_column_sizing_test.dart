import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vfxpick_pipeline/modules/production_management/utils/grid_column_sizing.dart';

/// Width of [text] as actually painted, used to check the sizing rule really
/// does fit the content rather than merely being proportional to it.
double _paintedWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// Runs [body] against a real [BuildContext] so directionality and the text
/// scaler resolve exactly as they do in the app.
Future<T> _withContext<T>(
  WidgetTester tester,
  T Function(BuildContext context) body,
) async {
  late T result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          result = body(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return result;
}

void main() {
  const style = TextStyle(fontSize: 12);

  group('gridColumnWidth', () {
    testWidgets('fits the widest value plus horizontal padding', (
      tester,
    ) async {
      const widest = 'BLACKBIRD_0120_comp_v003';
      final width = await _withContext(
        tester,
        (context) => gridColumnWidth(
          context,
          label: 'Shot ID',
          values: const [widest, 'A', 'BB'],
          style: style,
        ),
      );

      expect(
        width,
        moreOrLessEquals(
          _paintedWidth(widest, style) + gridColumnHorizontalPadding,
          epsilon: 0.5,
        ),
      );
    });

    testWidgets('grows as the content gets longer', (tester) async {
      final (short, long) = await _withContext(tester, (context) {
        return (
          gridColumnWidth(
            context,
            label: 'Tasks',
            values: const ['MM'],
            style: style,
          ),
          gridColumnWidth(
            context,
            label: 'Tasks',
            values: const ['ROTO, PAINT, MM'],
            style: style,
          ),
        );
      });

      expect(long, greaterThan(short));
    });

    testWidgets('fits a multi-department value the old fixed width clipped', (
      tester,
    ) async {
      const value = 'ROTO, PAINT';
      final width = await _withContext(
        tester,
        (context) => gridColumnWidth(
          context,
          label: 'Tasks',
          values: const [value],
          style: style,
        ),
      );

      expect(
        width,
        greaterThanOrEqualTo(
          _paintedWidth(value, style) + gridColumnHorizontalPadding,
        ),
      );
    });

    testWidgets('never exceeds the maximum width', (tester) async {
      final width = await _withContext(
        tester,
        (context) => gridColumnWidth(
          context,
          label: 'Review Notes',
          values: ['x' * 400],
          style: style,
        ),
      );

      expect(width, gridColumnMaxWidth);
    });

    testWidgets('never shrinks below the minimum width', (tester) async {
      final width = await _withContext(
        tester,
        (context) => gridColumnWidth(
          context,
          label: '',
          values: const <String>[],
          style: style,
        ),
      );

      expect(width, gridColumnMinWidth);
    });

    testWidgets('honours a per-column minimum width', (tester) async {
      final width = await _withContext(
        tester,
        (context) =>
            gridColumnWidth(context, label: '', style: style, minWidth: 90),
      );

      expect(width, 90);
    });

    testWidgets('caps how much a wrapping header may contribute', (
      tester,
    ) async {
      final width = await _withContext(
        tester,
        (context) => gridColumnWidth(
          context,
          label: 'Shots Received Date',
          style: style,
          maxHeaderWidth: 40,
        ),
      );

      expect(width, 40 + gridColumnHorizontalPadding);
    });

    testWidgets('ignores blank values so they cannot pad a column', (
      tester,
    ) async {
      final (withBlanks, withoutBlanks) = await _withContext(tester, (context) {
        return (
          gridColumnWidth(
            context,
            label: 'Status',
            values: const ['AW', '', '   ', null],
            style: style,
          ),
          gridColumnWidth(
            context,
            label: 'Status',
            values: const ['AW'],
            style: style,
          ),
        );
      });

      expect(withBlanks, withoutBlanks);
    });
  });
}
