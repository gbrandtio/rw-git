import 'dart:convert';

import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// Guards the headline business requirement: the `tools/list` payload — the
/// fixed cost every (small) LLM conversation pays up-front — must stay
/// bounded.
///
/// The decorator deliberately keeps its per-tool augmentation terse and defers
/// the full offload contract to `get_rw_git_documentation`. This test fails if
/// that discipline regresses (e.g. a verbose paragraph creeps back onto every
/// tool description). Nearly every tool also advertises a compact
/// `outputSchema` (ADR: expand structural hints so a model can anticipate an
/// offloaded file's shape without reading it) — that is the largest
/// contributor to the payload size, so the budget below is set relative to
/// that fuller baseline rather than the pre-outputSchema one.
void main() {
  group('tools/list payload size', () {
    final registry = buildDefaultRegistry(runner: MockProcessRunner());
    final listings = registry.getToolListings();
    final serialized = jsonEncode(listings);

    test('exposes the full tool surface', () {
      // Sanity check so a future accidental drop of tools does not make the
      // size assertion trivially pass.
      expect(listings.length, greaterThanOrEqualTo(30));
    });

    test('serialized payload stays within the small-context budget', () {
      final bytes = utf8.encode(serialized).length;
      // The pre-trim payload was ~43KB (~12k tokens); after deferring the
      // offload contract to get_rw_git_documentation it dropped to ~30KB.
      // Nearly every tool now advertises a compact outputSchema (so a model
      // can anticipate an offloaded file's structure without reading it),
      // which raised the measured baseline to ~41KB (~11.5k tokens) as of
      // this writing. The ceiling below leaves roughly 15% headroom above
      // that baseline for a handful of future additions, while still
      // guarding against unbounded growth (e.g. verbose descriptions or
      // schemas creeping back in) — this is a materially larger budget than
      // the original ~30KB target, so it still leaves working room for
      // 16-32K local windows but with less slack than before.
      const budgetBytes = 48000;
      expect(bytes, lessThan(budgetBytes),
          reason: 'tools/list grew to $bytes bytes (budget $budgetBytes). '
              'Keep per-tool descriptions terse and defer detail to '
              'get_rw_git_documentation.');
    });

    test('decorator does not re-stamp the verbose offload paragraph per tool',
        () {
      // The long explanation must live in one place, not be duplicated across
      // every offloaded tool description.
      final occurrences =
          'return_full_json: true'.allMatches(serialized).length;
      expect(occurrences, lessThanOrEqualTo(1));
    });
  });
}
