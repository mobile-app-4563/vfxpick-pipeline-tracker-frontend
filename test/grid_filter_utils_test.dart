import 'package:flutter_test/flutter_test.dart';
import 'package:vfxpick_pipeline/core/utils/grid_filter_utils.dart';

void main() {
  group('gridTextContains', () {
    test('is case-insensitive for plain text', () {
      expect(gridTextContains('Client ABC', 'client'), isTrue);
      expect(gridTextContains('client abc', 'CLIENT ABC'), isTrue);
      expect(gridTextContains('Roto/Paint', 'roto'), isTrue);
      expect(gridTextContains('Roto', 'paint'), isFalse);
    });

    test('empty query matches everything', () {
      expect(gridTextContains('anything', ''), isTrue);
      expect(gridTextContains('anything', '   '), isTrue);
      expect(gridTextContains(null, ''), isTrue);
    });

    test('matches Excel-style labels from ISO stored dates', () {
      // Use a year that is NOT the current one so the date renders as the
      // month-year label ("May-25" style), independent of the machine clock.
      final now = DateTime.now();
      final year = now.year != 2025 ? 2025 : 2026;
      final yy = (year % 100).toString().padLeft(2, '0');
      final iso = '$year-05-01';
      expect(gridTextContains(iso, 'May-$yy'), isTrue);
      expect(gridTextContains(iso, 'may $yy'), isTrue);
      expect(gridTextContains(iso, '$year-05'), isTrue);
      expect(gridTextContains(iso, 'may'), isTrue);
    });

    test('matches the month-day label of a date in the current year', () {
      final iso = '${DateTime.now().year}-05-15';
      expect(gridTextContains(iso, 'may-15'), isTrue);
      expect(gridTextContains(iso, 'May 15'), isTrue);
    });

    test('matches dd/MM/yyyy with different separators', () {
      expect(gridTextContains('14/05/2025', '14-05-2025'), isTrue);
      expect(gridTextContains('14/05/2025', '14 05 2025'), isTrue);
      expect(gridTextContains('14/05/2025', '14.05.2025'), isTrue);
    });

    test('matches DateTime objects by ISO and by label', () {
      final now = DateTime.now();
      final year = now.year != 2025 ? 2025 : 2026;
      final yy = (year % 100).toString().padLeft(2, '0');
      final date = DateTime(year, 5, 1);
      expect(gridTextContains(date, '$year-05-01'), isTrue);
      expect(gridTextContains(date, 'May-$yy'), isTrue);
    });

    test('ignores thousands separators in numbers', () {
      expect(gridTextContains('1,234.5', '1234'), isTrue);
      expect(gridTextContains('1234.5', '1,234'), isTrue);
    });

    test('never treats a bare number as an Excel date serial', () {
      // 100 as an Excel date serial is 1900-04-09; it must stay a frame count.
      expect(gridTextContains('100', 'apr'), isFalse);
      expect(gridTextContains(100, 'apr'), isFalse);
      expect(gridTextContains('100', '100'), isTrue);
      expect(gridTextContains(100, '1'), isTrue);
    });

    test('does not date-parse prose even when it contains a month word', () {
      expect(gridTextContains('Rohit May sent it', '2025-05-01'), isFalse);
      expect(gridTextContains('Rohit May sent it', 'may'), isTrue);
    });

    test('matches whitespace variants of multi-word chips', () {
      expect(gridTextContains('Inhouse/FL', 'inhouse / fl'), isTrue);
    });
  });

  group('gridEqualsIgnoreCase', () {
    test('compares case-insensitively', () {
      expect(gridEqualsIgnoreCase('WIP', 'wip'), isTrue);
      expect(gridEqualsIgnoreCase('Inhouse / FL', 'inhouse/fl'), isTrue);
      expect(gridEqualsIgnoreCase('Hold', 'wip'), isFalse);
      expect(gridEqualsIgnoreCase(null, 'wip'), isFalse);
      expect(gridEqualsIgnoreCase('WIP', ''), isTrue);
    });
  });

  group('gridSetContainsIgnoreCase', () {
    test('matches case-insensitively and supports Blank', () {
      expect(gridSetContainsIgnoreCase('WIP', {'wip'}), isTrue);
      expect(gridSetContainsIgnoreCase('wip', {'WIP'}), isTrue);
      expect(gridSetContainsIgnoreCase('Hold', {'wip'}), isFalse);
      expect(gridSetContainsIgnoreCase('', {'Blank'}), isTrue);
      expect(gridSetContainsIgnoreCase('', {}), isTrue);
    });
  });
}
