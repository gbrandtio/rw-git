import 'dart:io';
import 'dart:convert';

import '../mcp_tool.dart';
import '../../quality/metrics/agnostic/lexer/fsm_lexer.dart';
import '../../quality/metrics/agnostic/profiles/default_profiles.dart';
import '../../quality/metrics/agnostic/algorithms/cyclomatic_complexity.dart';
import '../../quality/metrics/agnostic/algorithms/halstead_complexity.dart';
import '../../quality/metrics/agnostic/algorithms/cognitive_complexity.dart';
import '../../quality/metrics/agnostic/algorithms/indentation_complexity.dart';
import '../../quality/metrics/agnostic/algorithms/maintainability_index.dart';
import '../utils/mcp_argument_extensions.dart';

/// MCP Tool that calculates language-agnostic code quality metrics
/// for any text-based source file using a high-performance FSM Lexer.
class CalculateUniversalLexicalMetricsTool implements McpTool {
  @override
  String get name => 'calculate_universal_lexical_metrics';

  @override
  String get description =>
      'Calculates language-agnostic code quality metrics (Cyclomatic, Halstead, '
      'Cognitive, Maintainability Index) for any source file using a fast Lexical FSM.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'file_path': {
            'type': 'string',
            'description': 'Absolute path to the source file to analyze.',
          },
        },
        'required': ['file_path'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final filePath = arguments.getStringArgument('file_path');
    final file = File(filePath);

    if (!file.existsSync()) {
      return jsonEncode({'error': 'File not found at path: $filePath'});
    }

    final source = await file.readAsString();

    // Load language profile based on file extension
    final profile = DefaultProfiles.getProfileForFile(filePath);

    // Tokenize using FSM (Zero-allocation masking)
    final lexer = FsmLexer(source);
    final tokens = lexer.tokenize();

    // Run heuristics
    final cyclomatic =
        CyclomaticComplexityAlgorithm().calculate(tokens, profile);
    final halstead = HalsteadComplexityAlgorithm().calculate(tokens, profile);
    final cognitive = CognitiveComplexityAlgorithm().calculate(tokens, profile);
    final indentation =
        IndentationComplexityAlgorithm().calculate(tokens, profile);
    final maintainability =
        MaintainabilityIndexAlgorithm().calculate(tokens, profile);

    return jsonEncode({
      'language_profile': profile.name,
      'cyclomatic_complexity': cyclomatic,
      'cognitive_complexity': cognitive,
      'indentation_complexity': indentation,
      'halstead_metrics': halstead.toJson(),
      'maintainability_index': maintainability.toJson(),
    });
  }
}
