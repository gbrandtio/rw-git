import 'agnostic_metric_algorithm.dart';
import '../lexer/token.dart';
import '../language_profile.dart';
import '../nesting_resolver.dart';

/// Approximates NPath Complexity (Nejmeh, 1988).
///
/// NPath counts acyclic execution paths through a function. It uses the
/// [NestingResolver] to differentiate between sequential decisions (which multiply
/// paths) and nested decisions (which add acyclic paths to their branch).
///
/// Threshold: NPath > 200 indicates a function that requires more test cases
/// than a team can realistically write.
class NpathComplexityAlgorithm implements AgnosticMetricAlgorithm<int> {
  @override
  int calculate(List<Token> tokens, LanguageProfile profile) {
    if (tokens.isEmpty) return 1;

    final resolution = NestingResolver(profile).resolve(tokens);
    final depths = resolution.depths;

    // pathsAtDepth[d] tracks the path multiplier at depth d.
    // Sequential blocks multiply paths; nested decisions add alternative paths.
    final List<int> pathsAtDepth = [1];
    var currentDepth = 0;

    for (var i = 0; i < tokens.length; i++) {
      final d = depths[i];

      // If we dedented, the nested block adds its paths to the parent depth,
      // minus 1 (since the parent decision already assumes 1 path for the true branch).
      while (currentDepth > d) {
        pathsAtDepth[currentDepth - 1] += pathsAtDepth[currentDepth] - 1;
        pathsAtDepth[currentDepth] = 1; // reset for future use
        currentDepth--;
      }

      // If we indented, ensure our stack is deep enough.
      while (currentDepth < d) {
        if (pathsAtDepth.length <= currentDepth + 1) {
          pathsAtDepth.add(1);
        }
        currentDepth++;
      }

      final token = tokens[i];
      if (token.type == TokenType.identifier &&
          profile.isControlFlow(token.lexeme)) {
        // 'else' and 'catch' share the path of an existing branch; they do not
        // introduce a new independent path.
        if (token.lexeme != 'else' && token.lexeme != 'catch') {
          // Sequential decisions multiply the current depth's paths.
          pathsAtDepth[currentDepth] *= 2;
        }
      } else if (token.type == TokenType.operator &&
          (token.lexeme == '&&' ||
              token.lexeme == '||' ||
              token.lexeme == '?')) {
        pathsAtDepth[currentDepth] += 1;
      }
    }

    // Fold any remaining depths back to 0
    while (currentDepth > 0) {
      pathsAtDepth[currentDepth - 1] += pathsAtDepth[currentDepth] - 1;
      currentDepth--;
    }

    final totalPaths = pathsAtDepth[0];
    // Clamp at 2^30 to prevent integer overflow; any value above ~30 decisions
    // is already astronomically untestable (> 10^9 unique paths).
    if (totalPaths >= (1 << 30)) return 1 << 30;
    return totalPaths == 0 ? 1 : totalPaths;
  }
}
