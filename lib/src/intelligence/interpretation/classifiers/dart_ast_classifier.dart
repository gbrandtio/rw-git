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

  List<Finding> classifyImportCycles(List<List<String>> cycles) {
    final findings = <Finding>[];
    for (final cycle in cycles) {
      final normalizedMembers = cycle.map(PathKey.normalize).toList()..sort();
      findings.add(
        Finding(
          category: 'dartAst',
          source: [AnalysisType.dartAstQuality],
          severity: Severity.high,
          subject: normalizedMembers.first,
          metric: 'import_cycle',
          value: normalizedMembers.length,
          band: 'circular import chain',
          evidence: {'cycle_members': normalizedMembers},
        ),
      );
    }
    return findings;
  }
}
