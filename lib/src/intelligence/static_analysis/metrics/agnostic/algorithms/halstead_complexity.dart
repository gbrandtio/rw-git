import 'dart:math';

import 'agnostic_metric_algorithm.dart';
import '../lexer/token.dart';
import '../language_profile.dart';
import '../../models.dart';

/// Calculates Halstead Complexity Measures using a universal token classification
/// strategy.
class HalsteadComplexityAlgorithm
    implements AgnosticMetricAlgorithm<HalsteadResult> {
  @override
  HalsteadResult calculate(List<Token> tokens, LanguageProfile profile) {
    int totalOperators = 0;
    int totalOperands = 0;
    final uniqueOperators = <String>{};
    final uniqueOperands = <String>{};

    for (final token in tokens) {
      if (token.type == TokenType.operator ||
          token.type == TokenType.punctuation) {
        totalOperators++;
        uniqueOperators.add(token.lexeme);
      } else if (token.type == TokenType.identifier) {
        if (profile.isControlFlow(token.lexeme) ||
            profile.isOperatorKeyword(token.lexeme) ||
            profile.isStructuralAnchor(token.lexeme)) {
          totalOperators++;
          uniqueOperators.add(token.lexeme);
        } else {
          totalOperands++;
          uniqueOperands.add(token.lexeme);
        }
      } else if (token.type == TokenType.number) {
        totalOperands++;
        uniqueOperands.add(token.lexeme);
      }
    }

    final n1 = uniqueOperators.length;
    final n2 = uniqueOperands.length;
    final totalN1 = totalOperators;
    final totalN2 = totalOperands;

    final vocabulary = n1 + n2;
    final length = totalN1 + totalN2;

    double volume = 0.0;
    if (vocabulary > 0) {
      volume = length * (log(vocabulary) / ln2);
    }

    double difficulty = 0.0;
    if (n2 > 0) {
      difficulty = (n1 / 2) * (totalN2 / n2);
    }

    final effort = difficulty * volume;

    return HalsteadResult(
      vocabulary: vocabulary,
      length: length,
      volume: volume,
      difficulty: difficulty,
      effort: effort,
      timeRequired: effort / 18.0,
      deliveredBugs: volume / 3000.0,
    );
  }
}
