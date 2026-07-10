import 'dart:convert';
import 'package:rw_git/src/core/exceptions.dart';
import 'package:rw_git/src/core/git_date_time.dart';
import 'package:rw_git/src/models/short_log_dto.dart';
import 'package:rw_git/src/models/short_stat_dto.dart';
import 'package:rw_git/src/models/git/git_branch.dart';
import 'package:rw_git/src/models/git/git_commit.dart';
import 'package:rw_git/src/models/git/git_status.dart';
import 'package:rw_git/src/models/git/git_file_change.dart';
import 'package:rw_git/src/models/git/git_diff.dart';
import 'package:rw_git/src/models/git/git_file_diff.dart';
import 'package:rw_git/src/models/git/git_blame.dart';
import 'package:rw_git/src/models/git/git_blame_line.dart';
import 'package:rw_git/src/models/git/git_tag.dart';

/// ----------------------------------------------------------------------------
/// rw_git_parser.dart
/// ----------------------------------------------------------------------------
/// Provides functionality for the parsing of the cmd output of git commands.
class RwGitParser {
  /// Parses a stdout git output into a list. The parsing is achieved by
  /// splitting the data based on newline characters.
  ///
  /// NOTE: empty lines are dropped, so the result is unsuitable for output
  /// where blank lines are significant (e.g. multiline commit bodies, diff
  /// hunks). Callers needing those must split the raw stdout themselves.
  static List<String> parseGitStdoutBasedOnNewLine(String gitStdout) {
    LineSplitter independentLineSplitter = const LineSplitter();
    List<String> independentLines = independentLineSplitter.convert(gitStdout);
    independentLines =
        independentLines.where((element) => element.isNotEmpty).toList();

    return independentLines;
  }

  /// Given a [List] that contains all the tags of a component, returns a new [List]
  /// that contains only the tags between the [oldTag] and the [newTag], including
  /// the [newTag] (but not the [oldTag]).
  static List<String> retrieveTagsInBetweenOf(
      List<String> allTags, String oldTag, String newTag) {
    int oldTagIndex = allTags.indexOf(oldTag) + 1;
    int newTagIndex = allTags.indexOf(newTag);

    newTagIndex = newTagIndex == -1 ? allTags.length - 1 : newTagIndex;
    // Include the element at [newTagIndex] in the resulting sublist.
    newTagIndex++;

    List<String> inBetweenTags = allTags.sublist(oldTagIndex, newTagIndex);
    return inBetweenTags;
  }

  /// Parses the stdout of git diff --shortstat into the representation model.
  /// Example of git diff --shortstat:
  /// ```
  ///  3 files changed, 455 insertions(+), 12 deletions(-)
  /// ```
  static ShortStatDto parseGitShortStatStdout(String rawGitShortStats) {
    int numberOfChangedFiles = -1;
    int insertions = -1;
    int deletions = -1;

    try {
      List<String> shortStatParts = rawGitShortStats.split(',');
      for (int i = 0; i < shortStatParts.length; i++) {
        shortStatParts[i] = shortStatParts[i].trim();
      }

      numberOfChangedFiles = int.parse(shortStatParts[0].split(' ')[0]);
      insertions = int.parse(shortStatParts[1].split(' ')[0]);
      deletions = int.parse(shortStatParts[2].split(' ')[0]);
    } catch (e) {
      numberOfChangedFiles = -1;
      insertions = -1;
      deletions = -1;
    }

    return ShortStatDto(numberOfChangedFiles, insertions, deletions);
  }

  /// Parses the stdout of git shortlog -s into the representation model.
  /// Example of git shortlog -s:
  /// ```
  ///  (80) Ioannis Brant-Ioannidis
  /// ```
  static ShortLogDto parseGitShortLogStdout(String rawGitShortLog) {
    int numberOfContributions = -1;
    String authorName = "";

    try {
      List<String> shortLogParts = rawGitShortLog.trim().split(RegExp('\\s+'));
      numberOfContributions = int.parse(shortLogParts[0]);
      authorName = shortLogParts.skip(1).join(' ');
    } catch (e) {
      numberOfContributions = -1;
      authorName = "";
    }

    return ShortLogDto(numberOfContributions, authorName);
  }

  /// Parses the stdout of git branch.
  static List<GitBranch> parseBranches(String stdout) {
    final lines = parseGitStdoutBasedOnNewLine(stdout);
    return lines.map((line) {
      final isCurrent = line.startsWith('*');
      final name = line.replaceFirst(RegExp(r'^[\*\s]+'), '').trim();
      return GitBranch(name: name, isCurrent: isCurrent);
    }).toList();
  }

  /// Parses the stdout of git tag.
  static List<GitTag> parseTags(String stdout) {
    final lines = parseGitStdoutBasedOnNewLine(stdout);
    return lines.map((line) => GitTag(name: line.trim())).toList();
  }

  /// Parses the stdout of git status --porcelain.
  static GitStatus parseStatus(String stdout) {
    final lines = parseGitStdoutBasedOnNewLine(stdout);
    final staged = <GitFileChange>[];
    final unstaged = <GitFileChange>[];
    final untracked = <String>[];

    GitFileStatus mapStatus(String code) {
      switch (code) {
        case 'A':
          return GitFileStatus.added;
        case 'M':
          return GitFileStatus.modified;
        case 'D':
          return GitFileStatus.deleted;
        case 'R':
          return GitFileStatus.renamed;
        case 'C':
          return GitFileStatus.copied;
        case '?':
          return GitFileStatus.untracked;
        default:
          return GitFileStatus.unknown;
      }
    }

    for (final line in lines) {
      if (line.length < 3) continue;
      // `git status --porcelain` encodes each entry as two status columns:
      // the index (staged) column followed by the worktree (unstaged) column.
      final indexStatusCode = line[0];
      final worktreeStatusCode = line[1];
      final path = line.substring(3).trim();

      if (indexStatusCode == '?' && worktreeStatusCode == '?') {
        untracked.add(path);
      } else {
        if (indexStatusCode != ' ' && indexStatusCode != '?') {
          staged.add(
              GitFileChange(path: path, status: mapStatus(indexStatusCode)));
        }
        if (worktreeStatusCode != ' ' && worktreeStatusCode != '?') {
          unstaged.add(
              GitFileChange(path: path, status: mapStatus(worktreeStatusCode)));
        }
      }
    }
    return GitStatus(
      stagedChanges: staged,
      unstagedChanges: unstaged,
      untrackedFiles: untracked,
    );
  }

  /// Parses the stdout of git log with custom format %H|%an|%ae|%aI|%s
  static List<GitCommit> parseCommits(String stdout) {
    final lines = parseGitStdoutBasedOnNewLine(stdout);
    final commits = <GitCommit>[];
    for (final line in lines) {
      final parts = line.split('|');
      if (parts.length >= 5) {
        commits.add(GitCommit(
          hash: parts[0],
          authorName: parts[1],
          authorEmail: parts[2],
          date: parts[3],
          message: parts.sublist(4).join('|'),
        ));
      }
    }
    return commits;
  }

  /// Parses the stdout of git diff.
  static GitDiff parseDiff(String stdout) {
    final files = <GitFileDiff>[];
    final fileChunks = stdout.split(RegExp(r'^diff --git ', multiLine: true));

    for (final chunk in fileChunks) {
      if (chunk.trim().isEmpty) continue;

      final lines = chunk.split('\n');
      if (lines.isEmpty) continue;

      final pathParts = lines[0].split(' ');
      final path =
          pathParts.isNotEmpty ? pathParts.last.replaceFirst('b/', '') : '';

      int additions = 0;
      int deletions = 0;

      for (final line in lines) {
        if (line.startsWith('+') && !line.startsWith('+++')) {
          additions++;
        } else if (line.startsWith('-') && !line.startsWith('---')) {
          deletions++;
        }
      }

      files.add(GitFileDiff(
        path: path,
        additions: additions,
        deletions: deletions,
        contentDiff: 'diff --git $chunk',
      ));
    }

    return GitDiff(files: files);
  }

  /// Parses the stdout of standard git blame.
  static GitBlame parseBlame(String stdout) {
    final lines = parseGitStdoutBasedOnNewLine(stdout);
    final blameLines = <GitBlameLine>[];

    // Example: 93f2f810 (Ioannis 2026-06-29 00:00:00 +0400 1) content
    final regex = RegExp(
        r'^([a-f0-9\^]+)\s+\((.*?)\s*(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+(?:Z|[+-]\d{2}:?\d{2}))\s+(\d+)\)\s?(.*)$');

    for (final line in lines) {
      final match = regex.firstMatch(line);
      if (match == null) {
        // BlameCommand pins --date=iso, so every line must match; silently
        // skipping a line would return a truncated-but-successful result and
        // corrupt every metric built on top of it.
        throw GitOutputParseException(
          offendingLine: line,
          reason: 'does not match the git blame --date=iso format',
        );
      }

      // Honours the timestamp's UTC offset and throws on malformed input;
      // substituting a fallback such as DateTime.now() would silently
      // corrupt every date-based metric downstream.
      final parsedDate = GitDateTime.parse(match.group(3)!).utc;

      blameLines.add(GitBlameLine(
        commitHash: match.group(1) ?? '',
        author: match.group(2) ?? '',
        date: parsedDate,
        lineNumber: int.tryParse(match.group(4) ?? '') ?? 0,
        content: match.group(5) ?? '',
      ));
    }
    return GitBlame(lines: blameLines);
  }
}
