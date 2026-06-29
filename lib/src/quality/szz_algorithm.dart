import 'package:rw_git/rw_git.dart';

/// ----------------------------------------------------------------------------
/// szz_algorithm.dart
/// ----------------------------------------------------------------------------
/// Core reusable implementation of the SZZ algorithm.
class SzzAlgorithm {
  final ProcessRunner runner;

  SzzAlgorithm(this.runner);

  /// Implements the SZZ Algorithm to identify Bug Introductions.
  /// 1. Finds recent bug-fix commits using heuristics.
  /// 2. Finds deleted lines in those commits.
  /// 3. Uses `git blame` to find the original author/commit that introduced the bug.
  Future<List<SzzMatch>> execute(
    String directory, {
    String? limit,
    String? positiveRegex,
    String? negativeRegex,
  }) async {
    final args = [
      'log',
      '--grep=fix\\|bug\\|patch\\|issue\\|resolv',
      '-i',
      '--no-merges',
      '--format=format:%H%x09%s'
    ];

    if (limit != null) {
      args.insert(1, '-n');
      args.insert(2, limit);
    }

    final res = await runner.run('git', args, workingDirectory: directory);
    if (res.exitCode != 0) return [];

    final rawOutput = res.stdout?.toString() ?? '';
    if (rawOutput.isEmpty) return [];

    final lines = rawOutput.split('\n');
    final fixCommits = <String>[];

    final posRegex = positiveRegex != null
        ? RegExp(positiveRegex, caseSensitive: false)
        : null;
    final negRegex = negativeRegex != null
        ? RegExp(negativeRegex, caseSensitive: false)
        : null;

    final defaultPosRegex = RegExp(
        r'\b(fix|fixes|fixed|fixing|bug|bugs|patch|issue|resolve|resolves|resolved)\b',
        caseSensitive: false);
    final defaultNegRegex = RegExp(
        r'\b(typo|docs?|documentation|readme|format|formatting|style|cleanup|refactor)\b',
        caseSensitive: false);

    final rPos = posRegex ?? defaultPosRegex;
    final rNeg = negRegex ?? defaultNegRegex;

    for (final line in lines) {
      final parts = line.split('\t');
      if (parts.length >= 2) {
        final hash = parts[0].trim();
        final subject = parts.sublist(1).join('\t').trim();

        if (rPos.hasMatch(subject) && !rNeg.hasMatch(subject)) {
          fixCommits.add(hash);
        }
      }
    }

    final matches = <SzzMatch>[];

    for (final commit in fixCommits) {
      // Get parent of fix commit
      final parentRes = await runner.run('git', ['rev-parse', '$commit^'],
          workingDirectory: directory);
      if (parentRes.exitCode != 0) continue;
      final parent = parentRes.stdout?.toString().trim() ?? '';
      if (parent.isEmpty) continue;

      // Get diff of fix commit with rename detection
      final diffRes = await runner.run('git', ['diff', '-M', parent, commit],
          workingDirectory: directory);
      if (diffRes.exitCode != 0) continue;
      final diffOutput = (diffRes.stdout?.toString() ?? '').split('\n');

      String currentFile = '';
      for (final line in diffOutput) {
        if (line.startsWith('--- a/')) {
          currentFile = line.substring(6).trim();
        } else if (line.startsWith('@@ ') &&
            currentFile.isNotEmpty &&
            currentFile != '/dev/null') {
          final parts = line.split(' ');
          if (parts.length > 1) {
            final minusPart = parts[1]; // -start,count
            if (minusPart.startsWith('-')) {
              final minusParts = minusPart.substring(1).split(',');
              final start = int.tryParse(minusParts[0]) ?? 0;
              final count = minusParts.length > 1
                  ? (int.tryParse(minusParts[1]) ?? 1)
                  : 1;

              if (count > 0 && start > 0) {
                final end = start + count - 1;
                final blameRes = await runner.run(
                    'git',
                    [
                      'blame',
                      '-l', // long hash
                      '-w', // ignore whitespace
                      '-C', '-C', '-M', // detect moves and copies
                      '-L',
                      '$start,$end',
                      parent,
                      '--',
                      currentFile
                    ],
                    workingDirectory: directory);

                if (blameRes.exitCode == 0) {
                  final blameLines = (blameRes.stdout?.toString() ?? '')
                      .split('\n')
                      .where((l) => l.trim().isNotEmpty);
                  for (final bLine in blameLines) {
                    // Match the long hash and author
                    // format: hash (Author Name ...
                    final match = RegExp(
                            r'^([a-f0-9]{40})\s+.*?\(<([^>]+)>|\((.*?)\s+\d{4}-')
                        .firstMatch(bLine);
                    if (match != null) {
                      // We skip parsing to BugIntroductionDto since it is only needed for the tool
                      // parse author depending on format, blame sometimes outputs (<email> or (Author Name Date)
                      // wait, let's use standard blame -l output:
                      // hash (Author Name 2023-01-01 12:00:00 +0000 1) line content
                      // a simpler regex: ^([a-f0-9]{40})\s+\((.*?)\s+\d{4}-
                      final authorMatch =
                          RegExp(r'^([a-f0-9]{40})\s+\((.*?)\s+\d{4}-')
                              .firstMatch(bLine);
                      if (authorMatch != null) {
                        final introHash = authorMatch.group(1)!;
                        final author = authorMatch.group(2)!.trim();
                        matches.add(SzzMatch(
                          introducingCommitHash: introHash,
                          introducingAuthor: author,
                          fixingCommitHash: commit,
                          filePath: currentFile,
                        ));
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    return matches;
  }
}

class SzzMatch {
  final String introducingCommitHash;
  final String introducingAuthor;
  final String fixingCommitHash;
  final String filePath;

  SzzMatch({
    required this.introducingCommitHash,
    required this.introducingAuthor,
    required this.fixingCommitHash,
    required this.filePath,
  });
}
