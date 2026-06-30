import '../../../intelligence/static_analysis/metrics/agnostic/lexer/fsm_lexer.dart';
import '../../../intelligence/static_analysis/metrics/agnostic/profiles/default_profiles.dart';
import '../../../intelligence/static_analysis/metrics/agnostic/algorithms/maintainability_index.dart';
import '../../../intelligence/static_analysis/metrics/agnostic/algorithms/indentation_complexity.dart';
import '../../../intelligence/static_analysis/metrics/agnostic/algorithms/cognitive_complexity.dart';
import '../../../intelligence/static_analysis/metrics/agnostic/algorithms/halstead_complexity.dart';
import '../../../intelligence/static_analysis/metrics/agnostic/algorithms/cyclomatic_complexity.dart';
import '../../../intelligence/static_analysis/metrics/agnostic/algorithms/npath_complexity.dart';
import '../../../intelligence/static_analysis/metrics/agnostic/algorithms/abc_score.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

import '../../mcp_tool.dart';
import '../../utils/mcp_argument_extensions.dart';

/// MCP Tool that calculates language-agnostic code quality metrics
/// for any text-based source file using a high-performance FSM Lexer.
class CalculateUniversalLexicalMetricsTool implements McpTool {
  @override
  String get name => 'calculate_universal_lexical_metrics';

  @override
  String get description =>
      'Calculates language-agnostic code quality metrics (Cyclomatic, NPath, ABC, '
      'Halstead, Cognitive, Maintainability Index) for any source file using a '
      'fast Lexical FSM.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The absolute path to the repository root. '
                'Used to scope file access and prevent path traversal.',
          },
          'file_path': {
            'type': 'string',
            'description': 'Path to the source file to analyze, absolute or '
                'relative to directory.',
          },
        },
        'required': ['directory', 'file_path'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final filePath = arguments.getStringArgument('file_path');

    final canonicalDir = p.canonicalize(directory);
    final resolvedPath = p.isAbsolute(filePath)
        ? p.canonicalize(filePath)
        : p.canonicalize(p.join(directory, filePath));

    if (!p.isWithin(canonicalDir, resolvedPath)) {
      return jsonEncode({
        'error': 'file_path must resolve within directory.',
      });
    }

    final file = File(resolvedPath);

    if (!file.existsSync()) {
      return jsonEncode({'error': 'File not found at path: $resolvedPath'});
    }

    final source = await file.readAsString();

    // Load language profile based on file extension
    final profile = DefaultProfiles.getProfileForFile(resolvedPath);

    // Tokenize using FSM (Zero-allocation masking)
    final lexer = FsmLexer(source);
    final tokens = lexer.tokenize();

    // Run heuristics
    final cyclomatic =
        CyclomaticComplexityAlgorithm().calculate(tokens, profile);
    final npath = NpathComplexityAlgorithm().calculate(tokens, profile);
    final abc = AbcScoreAlgorithm().calculate(tokens, profile);
    final halstead = HalsteadComplexityAlgorithm().calculate(tokens, profile);
    final cognitive = CognitiveComplexityAlgorithm().calculate(tokens, profile);
    final indentation =
        IndentationComplexityAlgorithm().calculate(tokens, profile);
    final maintainability =
        MaintainabilityIndexAlgorithm().calculate(tokens, profile);

    return jsonEncode({
      'language_profile': profile.name,
      'cyclomatic_complexity': cyclomatic,
      'npath_complexity': npath,
      'abc_score': abc.toJson(),
      'cognitive_complexity': cognitive,
      'indentation_complexity': indentation,
      'halstead_metrics': halstead.toJson(),
      'maintainability_index': maintainability.toJson(),
    });
  }
}
