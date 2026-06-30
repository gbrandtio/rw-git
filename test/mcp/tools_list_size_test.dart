import 'dart:convert';

import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// Guards the headline business requirement: the `tools/list` payload — the
/// fixed cost every (small) LLM conversation pays up-front — must stay small.
///
/// The decorator deliberately keeps its per-tool augmentation terse and defers
/// the full offload contract to `get_rw_git_documentation`. This test fails if
/// that discipline regresses (e.g. a verbose paragraph creeps back onto every
/// tool description).
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
      // The pre-trim payload was ~43KB (~12k tokens). After deferring the
      // offload contract to get_rw_git_documentation it is ~30KB (~8.4k
      // tokens). This ceiling guarantees we stay meaningfully below the old
      // state even after adding standard tool metadata (annotations /
      // compact outputSchema), leaving working room for 16-32K local windows.
      const budgetBytes = 35000;
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
