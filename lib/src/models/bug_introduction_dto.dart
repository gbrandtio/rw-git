import 'package:rw_git/src/models/git/git_commit.dart';

/// ----------------------------------------------------------------------------
/// bug_introduction_dto.dart
/// ----------------------------------------------------------------------------
/// Data Transfer Object representing a bug introduction.
/// It links the commit that originally introduced the buggy code
/// to the subsequent commit(s) that fixed it.
class BugIntroductionDto {
  final GitCommit introducingCommit;
  final List<GitCommit> fixingCommits;
  final double timeTakenToFixInHours;

  const BugIntroductionDto({
    required this.introducingCommit,
    required this.fixingCommits,
    required this.timeTakenToFixInHours,
  });

  Map<String, dynamic> toJson() => {
        'introducingCommit': introducingCommit.toJson(),
        'fixingCommits': fixingCommits.map((e) => e.toJson()).toList(),
        'timeTakenToFixInHours': timeTakenToFixInHours,
      };
}
