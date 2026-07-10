/// ----------------------------------------------------------------------------
/// dart_ast_classifier.dart
/// ----------------------------------------------------------------------------
library;

import '../models/analysis_type.dart';

import '../models/finding.dart';
import '../utils/path_key.dart';
import '../models/severity.dart';

/// Classifies Dart AST analysis into findings: each circular import chain
/// detected by Tarjan's strongly-connected-components algorithm (Tarjan
/// 1972) bands High — a cycle makes every member file unbuildable,
/// untestable, and unreleasable in isolation (Lakhotia 1993; Martin's
/// Acyclic Dependencies Principle).
class DartAstClassifier {
  const DartAstClassifier();

  /// Compact citation tag carried inline on every finding.
  static const String researchBasis =
      'Import-cycle detection via Tarjan SCC (Tarjan 1972; Lakhotia 1993)';

  /// Fuller research rationale carried only in the offloaded full report.
  static const String researchRationale =
      'A circular import chain fuses its member files into one inseparable '
      'unit: none can be compiled, tested, or reused without all the '
      'others, and a change to any propagates to every member (Lakhotia '
      '1993). Tarjan (1972) finds every such strongly connected component '
      'in linear time. Break a cycle by extracting the shared types into a '
      'module all members can depend on.';

  List<Finding> classifyImportCycles(List<List<String>> cycles) {
    final findings = <Finding>[];
    for (final cycle in cycles) {
      final normalizedMembers = cycle.map(PathKey.normalize).toList()..sort();
      findings.add(Finding(
        category: 'dartAst',
        source: [AnalysisType.dartAstQuality],
        severity: Severity.high,
        subject: normalizedMembers.first,
        metric: 'import_cycle',
        value: normalizedMembers.length,
        band: 'circular import chain',
        basis: researchBasis,
        rationale: researchRationale,
        message: '${normalizedMembers.length} files form a circular import '
            'chain: ${normalizedMembers.join(' -> ')}. Extract the shared '
            'types into a separate module to break the cycle.',
        evidence: {'cycle_members': normalizedMembers},
      ));
    }
    return findings;
  }
}
