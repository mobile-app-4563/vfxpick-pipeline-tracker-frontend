/// Matches the Tasks/Department values found in imported spreadsheets against
/// the pipeline departments, for the grid's Department / Tasks filters.
///
/// The import itself stores the spreadsheet cell verbatim — nothing is mapped,
/// validated or rewritten — so this library is used only to make filtering and
/// the filter-option lists understand the spellings actually present in the
/// data.
///
/// Matching is case-insensitive: every capitalisation of a known spelling
/// (``camera track``, ``Camera Track``, ``CAMERA TRACK``) normalises onto the
/// same canonical department. Runtime-added departments such as Camera track,
/// Object track and Rotoanim resolve to themselves and are never folded into a
/// built-in department. Values that cannot be recognised are kept verbatim —
/// never dropped and never rejected — and [gridExtraDepartments] feeds them to
/// the Department / Tasks filters so those rows stay reachable instead of
/// hiding behind the "All" option.
library;

/// Pipeline departments an imported Tasks value is mapped onto.
const List<String> gridDepartments = <String>['ROTO', 'PAINT', 'MM', 'COMP'];

/// Spreadsheet spellings for each pipeline department (keys upper-cased,
/// values one of [gridDepartments]).
///
/// Real sheets spell the same work many ways. Only values that are intended to
/// map to one of the four built-in departments are listed here.
const Map<String, String> gridTaskAlias = <String, String>{
  // ROTO — rotoscoping and keying.
  'ROTO': 'ROTO',
  'ROTOSCOPE': 'ROTO',
  'ROTOSCOPY': 'ROTO',
  'ROTOKEY': 'ROTO',
  'ROTO KEY': 'ROTO',
  'ROTO KEYING': 'ROTO',
  'KEYING': 'ROTO',

  // PAINT — cleanup, prep and matte painting.
  'PAINT': 'PAINT',
  'PAINTING': 'PAINT',
  'DIGI PAINT': 'PAINT',
  'DIGITAL PAINT': 'PAINT',
  'PREP': 'PAINT',
  'CLEANUP': 'PAINT',
  'CLEAN UP': 'PAINT',
  'DUSTBUST': 'PAINT',
  'DUST BUST': 'PAINT',
  'WIRE REMOVAL': 'PAINT',
  'DMP': 'PAINT',
  'MATTE': 'PAINT',
  'MATTE PAINTING': 'PAINT',

  // MM — matchmove, tracking and modelling.
  'MM': 'MM',
  'MATCHMOVE': 'MM',
  'MATCH MOVE': 'MM',
  'MATCHMOTION': 'MM',
  'MATCH MOTION': 'MM',
  'PLANAR TRACK': 'MM',
  'PLANE TRACK': 'MM',
  '3D TRACK': 'MM',
  'MOTION TRACK': 'MM',
  'TRACKING': 'MM',
  'MODELING': 'MM',
  'MODELLING': 'MM',
  'RETOPO': 'MM',
  'RETOPOLOGY': 'MM',
  'RIGGING': 'MM',
  'UV': 'MM',
  'TEXTURE': 'MM',
  'SHADING': 'MM',
  'LOOKDEV': 'MM',
  'LOOK DEV': 'MM',

  // COMP — compositing.
  'COMP': 'COMP',
  'COMPOSITING': 'COMP',
  'COMPOSITE': 'COMP',
  'CGI': 'COMP',

  // Runtime departments the user created. These resolve to themselves so the
  // import never folds them into a built-in department — in particular
  // Camera/Object tracking must never become MM.
  'ROTOANIM': 'ROTOANIM',
  'ROTO ANIM': 'ROTO ANIM',
  'ROTOANIMATION': 'ROTOANIMATION',
  'ROTO ANIMATION': 'ROTO ANIMATION',
  'CAMERA TRACK': 'CAMERA TRACK',
  'CAM TRACK': 'CAMERA TRACK',
  'CAMTRACK': 'CAMERA TRACK',
  'OBJECT TRACK': 'OBJECT TRACK',
  'OBJ TRACK': 'OBJECT TRACK',
};

/// Separators real sheets use between two departments on one row.
final RegExp _separator = RegExp(r'[,/&+]|\bAND\b');

/// Valid standalone runtime departments that must not be reduced by a
/// broader built-in alias such as ROTO.
const Set<String> _preservedGridTaskLabels = <String>{
  'CAMERA TRACK',
  'OBJECT TRACK',
  'ROTOANIM',
  'ROTO ANIM',
  'ROTOANIMATION',
  'ROTO ANIMATION',
};

/// Maps a free-text Tasks/Department value onto the pipeline departments.
///
/// A value may name several departments (``PAINT / COMP``, ``ROTO + PAINT +
/// TRACKING``); those are split on ``,`` ``/`` ``&`` ``+`` ``AND`` and stored
/// comma-separated in pipeline order. Parts that match no known spelling are
/// kept verbatim, upper-cased and trimmed.
///
/// Returns ``''`` for an empty/blank input.
String normalizeGridTasks(String raw) {
  // Upper-case for case-insensitive matching, and collapse repeated
  // whitespace so "CaMeRa   TrAcK" matches the same alias as "CAMERA TRACK".
  final value = raw.toUpperCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  if (value.isEmpty) return '';
  if (_preservedGridTaskLabels.contains(value)) return value;

  final parts = value
      .split(_separator)
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return value;

  final mapped = <String>{};
  for (final part in parts) {
    mapped.add(gridTaskAlias[part] ?? _matchAlias(part) ?? part);
  }

  final ordered = <String>[
    ...gridDepartments.where(mapped.contains),
    ...mapped.where((m) => !gridDepartments.contains(m)).toList()..sort(),
  ];
  // A value that already was exactly one known department is unchanged.
  if (ordered.length == 1 && ordered.first == value) return value;
  return ordered.join(', ');
}

/// Finds the longest alias appearing as a whole word inside [part], so
/// ``ROTO ANIM`` wins over ``ROTO`` and ``ROTO KEYING`` still resolves.
String? _matchAlias(String part) {
  final keys = gridTaskAlias.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final key in keys) {
    if (part == key) return gridTaskAlias[key];
    if (RegExp(r'(^|\s)' + RegExp.escape(key) + r'($|\s)').hasMatch(part)) {
      return gridTaskAlias[key];
    }
  }
  return null;
}

/// Department values present in [tasksValues] that are not one of [known].
///
/// Real sheets carry spellings the importer cannot place (``NO TASK``,
/// ``PLATES`` …). Those rows are still saved, so the Department and Tasks
/// filters are extended with the values actually present in the data —
/// otherwise the row would be unreachable unless the user picked "All".
///
/// Comparison is case-insensitive, so ``roto`` is never reported as an extra
/// when ``ROTO`` is already known. Each value is normalised first, so a
/// multi-department spelling such as ``paint / comp`` is split exactly as
/// [normalizeGridTasks] splits it. The values are returned trimmed and sorted,
/// retaining the capitalisation stored in the data.
List<String> gridExtraDepartments(
  Iterable<String> tasksValues, {
  Iterable<String> known = gridDepartments,
}) {
  final knownUpper = known.map((k) => k.trim().toUpperCase()).toSet();
  final seen = <String>{};
  final extras = <String>[];
  for (final raw in tasksValues) {
    for (final part in normalizeGridTasks(raw).split(',')) {
      final value = part.trim();
      if (value.isEmpty) continue;
      final upper = value.toUpperCase();
      if (knownUpper.contains(upper)) continue;
      if (seen.add(upper)) extras.add(value);
    }
  }
  extras.sort();
  return extras;
}
