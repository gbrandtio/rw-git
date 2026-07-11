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
/// tool description). `outputSchema` is advertised only where the shape is
/// stable and drives `structuredContent` (ADR-0013): the report meta-tools,
/// tiny git-operation results, and a handful of fixed-shape tools — the
/// response-time offload `preview` conveys structure for every other tool at
/// zero fixed cost.
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
      // History of the fixed up-front cost: ~43KB pre-trim (~12k tokens),
      // ~30KB after deferring the offload contract to
      // get_rw_git_documentation, ~41KB after outputSchema was stamped onto
      // nearly every tool, ~35.6KB (~10k tokens) after ADR-0013 restricted
      // outputSchema to stable shapes that actually drive structuredContent
      // (report meta-tools, tiny git-op results, a few fixed-shape tools).
      // The ceiling leaves ~12% headroom above that measured baseline for a
      // handful of future additions while guarding against verbose
      // descriptions or broad schemas creeping back in.
      const budgetBytes = 40000;
      expect(
        bytes,
        lessThan(budgetBytes),
        reason:
            'tools/list grew to $bytes bytes (budget $budgetBytes). '
            'Keep per-tool descriptions terse and defer detail to '
            'get_rw_git_documentation.',
      );
    });

    test(
      'decorator does not re-stamp the verbose offload paragraph per tool',
      () {
        // The long explanation must live in one place, not be duplicated across
        // every offloaded tool description.
        final occurrences = 'return_full_json: true'
            .allMatches(serialized)
            .length;
        expect(occurrences, lessThanOrEqualTo(1));
      },
    );
  });
}
