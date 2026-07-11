import 'dart:math';

import 'agnostic_metric_algorithm.dart';
import '../lexer/token.dart';
import '../language_profile.dart';
import '../../models.dart';
import 'halstead_complexity.dart';
import 'cyclomatic_complexity.dart';

/// Calculates the Maintainability Index (MI) using the standard SEI formula.
/// MI = max(0, (171 - 5.2 * ln(V) - 0.23 * G - 16.2 * ln(LOC)) * 100 / 171)
class MaintainabilityIndexAlgorithm
    implements AgnosticMetricAlgorithm<MaintainabilityResult> {
  final HalsteadComplexityAlgorithm _halsteadAlgorithm =
      HalsteadComplexityAlgorithm();
  final CyclomaticComplexityAlgorithm _cyclomaticAlgorithm =
      CyclomaticComplexityAlgorithm();

  @override
  MaintainabilityResult calculate(List<Token> tokens, LanguageProfile profile) {
    if (tokens.isEmpty) {
      return const MaintainabilityResult(
        score: 100.0,
        category: 'Highly Maintainable',
      );
    }

    final halstead = _halsteadAlgorithm.calculate(tokens, profile);
    final cyclomatic = _cyclomaticAlgorithm.calculate(tokens, profile);

    // Count LOC by iterating over newline tokens.
    // Since FsmLexer emits \n tokens for unmasked code, this represents SLOC (Source Lines of Code).
    int loc = tokens.where((t) => t.type == TokenType.newline).length;
    if (loc == 0) loc = 1;

    final double v = halstead.volume;
    final int g = cyclomatic;

    double lnV = v > 0 ? log(v) : 0;
    double lnLoc = log(loc);

    double mi = (171.0 - 5.2 * lnV - 0.23 * g - 16.2 * lnLoc) * 100.0 / 171.0;
    mi = max(0.0, mi); // Cap at 0

    String category;
    if (mi >= 85) {
      category = 'Highly Maintainable';
    } else if (mi >= 65) {
      category = 'Moderate';
    } else {
      category = 'Low / Needs Refactoring';
    }

    return MaintainabilityResult(
      score: double.parse(mi.toStringAsFixed(2)),
      category: category,
    );
  }
}
