/// Canonical worker/bin area matching used by every worker-facing screen
/// (map, home stats, route orphan bins). Keep this file as the single source
/// of truth — if you tweak the matching rule, every screen picks it up.
///
/// Rules (all comparisons are case-insensitive and trimmed):
///   1. A bin with empty area is NEVER shown to an assigned worker.
///   2. Exact equality matches.
///   3. Hierarchy match via word boundaries — worker "G-9" matches bin
///      "Islamabad G-9" and "G-9 Markaz", but worker "Wah" does NOT match
///      bin "Wahdat Colony".
///   4. Match is bidirectional so a worker tagged with the full address
///      ("DHA, Lahore") still matches a bin tagged only with the city
///      ("Lahore").
library;

bool areaMatches(String? binAreaRaw, String? workerAreaRaw) {
  final binArea    = (binAreaRaw    ?? '').trim().toLowerCase();
  final workerArea = (workerAreaRaw ?? '').trim().toLowerCase();

  // Worker has no assignment yet — caller decides what to do (usually a
  // proximity fallback). Return false so this helper never silently
  // approves everything.
  if (workerArea.isEmpty) return false;

  // Hide untagged bins from assigned workers — admin must tag the bin first.
  if (binArea.isEmpty) return false;

  if (binArea == workerArea) return true;

  final wPattern = RegExp(r'\b' + RegExp.escape(workerArea) + r'\b');
  if (wPattern.hasMatch(binArea)) return true;

  final bPattern = RegExp(r'\b' + RegExp.escape(binArea) + r'\b');
  if (bPattern.hasMatch(workerArea)) return true;

  return false;
}

/// Pull a bin's area string out of a raw Firestore map, preferring the
/// canonical `area` field and falling back to legacy `sector`. Empty string
/// returns are treated the same as null by [areaMatches].
String readBinArea(Map<String, dynamic> data) {
  final a = (data['area'] as String?)?.trim();
  if (a != null && a.isNotEmpty) return a;
  final s = (data['sector'] as String?)?.trim();
  return s ?? '';
}
