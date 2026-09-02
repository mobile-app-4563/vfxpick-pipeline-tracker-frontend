import 'package:flutter_test/flutter_test.dart';

import 'package:vfxpick_pipeline/core/utils/show_resolver.dart';

/// Mirrors the real scenario from the user's Excel import:
///   - SN4  (client 120)
///   - Kalshi Beast Mode (client 120)
///   - Shiver (client 271)
///   - Trucks (client 152)
/// The file's Show column may say "SN4", "Kalshi Beast Mode",
/// "KALSHI BEASTMODE_Pkg_1", etc.
List<Map<String, String>> demoShows() => [
  {'showId': 'SHW_SN4', 'showName': 'SN4', 'clientId': 'CLT_120'},
  {
    'showId': 'SHW_KALSHI',
    'showName': 'Kalshi Beast Mode',
    'clientId': 'CLT_120',
  },
  {'showId': 'SHW_SHIVER', 'showName': 'Shiver', 'clientId': 'CLT_271'},
  {'showId': 'SHW_TRUCKS', 'showName': 'Trucks', 'clientId': 'CLT_152'},
];

void main() {
  group('resolveShowId — Excel Show column → real showId', () {
    test('exact show name resolves to its own show (not the selected one)', () {
      // Toolbar has SN4 selected, but the file row says "Kalshi Beast Mode".
      final id = resolveShowId(
        'Kalshi Beast Mode',
        demoShows(),
        targetShowId: 'SHW_SN4',
        fallbackShowId: 'SHW_SN4',
      );
      expect(id, 'SHW_KALSHI');
    });

    test('exact show name wins over fallback showId', () {
      final id = resolveShowId(
        'Shiver',
        demoShows(),
        targetShowId: 'SHW_SN4',
        fallbackShowId: 'SHW_SN4',
      );
      expect(id, 'SHW_SHIVER');
    });

    test('case-insensitive exact match', () {
      final id = resolveShowId(
        'kalshi beast mode',
        demoShows(),
        targetShowId: 'SHW_SN4',
        fallbackShowId: 'SHW_SN4',
      );
      expect(id, 'SHW_KALSHI');
    });

    test('exact showId in the file resolves directly', () {
      final id = resolveShowId(
        'SHW_SHIVER',
        demoShows(),
        targetShowId: 'SHW_SN4',
        fallbackShowId: 'SHW_SN4',
      );
      expect(id, 'SHW_SHIVER');
    });

    test('package name (KALSHI BEASTMODE_Pkg_1) fuzzy-matches the show', () {
      // Real file template value: uppercase + underscore package suffix.
      final id = resolveShowId(
        'KALSHI BEASTMODE_Pkg_1',
        demoShows(),
        targetShowId: 'SHW_SN4',
        fallbackShowId: 'SHW_SN4',
      );
      expect(id, 'SHW_KALSHI');
    });

    test('package name with space-less variant (Kalshi Beastmode) matches', () {
      final id = resolveShowId(
        'Kalshi Beastmode_Pkg_2',
        demoShows(),
        targetShowId: 'SHW_SN4',
        fallbackShowId: 'SHW_SN4',
      );
      expect(id, 'SHW_KALSHI');
    });

    test('client-scoped: prefers same-client show when name is ambiguous', () {
      // "Trucks" belongs to CLT_152.  If the selected show is under a client
      // that has no "Trucks", we still find it globally — but if the target
      // client had its own show containing "truck", that should win first.
      final id = resolveShowId(
        'TRUCKS_14719_Pkg_10',
        demoShows(),
        targetShowId: 'SHW_SHIVER', // client 271
        fallbackShowId: 'SHW_SHIVER',
      );
      expect(id, 'SHW_TRUCKS');
    });

    test('no match anywhere → fallback to toolbar-selected show', () {
      final id = resolveShowId(
        'Totally Unknown Show',
        demoShows(),
        targetShowId: 'SHW_SN4',
        fallbackShowId: 'SHW_SN4',
      );
      expect(id, 'SHW_SN4');
    });

    test('empty Show value → fallback to toolbar-selected show', () {
      final id = resolveShowId(
        '',
        demoShows(),
        targetShowId: 'SHW_SN4',
        fallbackShowId: 'SHW_SN4',
      );
      expect(id, 'SHW_SN4');
    });

    test('short names do not cause false positives', () {
      // "SN" is a 2-char substring of many things, but must not hijack a
      // longer show match.
      final id = resolveShowId(
        'SN4',
        demoShows(),
        targetShowId: 'SHW_SN4',
        fallbackShowId: 'SHW_SN4',
      );
      expect(id, 'SHW_SN4');
    });

    test('showsListFromArgs filters out entries without an id', () {
      final out = showsListFromArgs([
        {'showId': 'SHW_1', 'showName': 'One', 'clientId': 'CLT_1'},
        {'showName': 'No Id Here', 'clientId': 'CLT_1'},
        {'showId': 'SHW_2', 'showName': 'Two', 'clientId': 'CLT_2'},
      ]);
      expect(out, hasLength(2));
      expect(out[0]['showId'], 'SHW_1');
      expect(out[1]['showId'], 'SHW_2');
    });

    test('non-list args produce an empty list', () {
      expect(showsListFromArgs(null), isEmpty);
      expect(showsListFromArgs('nope'), isEmpty);
    });
  });

  group('resolveShowId — clientScopeId scoping (Excel-driven client)', () {
    test('show resolves within the file-named client', () {
      final id = resolveShowId(
        'Kalshi Beast Mode',
        demoShows(),
        clientScopeId: 'CLT_120',
        targetShowId: 'SHW_SN4',
        fallbackShowId: 'SHW_SN4',
      );
      expect(id, 'SHW_KALSHI');
    });

    test('client-scoped: same-client show wins over global fallback', () {
      final id = resolveShowId(
        'Trucks',
        demoShows(),
        clientScopeId: 'CLT_152',
        targetShowId: 'SHW_SN4',
        fallbackShowId: 'SHW_SN4',
      );
      expect(id, 'SHW_TRUCKS');
    });

    test('no match under the file-named client → empty fallback (skip)', () {
      // File says client 120 but the show belongs to client 271: strict mode
      // must NOT stamp the toolbar show — it returns the empty fallback so
      // the caller skips the row.
      final id = resolveShowId(
        'Shiver',
        demoShows(),
        clientScopeId: 'CLT_120',
        targetShowId: 'SHW_SN4',
        fallbackShowId: '',
      );
      expect(id, '');
    });

    test('no match under the file-named client with non-empty fallback', () {
      // Same situation but with a toolbar fallback: strict callers pass '' so
      // the fallback only survives when the caller explicitly wants it.
      final id = resolveShowId(
        'Shiver',
        demoShows(),
        clientScopeId: 'CLT_120',
        targetShowId: 'SHW_SN4',
        fallbackShowId: 'SHW_SN4',
      );
      expect(id, 'SHW_SN4');
    });
  });

  group('resolveClientId — Excel Client column → real clientId', () {
    final clients = [
      {'clientId': 'CLT_120', 'clientName': 'Kalshi'},
      {'clientId': 'CLT_271', 'clientName': 'Shiver Studios'},
      {'clientId': 'CLT_152', 'clientName': 'Trucks & Co'},
    ];

    test('exact name match', () {
      expect(resolveClientId('Kalshi', clients), 'CLT_120');
    });

    test('case-insensitive exact match', () {
      expect(resolveClientId('kalshi', clients), 'CLT_120');
      expect(resolveClientId('SHIVER STUDIOS', clients), 'CLT_271');
    });

    test('fuzzy contains match (punctuation/whitespace differences)', () {
      expect(resolveClientId('Trucks & Co.', clients), 'CLT_152');
      expect(resolveClientId('ShiverStudios', clients), 'CLT_271');
    });

    test('longest client name wins when several fuzzy-match', () {
      // Both "Shiver" and "Shiver Studios" would match — the longer (more
      // specific) client name must win.
      final wider = [
        {'clientId': 'CLT_A', 'clientName': 'Shiver'},
        {'clientId': 'CLT_B', 'clientName': 'Shiver Studios'},
      ];
      expect(resolveClientId('Shiver Studios', wider), 'CLT_B');
    });

    test('empty value → empty id', () {
      expect(resolveClientId('', clients), '');
      expect(resolveClientId('   ', clients), '');
    });

    test('no match → empty id (caller decides skip/scoping)', () {
      expect(resolveClientId('Unknown Client Ltd', clients), '');
    });

    test('clientsListFromArgs sanitizes isolate args', () {
      final out = clientsListFromArgs([
        {'clientId': 'CLT_1', 'clientName': 'One'},
        {'clientName': 'No Id'},
        {'clientId': 'CLT_2', 'clientName': 'Two'},
      ]);
      expect(out, hasLength(2));
      expect(out[0]['clientId'], 'CLT_1');
      expect(out[0]['clientName'], 'One');
    });

    test('clientsListFromArgs tolerates null/non-list input', () {
      expect(clientsListFromArgs(null), isEmpty);
      expect(clientsListFromArgs('nope'), isEmpty);
    });
  });
}
