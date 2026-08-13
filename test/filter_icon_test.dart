// import 'package:flutter/material.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:vfxpick_pipeline/shared/widgets/filter_icon.dart';

// void main() {
//   testWidgets('shows deduplicated selectable chips for filter options', (
//     WidgetTester tester,
//   ) async {
//     await tester.pumpWidget(
//       MaterialApp(
//         home: Scaffold(
//           body: FilterIcon(
//             label: 'Status',
//             options: const [
//               FilterOption(label: 'Open', value: 'Open'),
//               FilterOption(label: 'Open', value: 'Open'),
//               FilterOption(label: 'Closed', value: 'Closed', isSelected: true),
//             ],
//             onFilterChanged: (_) {},
//             onClear: () {},
//           ),
//         ),
//       ),
//     );

//     await tester.tap(find.byIcon(Icons.filter_list));
//     await tester.pumpAndSettle();

//     expect(find.text('Open'), findsOneWidget);
//     expect(find.text('Closed'), findsOneWidget);
//     expect(find.byType(FilterChip), findsNWidgets(2));
//   });
// }
