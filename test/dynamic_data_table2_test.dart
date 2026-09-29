import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vfxpick_pipeline/shared/widgets/dynamic_data_table.dart';

void main() {
  testWidgets('DataTable2 renders long cell content in the bounded grid', (
    tester,
  ) async {
    const content = 'A long production value that should stay within its cell';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 140,
            child: DynamicDataTable(
              fields: [
                DynamicTableField(key: 'show', label: 'Show', width: 180),
              ],
              rows: [
                <String, dynamic>{'show': content},
              ],
              rowsPerPage: 0,
              useDataTable2: true,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Show'), findsOneWidget);
    expect(find.text(content), findsOneWidget);
    expect(tester.widget<Text>(find.text(content)).maxLines, 2);
  });
}
