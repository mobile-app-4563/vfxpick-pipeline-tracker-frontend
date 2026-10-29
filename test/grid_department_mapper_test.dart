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
      expect(normalizeGridTasks('CAMERA TRACK'), 'CAMERA TRACK');
      expect(normalizeGridTasks('OBJECT TRACK'), 'OBJECT TRACK');
      expect(normalizeGridTasks('TRACKING'), 'MM');
      expect(normalizeGridTasks('RETOPO'), 'MM');
      expect(normalizeGridTasks('RIGGING'), 'MM');
      expect(normalizeGridTasks('UV / TEXTURE'), 'MM');
      expect(normalizeGridTasks('ROTOANIM'), 'ROTOANIM');
      expect(normalizeGridTasks('ROTO ANIM'), 'ROTO ANIM');
      expect(normalizeGridTasks('ROTOANIMATION'), 'ROTOANIMATION');
      expect(normalizeGridTasks('ROTO + KEYING'), 'ROTO');
      expect(normalizeGridTasks('DMP'), 'PAINT');
      expect(normalizeGridTasks('CGI'), 'COMP');
    });

    // Camera / Object tracking and Rotoanim are their own runtime departments,
    // never MM. The abbreviated spellings follow the same rule.
    test('never folds a tracking department into MM', () {
      expect(normalizeGridTasks('CAM TRACK'), 'CAMERA TRACK');
      expect(normalizeGridTasks('CAMTRACK'), 'CAMERA TRACK');
      expect(normalizeGridTasks('cam track'), 'CAMERA TRACK');
      expect(normalizeGridTasks('OBJ TRACK'), 'OBJECT TRACK');
      expect(normalizeGridTasks('obj track'), 'OBJECT TRACK');
      expect(normalizeGridTasks('ROTO ANIMATION'), 'ROTO ANIMATION');
      expect(normalizeGridTasks('PLANAR TRACK'), 'MM');
    });

    test('keeps a tracking department alongside a built-in one', () {
      expect(
        normalizeGridTasks('CAMERA TRACK / OBJECT TRACK'),
        'CAMERA TRACK, OBJECT TRACK',
      );
      expect(normalizeGridTasks('Camera track / Comp'), 'COMP, CAMERA TRACK');
      expect(normalizeGridTasks('Rotoanim + Paint'), 'PAINT, ROTOANIM');
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
      expect(normalizeGridTasks('camera track'), 'CAMERA TRACK');
      expect(normalizeGridTasks('Camera Track'), 'CAMERA TRACK');
      expect(normalizeGridTasks('  CaMeRa   TrAcK '), 'CAMERA TRACK');
      expect(normalizeGridTasks('rotoanim'), 'ROTOANIM');
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
        'CAMERA TRACK, OBJECT TRACK',
        'PAINT, ROTOANIM',
      ]) {
        final once = normalizeGridTasks(raw);
        expect(normalizeGridTasks(once), once, reason: 'raw: $raw');
      }
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
