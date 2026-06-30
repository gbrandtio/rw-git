import 'agnostic_metric_algorithm.dart';
import '../lexer/token.dart';
import '../language_profile.dart';

/// Calculates McCabe's Cyclomatic Complexity using a heuristic token-counting
/// approach based on the target language's profile.
class CyclomaticComplexityAlgorithm implements AgnosticMetricAlgorithm<int> {
  @override
  int calculate(List<Token> tokens, LanguageProfile profile) {
    int complexity = 1; // Base complexity

    for (final token in tokens) {
      if (token.type == TokenType.identifier) {
        if (profile.isControlFlow(token.lexeme)) {
          complexity++;
        }
      } else if (token.type == TokenType.operator) {
        // Many languages use && and || for logical branching
        if (token.lexeme == '&&' ||
            token.lexeme == '||' ||
            token.lexeme == '?') {
          complexity++;
        }
      }
    }

    return complexity;
  }
}
