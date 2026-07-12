import 'agnostic_metric_algorithm.dart';
import '../lexer/token.dart';
import '../language_profile.dart';
import '../nesting_resolver.dart';

/// Reports the control-flow nesting-depth distribution of the token stream:
/// the deepest nesting reached and the average depth at which nested blocks
/// open. High values indicate deeply nested, hard-to-read code.
///
/// Depth comes from the shared [NestingResolver], so it reflects genuine
/// control-flow nesting (including indentation-structured and
/// keyword-terminated languages), not raw brace counting.
class IndentationComplexityAlgorithm
    implements AgnosticMetricAlgorithm<Map<String, double>> {
  @override
  Map<String, double> calculate(List<Token> tokens, LanguageProfile profile) {
    if (tokens.isEmpty) {
      return {'max_nesting_depth': 0.0, 'average_nesting_depth': 0.0};
    }

    final resolution = NestingResolver(profile).resolve(tokens);

    return {
      'max_nesting_depth': resolution.maxDepth.toDouble(),
      'average_nesting_depth': resolution.averageFrameDepth,
    };
  }
}
