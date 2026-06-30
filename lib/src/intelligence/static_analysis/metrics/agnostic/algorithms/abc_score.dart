import 'dart:math';

import 'agnostic_metric_algorithm.dart';
import '../lexer/token.dart';
import '../language_profile.dart';
import '../../models.dart';

/// Calculates the ABC Software Size Metric (Fitzpatrick, 1997).
///
/// The ABC score is a 3-vector (Assignments, Branches, Conditions).
/// Unlike Cyclomatic Complexity, ABC captures data-flow complexity (A) that
/// pure control-flow counting misses.
///
/// Thresholds per function: < 15 is good, > 30 signals over-complexity.
class AbcScoreAlgorithm implements AgnosticMetricAlgorithm<AbcScore> {
  static const _assignmentOps = {
    '=',
    '+=',
    '-=',
    '*=',
    '/=',
    '%=',
    '&=',
    '|=',
    '^=',
    '<<=',
    '>>=',
  };

  static const _comparisonOps = {
    '==',
    '!=',
    '<',
    '>',
    '<=',
    '>=',
    '===',
    '!==',
  };

  static const _logicalBranchOps = {'&&', '||', '?'};

  @override
  AbcScore calculate(List<Token> tokens, LanguageProfile profile) {
    int a = 0, b = 0, c = 0;

    for (final token in tokens) {
      if (token.type == TokenType.operator) {
        final lex = token.lexeme;
        // Assignment: must not overlap with comparisons (== is not =)
        if (_assignmentOps.contains(lex) && !_comparisonOps.contains(lex)) {
          a++;
        }
        if (_comparisonOps.contains(lex)) {
          c++;
        }
        if (_logicalBranchOps.contains(lex)) {
          b++;
        }
      }
      if (token.type == TokenType.identifier &&
          profile.isControlFlow(token.lexeme)) {
        b++;
      }
    }

    final score = sqrt(a * a + b * b + c * c);
    return AbcScore(
      assignments: a,
      branches: b,
      conditions: c,
      score: double.parse(score.toStringAsFixed(2)),
    );
  }
}
