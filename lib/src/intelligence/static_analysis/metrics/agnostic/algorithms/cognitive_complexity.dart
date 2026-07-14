import 'agnostic_metric_algorithm.dart';
import 'token_scan.dart';
import '../lexer/token.dart';
import '../language_profile.dart';
import '../nesting_resolver.dart';

/// Calculates Cognitive Complexity following the SonarSource specification:
/// structural control flow scores `1 + nesting depth`, hybrid branches
/// (`else`, `elif`) score a flat +1 with no depth penalty, and boolean
/// operators score +1 per use.
///
/// Nesting depth comes from the [NestingResolver], so only control-flow
/// blocks and lambdas nest — function bodies, argument lists, and literal
/// brackets do not.
class CognitiveComplexityAlgorithm implements AgnosticMetricAlgorithm<int> {
  /// Branch continuations that score +1 flat and never carry a depth
  /// penalty. An `else if` / `else unless` pair scores once, not twice.
  static const Set<String> _hybridBranches = {
    'else',
    'elif',
    'elsif',
    'elseif',
  };

  /// Control-flow keywords that structure a construct already counted by
  /// another keyword (`do`-while counts at its `while`; `case`/`when` arms
  /// are covered by their `switch`) or that the specification does not
  /// increment (`try`, `finally`, `with`, jump helpers).
  static const Set<String> _noIncrement = {
    'do',
    'case',
    'when',
    'then',
    'try',
    'finally',
    'ensure',
    'with',
    'defer',
    'go',
    'retry',
  };

  @override
  int calculate(List<Token> tokens, LanguageProfile profile) {
    final resolution = NestingResolver(profile).resolve(tokens);
    var complexity = 0;
    final skip = <int>{};
    Token? prevSignificant;

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token.type == TokenType.newline) {
        continue;
      }

      if (token.type == TokenType.identifier) {
        final lexeme = token.lexeme;
        if (profile.isControlFlow(lexeme) &&
            !isPreprocessorKeyword(prevSignificant, token)) {
          if (_hybridBranches.contains(lexeme)) {
            complexity += 1;
            // `else if` is one branch: suppress the trailing keyword.
            final next = _nextSignificantIndex(tokens, i);
            if (next != -1 &&
                (tokens[next].lexeme == 'if' ||
                    tokens[next].lexeme == 'unless')) {
              skip.add(next);
            }
          } else if (!_noIncrement.contains(lexeme) && !skip.contains(i)) {
            complexity += 1 + resolution.depths[i];
          }
        } else if (profile.isOperatorKeyword(lexeme) &&
            (lexeme == 'and' || lexeme == 'or')) {
          complexity += 1;
        }
      } else if (token.type == TokenType.operator) {
        final lexeme = token.lexeme;
        if (lexeme == '&&' || lexeme == '||' || lexeme == '??') {
          complexity += 1;
        } else if (lexeme == '?' && isTernaryOperator(tokens, i)) {
          complexity += 1 + resolution.depths[i];
        }
      }

      prevSignificant = token;
    }

    return complexity;
  }

  int _nextSignificantIndex(List<Token> tokens, int from) {
    for (var j = from + 1; j < tokens.length; j++) {
      if (tokens[j].type != TokenType.newline) return j;
    }
    return -1;
  }
}
