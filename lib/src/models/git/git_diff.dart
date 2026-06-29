import '../short_stat_dto.dart';
import 'git_file_diff.dart';

/// ----------------------------------------------------------------------------
/// git_diff.dart
/// ----------------------------------------------------------------------------
/// Represents the complete output of a git diff command.
class GitDiff {
  final List<GitFileDiff> files;
  final ShortStatDto shortStat;

  const GitDiff({
    this.files = const [],
    this.shortStat = const ShortStatDto.defaultStats(),
  });

  Map<String, dynamic> toJson() => {
        'files': files.map((e) => e.toJson()).toList(),
        'shortStat': {
          'numberOfChangedFiles': shortStat.numberOfChangedFiles,
          'insertions': shortStat.insertions,
          'deletions': shortStat.deletions,
        },
      };
}
