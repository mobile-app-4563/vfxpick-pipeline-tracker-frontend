import '../lib/core/utils/excel_date_utils.dart';

void main() {
  final now = DateTime.now();
  print('NOW: $now');

  // Values straight from "excel Jan - dec today pickout.xlsx"
  final cases = <String, String?>{
    'Sep-01': '${now.year}-09-01', // today's pickout → must be THIS year
    'Sep-02': '${now.year}-09-02', // tomorrow
    'Sep-03': '${now.year}-09-03',
    'Sep-04': '${now.year}-09-04',
    'Sep-1': '${now.year}-09-01', // no leading zero
    'May-25': '${now.year}-05-25', // day interpretation
    'May 2025': '2025-05-01', // month-year still works
    'May-25 2025': null,
    '2025-05-01': '2025-05-01', // ISO unchanged
    '2025-05-01T00:00:00.000Z': '2025-05-01', // ISO unchanged
    '25 May 2025': '2025-05-25', // day-named-year unchanged
    'Feb-30': null, // impossible day → null
    'Feb-29': now.year % 4 == 0 && now.year % 100 != 0 || now.year % 400 == 0
        ? '${now.year}-02-29'
        : null,
  };

  var failures = 0;
  cases.forEach((input, expected) {
    final actual = excelDateToIso(input);
    final ok = actual == expected;
    if (!ok) failures++;
    print('${ok ? 'PASS' : 'FAIL'}  $input  ->  $actual  (expected $expected)');
  });
  print(failures == 0 ? 'ALL PASS' : '$failures FAILURES');
}
