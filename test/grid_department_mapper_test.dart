import 'package:flutter_test/flutter_test.dart';
import 'package:vfxpick_pipeline/modules/production_management/utils/grid_department_mapper.dart';

void main() {
  group('normalizeGridTasks', () {
    test('leaves the four pipeline departments untouched', () {
      for (final dept in gridDepartments) {
        expect(normalizeGridTasks(dept), dept);
      }
    });

    test('upper-cases and trims', () {
      expect(normalizeGridTasks('  roto '), 'ROTO');
      expect(normalizeGridTasks('comp'), 'COMP');
    });

    test('returns empty for blank input', () {
      expect(normalizeGridTasks(''), '');
      expect(normalizeGridTasks('   '), '');
    });

    // Every value below actually appears in jan_dec_full.xlsx (2,939 rows
    // combined) and used to be invisible under every department filter.
    test('maps the real spreadsheet spellings', () {
      expect(normalizeGridTasks('CAMERA TRACK'), 'MM');
      expect(normalizeGridTasks('OBJECT TRACK'), 'MM');
      expect(normalizeGridTasks('TRACKING'), 'MM');
      expect(normalizeGridTasks('RETOPO'), 'MM');
      expect(normalizeGridTasks('RIGGING'), 'MM');
      expect(normalizeGridTasks('UV / TEXTURE'), 'MM');
      expect(normalizeGridTasks('ROTOANIM'), 'ROTO');
      expect(normalizeGridTasks('ROTO ANIM'), 'ROTO');
      expect(normalizeGridTasks('ROTOANIMATION'), 'ROTO');
      expect(normalizeGridTasks('ROTO + KEYING'), 'ROTO');
      expect(normalizeGridTasks('DMP'), 'PAINT');
      expect(normalizeGridTasks('CGI'), 'COMP');
    });

    test('splits multi-department values in pipeline order', () {
      expect(normalizeGridTasks('PAINT / COMP'), 'PAINT, COMP');
      expect(normalizeGridTasks('PAINT & COMP'), 'PAINT, COMP');
      expect(normalizeGridTasks('PAINT+ROTO'), 'ROTO, PAINT');
      expect(normalizeGridTasks('PLANAR TRACK / COMP'), 'MM, COMP');
      expect(normalizeGridTasks('ROTO + PAINT + TRACKING'), 'ROTO, PAINT, MM');
      expect(normalizeGridTasks('PAINT AND COMP'), 'PAINT, COMP');
    });

    test('de-duplicates repeated departments', () {
      expect(normalizeGridTasks('ROTO, ROTO'), 'ROTO');
      expect(normalizeGridTasks('ROTO + ROTOSCOPE'), 'ROTO');
    });

    test('keeps unrecognised text instead of inventing a department', () {
      expect(normalizeGridTasks('NO TASK'), 'NO TASK');
      expect(normalizeGridTasks('PAINTED BG'), 'PAINTED BG');
      expect(normalizeGridTasks('SOMETHING ELSE'), 'SOMETHING ELSE');
    });

    test('keeps unknown parts alongside known ones', () {
      expect(normalizeGridTasks('ROTO / NO TASK'), 'ROTO, NO TASK');
    });

    test('does not match a department inside a longer word', () {
      expect(normalizeGridTasks('COMPUTER'), 'COMPUTER');
      expect(normalizeGridTasks('PAINTER'), 'PAINTER');
    });

    test('matches aliases in any capitalisation', () {
      expect(normalizeGridTasks('camera track'), 'MM');
      expect(normalizeGridTasks('Camera Track'), 'MM');
      expect(normalizeGridTasks('  CaMeRa   TrAcK '), 'MM');
      expect(normalizeGridTasks('rotoanim'), 'ROTO');
      expect(normalizeGridTasks('Dmp'), 'PAINT');
      expect(normalizeGridTasks('paint / comp'), 'PAINT, COMP');
      expect(normalizeGridTasks('roto + tracking'), 'ROTO, MM');
    });

    test('is idempotent on already-normalized values', () {
      for (final raw in <String>[
        'CAMERA TRACK',
        'ROTOANIM',
        'PAINT / COMP',
        'NO TASK',
        'ROTO + PAINT + TRACKING',
      ]) {
        final once = normalizeGridTasks(raw);
        expect(normalizeGridTasks(once), once, reason: 'raw: $raw');
      }
    });
  });

  group('unmappedGridTaskParts', () {
    test('is empty for mapped values', () {
      expect(unmappedGridTaskParts('ROTO'), isEmpty);
      expect(unmappedGridTaskParts('PAINT, COMP'), isEmpty);
      expect(unmappedGridTaskParts(''), isEmpty);
    });

    test('reports the leftovers', () {
      expect(unmappedGridTaskParts('NO TASK'), ['NO TASK']);
      expect(unmappedGridTaskParts('ROTO, NO TASK'), ['NO TASK']);
    });
  });

  group('gridExtraDepartments', () {
    test('is empty when every value is a pipeline department', () {
      expect(gridExtraDepartments(const []), isEmpty);
      expect(gridExtraDepartments(const ['ROTO']), isEmpty);
      expect(gridExtraDepartments(const ['ROTO, PAINT', 'MM, COMP']), isEmpty);
    });

    test('is case-insensitive about what counts as known', () {
      expect(gridExtraDepartments(const ['roto', 'Roto', 'ROTO']), isEmpty);
      expect(gridExtraDepartments(const ['paint / comp']), isEmpty);
    });

    test('reports values the importer could not place', () {
      expect(gridExtraDepartments(const ['NO TASK']), const ['NO TASK']);
      expect(gridExtraDepartments(const ['ROTO, NO TASK']), const ['NO TASK']);
      expect(gridExtraDepartments(const ['NO TASK', 'PLATES', 'ROTO']), const [
        'NO TASK',
        'PLATES',
      ]);
    });

    test('de-duplicates case-insensitively and sorts', () {
      expect(gridExtraDepartments(const ['NO TASK', 'no task']), const [
        'NO TASK',
      ]);
      expect(gridExtraDepartments(const ['PLATES', 'NO TASK', 'BG']), const [
        'BG',
        'NO TASK',
        'PLATES',
      ]);
    });

    test('accepts a custom known list', () {
      expect(
        gridExtraDepartments(const ['ROTO', 'BG'], known: const ['ROTO', 'BG']),
        isEmpty,
      );
    });
  });
}
