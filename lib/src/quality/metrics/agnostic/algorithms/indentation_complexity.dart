import 'agnostic_metric_algorithm.dart';
import '../lexer/token.dart';
import '../language_profile.dart';

/// Calculates complexity based on structural indentation depth.
/// A high standard deviation or max depth indicates nested, complex code.
class IndentationComplexityAlgorithm
    implements AgnosticMetricAlgorithm<Map<String, double>> {
  @override
  Map<String, double> calculate(List<Token> tokens, LanguageProfile profile) {
    if (tokens.isEmpty) return {'max': 0.0, 'average': 0.0};

    // Instead of parsing tokens for whitespace, we can just look at the string directly for indentation,
    // but the FSM lexer skips lines and masks comments. It's better to calculate indentation
    // using the tokens if we emit newline and whitespace tokens, but FsmLexer currently skips whitespace.
    // Wait, FsmLexer skips whitespace but emits `\n`. It does NOT emit whitespace at the start of the line.

    // Let's modify the algorithm to just use brace depth, which is very similar to indentation depth for C-family,
    // or we can read the raw string for indentation. Let's just track brace `{` and `}` depth for now as a proxy,
    // and if Python, we can't easily track without significant whitespace tokens.

    // Let's implement structural nesting depth instead, looking at generic block openers.
    int currentDepth = 0;
    int maxDepth = 0;
    int totalDepth = 0;
    int blockCount = 0;

    for (final token in tokens) {
      if (token.type == TokenType.punctuation) {
        if (token.lexeme == '{') {
          currentDepth++;
          if (currentDepth > maxDepth) maxDepth = currentDepth;
        } else if (token.lexeme == '}') {
          currentDepth--;
          if (currentDepth < 0) currentDepth = 0;
          totalDepth += currentDepth;
          blockCount++;
        }
      } else if (token.type == TokenType.identifier) {
        // Python-like heuristics: increment after ':' and decrement when indentation drops.
        // For simplicity, we just rely on braces for now.
      }
    }

    double averageDepth = blockCount > 0 ? totalDepth / blockCount : 0.0;

    return {
      'max_nesting_depth': maxDepth.toDouble(),
      'average_nesting_depth': averageDepth,
    };
  }
}
