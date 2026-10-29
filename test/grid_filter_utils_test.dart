import 'package:flutter_test/flutter_test.dart';
import 'package:vfxpick_pipeline/core/utils/grid_filter_utils.dart';
import 'package:vfxpick_pipeline/modules/production_management/utils/grid_department_mapper.dart';

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
      // The grid always renders a date as month + day ("May-01"), never as a
      // month-year label, so that is the form the user types.
      final iso = '${DateTime.now().year}-05-01';
      expect(gridTextContains(iso, 'May-01'), isTrue);
      expect(gridTextContains(iso, 'may 01'), isTrue);
      expect(gridTextContains(iso, '${DateTime.now().year}-05'), isTrue);
      expect(gridTextContains(iso, 'may'), isTrue);
      // A month-year label is NOT what the grid shows, so it must not match.
      expect(gridTextContains(iso, 'May-25'), isFalse);
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
      final year = DateTime.now().year;
      final date = DateTime(year, 5, 1);
      expect(gridTextContains(date, '$year-05-01'), isTrue);
      expect(gridTextContains(date, 'May-01'), isTrue);
      expect(gridTextContains(date, 'may 01'), isTrue);
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

  // The production grid stores every spreadsheet cell verbatim, so these are
  // the real spellings from Master SHEET 2026.xlsx.
  group('gridDepartmentMatches (Tasks / Department)', () {
    test('matches the built-in departments in any capitalisation', () {
      expect(gridDepartmentMatches('Roto', 'ROTO'), isTrue);
      expect(gridDepartmentMatches('PAINT', 'Paint'), isTrue);
      expect(gridDepartmentMatches('  comp ', 'COMP'), isTrue);
      expect(gridDepartmentMatches('Roto', 'PAINT'), isFalse);
    });

    test('matches a runtime department to itself', () {
      expect(gridDepartmentMatches('Camera track', 'Camera track'), isTrue);
      expect(gridDepartmentMatches('Camera Track', 'CAMERA TRACK'), isTrue);
      expect(gridDepartmentMatches('Object track', 'Object track'), isTrue);
      expect(gridDepartmentMatches('Rotoanim', 'ROTOANIM'), isTrue);
      expect(gridDepartmentMatches('Rotoanim', 'Camera track'), isFalse);
    });

    test('never swallows a runtime department into a broader one', () {
      // ROTO must stay separate from ROTOANIM, and MM from Camera track.
      expect(gridDepartmentMatches('Rotoanim', 'ROTO'), isFalse);
      expect(gridDepartmentMatches('Camera track', 'MM'), isFalse);
      expect(gridDepartmentMatches('Object track', 'MM'), isFalse);
      expect(gridDepartmentMatches('Tracking', 'MM'), isTrue);
    });

    test('splits a multi-department cell', () {
      expect(gridDepartmentMatches('Paint / Comp', 'PAINT'), isTrue);
      expect(gridDepartmentMatches('Paint / Comp', 'COMP'), isTrue);
      expect(gridDepartmentMatches('Paint / Comp', 'ROTO'), isFalse);
      expect(gridDepartmentMatches('Roto + Keying', 'ROTO'), isTrue);
      expect(gridDepartmentMatches('Planar track / Comp', 'COMP'), isTrue);
    });

    test('ignores blank cells and empty selections', () {
      expect(gridDepartmentMatches('', 'ROTO'), isFalse);
      expect(gridDepartmentMatchesAny('Roto', const []), isTrue);
      expect(gridDepartmentMatchesAny(null, const ['ROTO']), isFalse);
      expect(gridDepartmentMatchesAny('Roto', const ['ROTO']), isTrue);
    });
  });

  group('gridCategoryMatchesAny (Status / Personnel / Notes)', () {
    test('a category chip catches the sheet variants', () {
      expect(gridCategoryMatchesAny('Hold', {'Hold'}), isTrue);
      expect(gridCategoryMatchesAny('HOLD', {'Hold'}), isTrue);
      expect(gridCategoryMatchesAny('Hold as of now', {'Hold'}), isTrue);
      expect(gridCategoryMatchesAny('RTU / Hold', {'Hold'}), isTrue);
      expect(gridCategoryMatchesAny('Delivered', {'Hold'}), isFalse);
    });

    test('work station names match their category', () {
      expect(gridCategoryMatchesAny('FL Kavi', {'FL'}), isTrue);
      expect(gridCategoryMatchesAny('FL_Bavi', {'FL'}), isTrue);
      expect(gridCategoryMatchesAny('  FL Saranga shivakumar', {'FL'}), isTrue);
      expect(gridCategoryMatchesAny('Inhouse / FL', {'FL'}), isTrue);
      expect(gridCategoryMatchesAny('In house', {'Inhouse'}), isTrue);
      // The combined chip is narrower than its parts, so it only matches the
      // combined value itself.
      expect(gridCategoryMatchesAny('Inhouse', {'Inhouse / FL'}), isFalse);
      expect(gridCategoryMatchesAny('Inhouse / FL', {'Inhouse / FL'}), isTrue);
      expect(gridCategoryMatchesAny('Inhouse', {'FL'}), isFalse);
    });

    test('coordinators match inside a paired value', () {
      expect(
        gridCategoryMatchesAny('Sangeetha / Saravanan', {'Sangeetha'}),
        isTrue,
      );
      expect(
        gridCategoryMatchesAny('Arun / Saravanan', {'Sangeetha'}),
        isFalse,
      );
    });

    test('review notes match the sheet spelling', () {
      expect(
        gridCategoryMatchesAny('Client feedback', {'Client Feedback'}),
        isTrue,
      );
      expect(
        gridCategoryMatchesAny('Final locked QT received', {'QT'}),
        isTrue,
      );
      expect(gridCategoryMatchesAny('Episode 104', {'Episode 104'}), isTrue);
    });

    test('Blank matches empty cells only', () {
      expect(gridCategoryMatchesAny(null, {'Blank'}), isTrue);
      expect(gridCategoryMatchesAny('   ', {'Blank'}), isTrue);
      expect(gridCategoryMatchesAny('Inhouse', {'Blank'}), isFalse);
      expect(gridCategoryMatchesAny('Inhouse', {'Blank', 'Inhouse'}), isTrue);
    });

    test('an empty selection matches everything', () {
      expect(gridCategoryMatchesAny('anything', const <String>{}), isTrue);
      expect(gridCategoryMatchesAny(null, const <String>{}), isTrue);
    });
  });
}
