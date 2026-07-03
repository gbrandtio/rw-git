import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// Every research-grounded tool must carry static [ToolHints] guidance so a
/// calling model gets literature thresholds, known limitations, and
/// complementary-tool suggestions without inventing them. These tests encode
/// the catalog's coverage and budget invariants; see
/// `test/intelligence/interpretation/finding_basis_test.dart` for the
/// equivalent contract on per-finding `basis`/`rationale`.
void main() {
  /// Recurring token cost per hint: a value this high already synthesizes
  /// several citations into one claim (D6) — beyond this, growth should be
  /// split into a new, distinct hint rather than one ballooning string.
  const int maximumHintLengthInCharacters = 600;

  const int maximumHintsPerTool = 6;

  final citationYearPattern = RegExp(r'\b(19|20)\d{2}\b');

  // Core git and pure-retrieval tools carry no academic basis to cite, so
  // they are deliberately absent from the catalog (see D12 in the plan).
  const toolsWithoutHints = {
    'clone_repository',
    'clone_specific_branch',
    'checkout_branch',
    'init_repository',
    'is_git_repository',
    'fetch_tags',
    'get_rw_git_documentation',
    'read_report_slice',
    // Report meta-tools: hints are aggregated at the report-payload level
    // from the catalog entries of the analyses each report runs.
    'generate_repository_audit',
    'generate_technical_report',
    'generate_security_report',
    'generate_pm_report',
    'generate_code_review_report',
  };

  late Set<String> registeredToolNames;

  setUpAll(() {
    final registry = buildDefaultRegistry();
    registeredToolNames =
        registry.getToolListings().map((t) => t['name'] as String).toSet();
  });

  test('every registered analysis tool has a catalog entry', () {
    final analysisTools = registeredToolNames.difference(toolsWithoutHints);
    for (final name in analysisTools) {
      expect(toolHintsCatalog.containsKey(name), isTrue,
          reason: '$name is registered but missing from toolHintsCatalog');
    }
  });

  test('every catalog key names a registered tool', () {
    for (final name in toolHintsCatalog.keys) {
      expect(registeredToolNames.contains(name), isTrue,
          reason: "toolHintsCatalog has an entry for '$name', which is not "
              'a registered tool name');
    }
  });

  test('no tool without academic basis has a catalog entry', () {
    for (final name in toolsWithoutHints) {
      expect(toolHintsCatalog.containsKey(name), isFalse,
          reason: "'$name' has no academic basis and should not carry "
              'invented hints');
    }
  });

  group('per-tool hint budgets', () {
    for (final entry in toolHintsCatalog.entries) {
      final name = entry.key;
      final hints = entry.value;
      final all = [
        ...hints.interpretation,
        ...hints.caveats,
        ...hints.pairWith
      ];

      test('$name stays within the hint-count and length budget', () {
        expect(all.length, lessThanOrEqualTo(maximumHintsPerTool),
            reason: '$name has ${all.length} hints, exceeding the budget');
        for (final hint in all) {
          expect(hint.length, lessThanOrEqualTo(maximumHintLengthInCharacters),
              reason: '$name hint exceeds the inline token budget: $hint');
        }
      });

      test('$name has at least one hint', () {
        expect(all, isNotEmpty, reason: '$name has an empty ToolHints entry');
      });

      test('$name interpretation hints carry a citation year', () {
        for (final hint in hints.interpretation) {
          expect(hint, matches(citationYearPattern),
              reason: '$name interpretation hint lacks a citation year: '
                  '$hint');
        }
      });

      test('$name pair_with hints name a registered tool', () {
        for (final hint in hints.pairWith) {
          final mentionsRegisteredTool =
              registeredToolNames.any((toolName) => hint.contains(toolName));
          expect(mentionsRegisteredTool, isTrue,
              reason: "$name pair_with hint doesn't mention a registered "
                  'tool name: $hint');
        }
      });
    }
  });

  group('ToolHints.toJson', () {
    test('omits empty categories', () {
      const hints = ToolHints(interpretation: ['x (Author 2020)']);
      final json = hints.toJson();
      expect(json.containsKey('interpretation'), isTrue);
      expect(json.containsKey('caveats'), isFalse);
      expect(json.containsKey('pair_with'), isFalse);
    });

    test('includes all populated categories', () {
      const hints = ToolHints(
        interpretation: ['i (A 2020)'],
        caveats: ['c'],
        pairWith: ['p'],
      );
      final json = hints.toJson();
      expect(json['interpretation'], ['i (A 2020)']);
      expect(json['caveats'], ['c']);
      expect(json['pair_with'], ['p']);
    });
  });
}
