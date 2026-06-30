import 'agnostic_metric_algorithm.dart';
import '../lexer/token.dart';
import '../language_profile.dart';

/// Approximates NPath Complexity (Nejmeh, 1988).
///
/// NPath counts acyclic execution paths through a function. Here we model it
/// as 2^decisions, where each branch point doubles the number of paths. This
/// captures the exponential path explosion that makes high-NPath code
/// effectively untestable.
///
/// Threshold: NPath > 200 (≈ decisions > 7) indicates a function that requires
/// more test cases than a team can realistically write.
class NpathComplexityAlgorithm implements AgnosticMetricAlgorithm<int> {
  @override
  int calculate(List<Token> tokens, LanguageProfile profile) {
    int decisions = 0;

    for (final token in tokens) {
      if (token.type == TokenType.identifier &&
          profile.isControlFlow(token.lexeme)) {
        // 'else' and 'catch' share the path of an existing branch; they do not
        // introduce a new independent path.
        if (token.lexeme != 'else' && token.lexeme != 'catch') {
          decisions++;
        }
      } else if (token.type == TokenType.operator &&
          (token.lexeme == '&&' ||
              token.lexeme == '||' ||
              token.lexeme == '?')) {
        decisions++;
      }
    }

    // Clamp at 2^30 to prevent integer overflow; any value above ~30 is
    // already astronomically untestable (> 10^9 unique paths).
    if (decisions >= 30) return 1 << 30;
    return decisions == 0 ? 1 : 1 << decisions;
  }
}
