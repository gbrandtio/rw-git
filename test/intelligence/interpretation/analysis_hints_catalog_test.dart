import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// Every research-grounded tool must carry static [ToolHints] guidance so a
/// calling model gets literature thresholds, known limitations, and
/// complementary-tool suggestions without inventing them. These tests encode
/// the catalog's coverage and budget invariants; see
/// `test/intelligence/interpretation/finding_basis_test.dart` for the
/// equivalent contract on per-finding `basis`/`rationale`.
void main() {
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
    registeredToolNames = registry
        .getToolListings()
        .map((t) => t['name'] as String)
        .toSet();
  });

  test('every registered analysis tool has a catalog entry', () {
    final analysisTools = registeredToolNames.difference(toolsWithoutHints);
    for (final name in analysisTools) {
      final type = analysisTypeForMcpTool[name];
      expect(type, isNotNull, reason: '$name has no AnalysisType mapping');
      expect(
        analysisHintsCatalog.containsKey(type),
        isTrue,
        reason: '$name is registered but missing from analysisHintsCatalog',
      );
    }
  });

  test('every catalog key names a registered tool', () {
    for (final type in analysisHintsCatalog.keys) {
      if (type == AnalysisType.compound) continue;
      final name = mcpToolNameForAnalysis[type];
      expect(name, isNotNull, reason: '$type has no MCP tool mapping');
      expect(
        registeredToolNames.contains(name),
        isTrue,
        reason:
            "analysisHintsCatalog has an entry for '$type', which is not "
            'a registered tool name',
      );
    }
  });

  test('no tool without academic basis has a catalog entry', () {
    for (final name in toolsWithoutHints) {
      final type = analysisTypeForMcpTool[name];
      if (type != null) {
        expect(
          analysisHintsCatalog.containsKey(type),
          isFalse,
          reason:
              "'$name' has no academic basis and should not carry "
              'invented hints',
        );
      }
    }
  });

  group('per-tool hint budgets', () {
    for (final entry in analysisHintsCatalog.entries) {
      final name = mcpToolNameForAnalysis[entry.key] ?? entry.key.name;
      final hints = entry.value;
      final all = [
        ...hints.interpretation,
        ...hints.caveats,
        ...hints.pairWith,
      ];

      test('$name has at least one hint', () {
        expect(all, isNotEmpty, reason: '$name has an empty ToolHints entry');
      });

      test('$name interpretation hints carry a citation year', () {
        if (hints.interpretation.isEmpty) {
          return;
        }
        final hasCitation = hints.interpretation.any(
          (hint) => citationYearPattern.hasMatch(hint),
        );
        expect(
          hasCitation,
          isTrue,
          reason: '$name interpretation hints lack any citation year.',
        );
      });

      test('$name pair_with hints name a registered tool', () {
        if (hints.pairWith.isEmpty || entry.key == AnalysisType.compound) {
          return;
        }
        final hasRegisteredTool = hints.pairWith.any(
          (hint) =>
              registeredToolNames.any((toolName) => hint.contains(toolName)),
        );
        expect(
          hasRegisteredTool,
          isTrue,
          reason: "$name pair_with hints don't mention a registered tool name.",
        );
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
