import '../../../models/file_lexical_metrics_dto.dart';
import 'agnostic/algorithms/abc_score.dart';
import 'agnostic/algorithms/cognitive_complexity.dart';
import 'agnostic/algorithms/cyclomatic_complexity.dart';
import 'agnostic/algorithms/halstead_complexity.dart';
import 'agnostic/algorithms/maintainability_index.dart';
import 'agnostic/algorithms/npath_complexity.dart';
import 'agnostic/language_profile.dart';
import 'agnostic/lexer/fsm_lexer.dart';
import 'agnostic/profiles/default_profiles.dart';

/// A synchronous facade for executing the lexical metrics suite on a single file.
/// This allows 3rd-party consumers to easily calculate all complexity metrics
/// without managing isolates or dealing with git-churn sampling logic.
class LexicalMetricsRunner {
  /// Computes all supported lexical complexity metrics for the given [sourceCode].
  ///
  /// The [filePath] is used to infer the [LanguageProfile] if [profile] is not
  /// provided. You can override the default profile by passing your own [profile].
  static FileLexicalMetricsDto execute(
    String filePath,
    String sourceCode, {
    LanguageProfile? profile,
  }) {
    final activeProfile =
        profile ?? DefaultProfiles.getProfileForFile(filePath);
    final tokens = FsmLexer(sourceCode).tokenize();

    return FileLexicalMetricsDto(
      filePath: filePath,
      cyclomaticComplexity: CyclomaticComplexityAlgorithm().calculate(
        tokens,
        activeProfile,
      ),
      maintainabilityIndex: MaintainabilityIndexAlgorithm()
          .calculate(tokens, activeProfile)
          .score,
      abcScore: AbcScoreAlgorithm().calculate(tokens, activeProfile).score,
      npathComplexity: NpathComplexityAlgorithm().calculate(
        tokens,
        activeProfile,
      ),
      cognitiveComplexity: CognitiveComplexityAlgorithm().calculate(
        tokens,
        activeProfile,
      ),
      halsteadDeliveredBugs: HalsteadComplexityAlgorithm()
          .calculate(tokens, activeProfile)
          .deliveredBugs,
    );
  }
}
