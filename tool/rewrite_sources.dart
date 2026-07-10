import 'dart:io';

void main() {
  final dir = Directory('lib/src/intelligence/interpretation/classifiers');
  final map = {
    "'analyze_code_quality'": "[AnalysisType.codeQuality]",
    "'analyze_code_volatility'": "[AnalysisType.codeVolatility]",
    "'analyze_clean_code'": "[AnalysisType.cleanCode]",
    "'audit_compliance'": "[AnalysisType.auditCompliance]",
    "'calculate_universal_lexical_metrics'":
        "[AnalysisType.universalLexicalMetrics]",
    "'analyze_logical_coupling'": "[AnalysisType.logicalCoupling]",
    "'detect_secrets_in_commits'": "[AnalysisType.detectSecrets]",
    "'analyze_commit_velocity'": "[AnalysisType.commitVelocity]",
    "'analyze_architecture_drift'": "[AnalysisType.architectureDrift]",
    "'analyze_refactoring'": "[AnalysisType.refactoring]",
    "'analyze_bus_factor'": "[AnalysisType.busFactor]",
    "'analyze_dart_ast_quality'": "[AnalysisType.dartAstQuality]",
    "'analyze_file_ownership'": "[AnalysisType.fileOwnership]",
    "'analyze_bug_hotspots'": "[AnalysisType.bugHotspots]",
    "'analyze_dependency_drift'": "[AnalysisType.dependencyDrift]",
  };

  for (final file in dir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;

    var content = file.readAsStringSync();
    var changed = false;
    for (final entry in map.entries) {
      if (content.contains("source: ${entry.key}")) {
        content = content.replaceAll(
            "source: ${entry.key}", "source: ${entry.value}");
        changed = true;
      }
    }

    if (changed) {
      if (!content.contains('import \'../models/analysis_type.dart\';')) {
        content = "import '../models/analysis_type.dart';\n$content";
      }
      file.writeAsStringSync(content);
      print('Updated ${file.path}');
    }
  }
}
