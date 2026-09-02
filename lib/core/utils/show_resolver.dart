/// Pure show-resolution helpers used by the Projects import pipeline.
///
/// These live in a plain Dart file (no Flutter imports) so they can be unit
/// tested in isolation and shared between the isolate entry points in
/// `projects_screen.dart`.
library;

/// Extracts the serializable shows list (id + name + client) from the raw
/// isolate-args `shows` value, as a plain list of string maps.
List<Map<String, String>> showsListFromArgs(dynamic rawShows) {
  final out = <Map<String, String>>[];
  if (rawShows is! List) return out;
  for (final s in rawShows) {
    if (s is! Map) continue;
    final id = (s['showId'] ?? '').toString().trim();
    final name = (s['showName'] ?? '').toString().trim();
    final clientId = (s['clientId'] ?? '').toString().trim();
    if (id.isEmpty) continue;
    out.add(<String, String>{
      'showId': id,
      'showName': name,
      'clientId': clientId,
    });
  }
  return out;
}

/// Resolves a value from the file's "Show" column to a real showId.
///
/// Matching is deliberately permissive because the Excel often stores package
/// names (e.g. "KALSHI BEASTMODE_Pkg_1") rather than the exact show name:
///   1. exact case-insensitive show-name match within the target show's client
///   2. exact case-insensitive show-name match across ALL of the user's shows
///   3. exact showId match (file may store the raw id)
///   4. fuzzy "contains" match against the target client's shows, preferring
///      the longest show name (so a package prefix resolves to the show, not
///      to a shorter similarly-named show)
///   5. fall back to [fallbackShowId] (the toolbar-selected show)
///
/// [clientScopeId] (when non-empty) overrides the target-client scoping: the
/// show is only matched against shows belonging to that client.  The import
/// passes the client resolved from the file's own "Client" column so a row
/// whose client and show disagree never gets stamped with the toolbar show.
String resolveShowId(
  String fileShowRaw,
  List<Map<String, String>> showsList, {
  required String targetShowId,
  required String fallbackShowId,
  String? clientScopeId,
}) {
  final raw = fileShowRaw.trim().toLowerCase();
  if (raw.isEmpty) return fallbackShowId;

  // Strict mode: the file itself named a client, so ONLY that client's shows
  // may match — a conflicting show resolves to nothing (caller skips the row)
  // instead of silently landing under a different client.  Permissive mode
  // (no clientScopeId) keeps the old global fallback behaviour.
  final strict = clientScopeId != null && clientScopeId.isNotEmpty;
  String? targetClientId = clientScopeId;
  if (targetClientId == null || targetClientId.isEmpty) {
    for (final s in showsList) {
      if (s['showId'] == targetShowId) {
        targetClientId = s['clientId'];
        break;
      }
    }
  }

  // Compact form: lowercase + strip everything except a-z0-9.  This makes the
  // fuzzy step tolerant of punctuation/whitespace differences between the
  // Excel value and the DB show name (e.g. "KALSHI BEASTMODE_Pkg_1" vs
  // "Kalshi Beast Mode").
  String compact(String v) =>
      v.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  final rawCompact = compact(fileShowRaw);

  String? byExact(String clientId) {
    for (final s in showsList) {
      if (clientId.isNotEmpty && s['clientId'] != clientId) continue;
      if ((s['showName'] ?? '').trim().toLowerCase() == raw) {
        return s['showId'] ?? fallbackShowId;
      }
    }
    return null;
  }

  // 1 + 2. Exact name match (target client first, then — unless strict —
  // everything).
  final targetExact = byExact(targetClientId ?? '');
  if (targetExact != null) return targetExact;
  if (!strict) {
    final anyExact = byExact('');
    if (anyExact != null) return anyExact;
  }

  // 3. Exact showId match (client-scoped in strict mode).
  for (final s in showsList) {
    if (strict && s['clientId'] != targetClientId) continue;
    if ((s['showId'] ?? '').toLowerCase() == raw) {
      return s['showId'] ?? fallbackShowId;
    }
  }

  // 4. Fuzzy "contains" on compacted strings — target client first, longest
  // show name wins (so a package prefix resolves to its show, not to a shorter
  // similarly-named show).
  String? bestId;
  var bestLen = 0;
  for (final s in showsList) {
    if (targetClientId != null &&
        targetClientId.isNotEmpty &&
        s['clientId'] != targetClientId) {
      continue;
    }
    final name = (s['showName'] ?? '').trim().toLowerCase();
    final nameCompact = compact(name);
    if (nameCompact.length < 2) continue;
    if (rawCompact.contains(nameCompact) || nameCompact.contains(rawCompact)) {
      if (nameCompact.length > bestLen) {
        bestLen = nameCompact.length;
        bestId = s['showId'];
      }
    }
  }
  if (bestId != null) return bestId;
  if (strict) return fallbackShowId;
  if (targetClientId == null || targetClientId.isEmpty) {
    // No target client to scope by — the target-client pass above already
    // covered everything, so nothing more to do here.
    return fallbackShowId;
  }
  // No match within the target client — try every show the user has.
  for (final s in showsList) {
    final name = (s['showName'] ?? '').trim().toLowerCase();
    final nameCompact = compact(name);
    if (nameCompact.length < 2) continue;
    if (rawCompact.contains(nameCompact) || nameCompact.contains(rawCompact)) {
      if (nameCompact.length > bestLen) {
        bestLen = nameCompact.length;
        bestId = s['showId'];
      }
    }
  }
  return bestId ?? fallbackShowId;
}

/// Extracts the serializable clients list (id + name) from the raw
/// isolate-args `clients` value, as a plain list of string maps.
List<Map<String, String>> clientsListFromArgs(dynamic rawClients) {
  final out = <Map<String, String>>[];
  if (rawClients is! List) return out;
  for (final c in rawClients) {
    if (c is! Map) continue;
    final id = (c['clientId'] ?? '').toString().trim();
    final name = (c['clientName'] ?? '').toString().trim();
    if (id.isEmpty) continue;
    out.add(<String, String>{'clientId': id, 'clientName': name});
  }
  return out;
}

/// Resolves a value from the file's "Client" column to a real clientId.
///
///   1. exact case-insensitive client-name match
///   2. fuzzy "contains" match on compacted names, preferring the longest
///      client name
///
/// Returns '' when nothing matches — the caller decides whether that means
/// "don't scope show matching" or "skip the row".
String resolveClientId(
  String fileClientRaw,
  List<Map<String, String>> clientsList,
) {
  final raw = fileClientRaw.trim().toLowerCase();
  if (raw.isEmpty) return '';

  String compact(String v) =>
      v.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  final rawCompact = compact(fileClientRaw);

  // 1. Exact name match.
  for (final c in clientsList) {
    if ((c['clientName'] ?? '').trim().toLowerCase() == raw) {
      return c['clientId'] ?? '';
    }
  }

  // 2. Fuzzy "contains" on compacted strings, longest client name wins.
  String? bestId;
  var bestLen = 0;
  for (final c in clientsList) {
    final name = (c['clientName'] ?? '').trim().toLowerCase();
    final nameCompact = compact(name);
    if (nameCompact.length < 2) continue;
    if (rawCompact.contains(nameCompact) || nameCompact.contains(rawCompact)) {
      if (nameCompact.length > bestLen) {
        bestLen = nameCompact.length;
        bestId = c['clientId'];
      }
    }
  }
  return bestId ?? '';
}
