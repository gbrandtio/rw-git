import 'agnostic_metric_algorithm.dart';
import '../lexer/token.dart';
import '../language_profile.dart';

/// Calculates Cognitive Complexity, which heavily penalizes deeply nested
/// control flow structures.
class CognitiveComplexityAlgorithm implements AgnosticMetricAlgorithm<int> {
  @override
  int calculate(List<Token> tokens, LanguageProfile profile) {
    int complexity = 0;
    int nestingDepth = 0;

    for (final token in tokens) {
      if (token.type == TokenType.punctuation) {
        if (token.lexeme == '{' || token.lexeme == '[' || token.lexeme == '(') {
          nestingDepth++;
        } else if (token.lexeme == '}' ||
            token.lexeme == ']' ||
            token.lexeme == ')') {
          nestingDepth--;
          if (nestingDepth < 0) nestingDepth = 0;
        }
      } else if (token.type == TokenType.identifier) {
        if (profile.isControlFlow(token.lexeme)) {
          // Add 1 for the branch itself, plus an increment for its nesting depth.
          complexity += 1 + nestingDepth;
        }
      } else if (token.type == TokenType.operator) {
        if (token.lexeme == '&&' || token.lexeme == '||') {
          complexity +=
              1; // Logical operators add complexity but aren't penalized by depth in the same way as structural loops.
        }
      }
    }

    return complexity;
  }
}
