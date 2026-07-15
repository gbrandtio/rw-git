import 'package:pool/pool.dart';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/constants.dart';

/// szz_algorithm.dart
/// ----------------------------------------------------------------------------
/// Core reusable implementation of the RA-SZZ algorithm (Refactoring-Aware
/// SZZ — Neto et al., *The Impact of Refactoring Changes on the SZZ
/// Algorithm*, SANER 2018), layered on the MA-SZZ whitespace filtering of
/// da Costa et al. (ICSME 2017).
///
/// This class is the single SZZ implementation in the package. Every tool
/// that links bug-fix commits to their introducing commits
/// (`analyze_bug_hotspots`, including its per-developer `author` filter, and
/// `generate_changelog`) must go through [execute] or [traceFixCommit];
/// re-implementing the fix→introducing tracing elsewhere would silently
/// fork the attribution accuracy the RA-SZZ/MA-SZZ guards provide.
class SzzAlgorithm {
  final ProcessRunner runner;

  SzzAlgorithm(this.runner);

  /// Commit metadata (subject, author date) looked up once per commit and
  /// reused across the instance: hot introducing commits recur across many
  /// fix commits. Keyed by directory + hash so one instance can safely
  /// serve multiple repositories.
  final Map<String, _CommitMetadata?> _commitMetadataCache = {};

  /// Commit subjects that describe refactorings rather than behaviour
  /// changes. Used as a lightweight stand-in for RefDiff's AST-based
  /// refactoring-operation detection: rw_git is language-agnostic, so
  /// AST differencing is not available (the same trade-off as
  /// `RefactoringDetectionAlgorithm`).
  static final RegExp _refactoringSubjectPattern = RegExp(
    r'\b(refactor(ing|ed)?|rewrite|rewrote|rename(d|s)?|restructure(d)?|'
    r'reformat(ted)?|format(ting)?|style|clean|cleanup|clean-up|move(d)?|'
    r'extract(ed)?|inline(d)?)\b',
    caseSensitive: false,
  );

  /// `git blame -l` line shape:
  /// `[^]<hash>[ <file>] (<author> <iso-strict date> <lineno>)`.
  /// A `^` prefix marks a boundary commit (git shortens the hash by one hex
  /// digit to keep the column width); the optional filename column appears
  /// when `-C -C` attributes the line to content moved from another file.
  static final RegExp _blameLinePattern = RegExp(
    r'^(\^?[a-f0-9]{39,40})(?:\s+(.+?))?\s+\((.*?)\s*(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:?\d{2}))\s+\d+\)',
  );

  /// Identifies bug introductions across the repository history:
  /// 1. Find bug-fix commits via keyword heuristics (positive/negative
  ///    filters).
  /// 2. Trace each fix commit to its introducing commits via the shared
  ///    RA-SZZ core (see [traceFixCommit] for the per-commit pipeline).
  Future<List<SzzMatch>> execute(
    String directory, {
    String? limit,
    String? since,
    String? until,
    String? positiveRegex,
    String? negativeRegex,
    List<String>? targetFiles,
  }) async {
    final args = [
      'log',
      '--grep=fix\\|bug\\|patch\\|issue\\|resolv',
      '-i',
      '--no-merges',
      '--format=format:%H%x09%aI%x09%s',
    ];

    if (limit != null) {
      args.insert(1, '-n');
      args.insert(2, limit);
    }
    if (since != null) {
      args.add('--since=$since');
    }
    if (until != null) {
      args.add('--until=$until');
    }
    if (targetFiles != null && targetFiles.isNotEmpty) {
      args.add('--');
      args.addAll(targetFiles);
    }

    final res = await runner.run('git', args, workingDirectory: directory);
    if (res.exitCode != 0) return [];

    final rawOutput = res.stdout?.toString() ?? '';
    if (rawOutput.isEmpty) return [];

    final lines = rawOutput.split('\n');
    final fixCommits = <_FixCommitInfo>[];

    final posRegex = positiveRegex != null
        ? RegExp(positiveRegex, caseSensitive: false)
        : null;
    final negRegex = negativeRegex != null
        ? RegExp(negativeRegex, caseSensitive: false)
        : null;

    final defaultPosRegex = RegExp(
      r'\b(fix|fixes|fixed|fixing|bug|bugs|patch|issue|resolve|resolves|resolved)\b',
      caseSensitive: false,
    );
    final defaultNegRegex = RegExp(
      r'\b(typo|docs?|documentation|readme|format|formatting|style|cleanup|refactor)\b',
      caseSensitive: false,
    );

    final rPos = posRegex ?? defaultPosRegex;
    final rNeg = negRegex ?? defaultNegRegex;

    for (final line in lines) {
      final parts = line.split('\t');
      if (parts.length >= 3) {
        final hash = parts[0].trim();
        final dateStr = parts[1].trim();
        final subject = parts.sublist(2).join('\t').trim();

        if (rPos.hasMatch(subject) && !rNeg.hasMatch(subject)) {
          // Fix/introduction dates are compared across commits from different
          // authors, so the exact UTC instant (offset honoured) is used.
          final fixDate = GitDateTime.parse(dateStr).utc;
          fixCommits.add(_FixCommitInfo(hash, fixDate));
        }
      }
    }

    final matches = <SzzMatch>[];
    final pool = Pool(20);

    final futures = fixCommits.map(
      (fixInfo) => _traceIntroducingCommits(
        directory,
        fixInfo.hash,
        fixInfo.date,
        pool: pool,
        targetFiles: targetFiles,
      ),
    );
    final results = await Future.wait(futures);
    matches.addAll(results.expand((m) => m));

    return matches;
  }

  /// Traces a single, already-identified bug-fix commit to its introducing
  /// commits through the shared RA-SZZ core. Entry point for tools that
  /// select fix commits themselves (e.g. `generate_changelog`, which
  /// classifies them via Conventional Commits instead of the keyword
  /// heuristics in [execute]).
  ///
  /// Returns an empty list when [fixCommitHash] cannot be resolved: a
  /// missing commit cannot be diffed or blamed either.
  Future<List<SzzMatch>> traceFixCommit(
    String directory,
    String fixCommitHash,
  ) async {
    final pool = Pool(20);
    final metadata = await _commitMetadata(
      directory,
      fixCommitHash,
      pool: pool,
    );
    if (metadata == null) return [];
    final fixDate = GitDateTime.parse(metadata.isoAuthorDate).utc;
    return _traceIntroducingCommits(
      directory,
      fixCommitHash,
      fixDate,
      pool: pool,
    );
  }

  /// The shared RA-SZZ core for one fix commit:
  /// 1. Extract deleted lines from the whitespace-filtered diff against the
  ///    parent (MA-SZZ).
  /// 2. RA-SZZ line filter: discard deleted lines whose content re-appears
  ///    among the same commit's added lines — code moved by a refactoring,
  ///    not a bug-removing deletion.
  /// 3. `git blame` the surviving lines on the parent to find the
  ///    introducing commit and author.
  /// 4. RA-SZZ commit filter: discard attributions whose introducing commit
  ///    is itself a refactoring commit — the buggy code predates it, so
  ///    blaming the refactoring author would be a false attribution.
  Future<List<SzzMatch>> _traceIntroducingCommits(
    String directory,
    String commit,
    DateTime fixDate, {
    required Pool pool,
    List<String>? targetFiles,
  }) async {
    final matches = <SzzMatch>[];

    // Get parent of fix commit
    final parentRes = await pool.withResource(
      () => runner.run('git', [
        'rev-parse',
        '$commit^',
      ], workingDirectory: directory),
    );
    if (parentRes.exitCode != 0) return matches;
    final parent = parentRes.stdout?.toString().trim() ?? '';
    if (parent.isEmpty) return matches;

    // MA-SZZ: ignore whitespace and blank-line changes to avoid attributing
    // cosmetic edits as bug introductions (da Costa et al., 2017).
    final diffRes = await pool.withResource(
      () => runner.run('git', [
        'diff',
        '-M',
        '-w',
        '--ignore-blank-lines',
        parent,
        commit,
      ], workingDirectory: directory),
    );
    if (diffRes.exitCode != 0) return matches;

    final commitDiff = _parseUnifiedDiff(diffRes.stdout?.toString() ?? '');

    final blameFutures = <Future<void>>[];

    for (final entry in commitDiff.deletedLinesByFile.entries) {
      final filePath = entry.key;

      if (targetFiles != null &&
          targetFiles.isNotEmpty &&
          !targetFiles.contains(filePath)) {
        continue;
      }

      // RA-SZZ line filter: a deleted line whose content re-appears among
      // the commit's added lines was moved, not fixed (Neto et al., 2018).
      final survivingLines = entry.value
          .where((deleted) => !commitDiff.isMovedLine(deleted.content))
          .toList();

      for (final range in _contiguousRanges(survivingLines)) {
        blameFutures.add(
          pool.withResource(() async {
            final blameRes = await runner.run('git', [
              'blame',
              '--date=iso-strict',
              '-l', // long hash
              '-w', // ignore whitespace
              '-C', '-C', '-M', // detect moves and copies
              '-L',
              '${range.start},${range.end}',
              parent,
              '--',
              filePath,
            ], workingDirectory: directory);
            if (blameRes.exitCode != 0) return;

            final blameLines = (blameRes.stdout?.toString() ?? '')
                .split('\n')
                .where((l) => l.trim().isNotEmpty);
            for (final blameLine in blameLines) {
              final blameMatch = _blameLinePattern.firstMatch(blameLine);
              if (blameMatch == null) {
                // --date=iso-strict is pinned above, so every line must match;
                // silently skipping would drop bug attributions and quietly
                // corrupt the analysis.
                throw GitOutputParseException(
                  offendingLine: blameLine,
                  reason:
                      'does not match the git blame -l --date=iso-strict '
                      'format',
                );
              }

              // Strip the boundary marker before handing the hash back to git:
              // in rev syntax a leading `^` means exclusion, not boundary.
              final rawHash = blameMatch.group(1)!;
              final introHash = rawHash.startsWith('^')
                  ? rawHash.substring(1)
                  : rawHash;
              final author = blameMatch.group(3)!.trim();
              final introDate = GitDateTime.parse(blameMatch.group(4)!).utc;

              // RA-SZZ commit filter: skip introducing commits that are
              // themselves refactorings. An unknown subject keeps the
              // attribution — failing open preserves recall.
              final introMetadata = await _commitMetadata(directory, introHash);
              final subject = introMetadata?.subject;
              if (subject != null &&
                  _refactoringSubjectPattern.hasMatch(subject)) {
                continue;
              }

              matches.add(
                SzzMatch(
                  introducingCommitHash: introHash,
                  introducingDate: introDate,
                  introducingAuthor: author,
                  fixingCommitHash: commit,
                  fixingDate: fixDate,
                  filePath: filePath,
                ),
              );
            }
          }),
        );
      }
    }

    await Future.wait(blameFutures);
    return matches;
  }

  /// Fetches (and caches) the subject and author date of [hash]. Returns
  /// null when the commit cannot be resolved, so callers decide the failure
  /// semantics (keep the attribution for the RA-SZZ commit filter; skip the
  /// trace entirely for [traceFixCommit]).
  Future<_CommitMetadata?> _commitMetadata(
    String directory,
    String hash, {
    Pool? pool,
  }) async {
    final cacheKey = '$directory@$hash';
    if (_commitMetadataCache.containsKey(cacheKey)) {
      return _commitMetadataCache[cacheKey];
    }

    final runAction = () => runner.run('git', [
      'log',
      '-1',
      '--format=format:%H%x09%an%x09%ae%x09%aI%x09%s',
      hash,
    ], workingDirectory: directory);

    final res = pool != null
        ? await pool.withResource(runAction)
        : await runAction();

    _CommitMetadata? metadata;
    if (res.exitCode == 0) {
      final parts = (res.stdout?.toString() ?? '').trim().split('\t');
      if (parts.length >= 5) {
        metadata = _CommitMetadata(
          isoAuthorDate: parts[3],
          subject: parts.sublist(4).join('\t'),
        );
      }
    }
    _commitMetadataCache[cacheKey] = metadata;
    return metadata;
  }

  /// Groups [sortedDeletedLines] (ascending by line number) into contiguous
  /// line ranges so each surviving block costs one `git blame -L` call.
  static List<_LineRange> _contiguousRanges(
    List<_DeletedLine> sortedDeletedLines,
  ) {
    final ranges = <_LineRange>[];
    for (final deleted in sortedDeletedLines) {
      if (ranges.isNotEmpty && ranges.last.end == deleted.lineNumber - 1) {
        ranges.last.end = deleted.lineNumber;
      } else {
        ranges.add(_LineRange(deleted.lineNumber, deleted.lineNumber));
      }
    }
    return ranges;
  }

  /// Parses a unified diff into per-file deleted lines (with their line
  /// numbers in the pre-image) and the commit-wide set of added-line
  /// contents used for RA-SZZ moved-line detection.
  static _CommitDiff _parseUnifiedDiff(String diffOutput) {
    final deletedLinesByFile = <String, List<_DeletedLine>>{};
    final normalizedAddedLines = <String>{};

    String currentFile = '';
    int oldLineNumber = 0;
    bool inHunk = false;

    final hunkHeaderPattern = RegExp(r'^@@ -(\d+)(?:,(\d+))? \+');

    for (final line in diffOutput.split('\n')) {
      if (line.startsWith('diff --git')) {
        inHunk = false;
        currentFile = '';
      } else if (line.startsWith('--- ')) {
        inHunk = false;
        currentFile = line.startsWith('--- a/') ? line.substring(6).trim() : '';
      } else if (line.startsWith('+++ ')) {
        // The pre-image path from `--- a/` is the blame target; nothing to do.
      } else if (line.startsWith('@@ ')) {
        final header = hunkHeaderPattern.firstMatch(line);
        if (header != null && currentFile.isNotEmpty) {
          oldLineNumber = int.parse(header.group(1)!);
          inHunk = true;
        } else {
          inHunk = false;
        }
      } else if (inHunk) {
        if (line.startsWith(r'\')) {
          // "\ No newline at end of file" — annotation, not content.
        } else if (line.startsWith('-')) {
          deletedLinesByFile
              .putIfAbsent(currentFile, () => [])
              .add(_DeletedLine(oldLineNumber, line.substring(1)));
          oldLineNumber++;
        } else if (line.startsWith('+')) {
          normalizedAddedLines.add(_normalizeLineContent(line.substring(1)));
        } else {
          oldLineNumber++;
        }
      }
    }

    return _CommitDiff(deletedLinesByFile, normalizedAddedLines);
  }

  static String _normalizeLineContent(String content) =>
      content.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// One fix commit's parsed diff: what was deleted (per file, with pre-image
/// line numbers) and what was added anywhere in the commit.
class _CommitDiff {
  final Map<String, List<_DeletedLine>> deletedLinesByFile;
  final Set<String> _normalizedAddedLines;

  _CommitDiff(this.deletedLinesByFile, this._normalizedAddedLines);

  /// A deleted line "moved" when its normalized content re-appears among the
  /// commit's added lines (any file — moves cross files). Lines shorter than
  /// [raSzzMovedLineMinimumLength] are boilerplate that recurs naturally, so
  /// a match on them is not evidence of movement.
  bool isMovedLine(String content) {
    final normalized = SzzAlgorithm._normalizeLineContent(content);
    return normalized.length >= raSzzMovedLineMinimumLength &&
        _normalizedAddedLines.contains(normalized);
  }
}

/// Subject and author date of a commit, cached for the RA-SZZ commit filter
/// and for resolving fix dates in [SzzAlgorithm.traceFixCommit].
class _CommitMetadata {
  final String isoAuthorDate;
  final String subject;

  _CommitMetadata({required this.isoAuthorDate, required this.subject});
}

class _DeletedLine {
  final int lineNumber;
  final String content;

  _DeletedLine(this.lineNumber, this.content);
}

class _LineRange {
  final int start;
  int end;

  _LineRange(this.start, this.end);
}

class _FixCommitInfo {
  final String hash;
  final DateTime date;

  _FixCommitInfo(this.hash, this.date);
}

class SzzMatch {
  final String introducingCommitHash;
  final DateTime introducingDate;
  final String introducingAuthor;
  final String fixingCommitHash;
  final DateTime fixingDate;
  final String filePath;

  SzzMatch({
    required this.introducingCommitHash,
    required this.introducingDate,
    required this.introducingAuthor,
    required this.fixingCommitHash,
    required this.fixingDate,
    required this.filePath,
  });
}
