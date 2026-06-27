import 'dart:isolate';
import 'dart:math';
import '../core/process_runner.dart';
import '../models/churn_metrics_dto.dart';
import '../models/churn_metrics_with_authors_dto.dart';
import '../models/commit_velocity_dto.dart';
import '../models/compliance_report_dto.dart';
import '../models/dependency_manifest_dto.dart';

/// ----------------------------------------------------------------------------
/// code_quality_tracker.dart
/// ----------------------------------------------------------------------------
/// Evaluates git repositories for low quality code based on various heuristics:
/// - Mega commits
/// - Suspicious keywords (fixme, todo, etc.)
/// - Churn analysis
///
/// Uses Isolates to offload heavy string parsing and regex operations.

class CodeQualityTracker {
  final ProcessRunner runner;

  CodeQualityTracker(this.runner);

  /// Analyzes the commits for suspicious keywords by streaming the output
  /// and scanning both the commit message and added code in the diff.
  Future<List<String>> findSuspiciousCommits(String directory,
      {String? limit}) async {
    final args = ['log', '-p', '--format=%H||%an||%ad||%s'];
    if (limit != null) {
      args.insert(1, '-n');
      args.insert(2, limit);
    }

    final stream = runner.runStream('git', args, workingDirectory: directory);

    final List<String> flaggedCommits = [];
    final regex = RegExp(
        r'\b(fixme|fix me|to-do|todo|hack|workaround|kludge|temporary|temp|wip|do not touch|dont touch|magic|dirty|ugly|hotfix|quick fix|oops|wtf|password|passwd|secret|api_key|apikey|credentials|creds|bypass|backdoor)\b',
        caseSensitive: false);

    String currentCommitHeader = '';
    bool currentCommitFlagged = false;

    await for (final line in stream) {
      if (line.trim().isEmpty) continue;

      if (line.contains('||') &&
          !line.startsWith('+') &&
          !line.startsWith('-')) {
        // This is likely a commit header: %H||%an||%ad||%s
        final parts = line.split('||');
        if (parts.length >= 2) {
          currentCommitHeader = line;
          currentCommitFlagged = false; // Reset for new commit

          // Check if message itself has suspicious keywords
          final message = parts.sublist(parts.length >= 4 ? 3 : 1).join('||');
          if (regex.hasMatch(message)) {
            currentCommitFlagged = true;
            if (parts.length >= 4) {
              flaggedCommits
                  .add('${parts[0]} - ${parts[1]} (${parts[2]}): $message');
            } else {
              flaggedCommits.add('${parts[0]} - $message');
            }
          }
        }
      } else if (!currentCommitFlagged &&
          line.startsWith('+') &&
          !line.startsWith('+++ b/')) {
        // This is an added line in the diff
        if (regex.hasMatch(line)) {
          currentCommitFlagged = true;
          // Format using the stored header
          final parts = currentCommitHeader.split('||');
          if (parts.length >= 4) {
            final message = parts.sublist(3).join('||');
            flaggedCommits
                .add('${parts[0]} - ${parts[1]} (${parts[2]}): $message');
          } else if (parts.length >= 2) {
            final message = parts.sublist(1).join('||');
            flaggedCommits.add('${parts[0]} - $message');
          }
        }
      }
    }

    return flaggedCommits;
  }

  /// Identifies mega-commits (e.g. ones that touch more than 500 lines or 20 files)
  Future<List<String>> findMegaCommits(String directory,
      {int lineThreshold = 500, int fileThreshold = 20, String? limit}) async {
    final args = ['log', '--shortstat', '--format=%H||%an||%ad||%s'];
    if (limit != null) {
      args.insert(1, '-n');
      args.insert(2, limit);
    }
    final result = await runner.run('git', args, workingDirectory: directory);
    evaluateProcessResult(result);

    final rawOutput = result.stdout?.toString() ?? '';

    // Offload parsing to an Isolate
    return await Isolate.run(
        () => _parseMegaCommits(rawOutput, lineThreshold, fileThreshold));
  }

  Future<ChurnMetricsDto> calculateChurn(String directory,
      {String? limit}) async {
    final countArgs = ['rev-list', '--count'];
    if (limit != null) {
      countArgs.add('-n');
      countArgs.add(limit);
    }
    countArgs.add('HEAD');
    final commitCountResult =
        await runner.run('git', countArgs, workingDirectory: directory);
    evaluateProcessResult(commitCountResult);
    final totalCommits =
        int.tryParse(commitCountResult.stdout?.toString().trim() ?? '0') ?? 0;

    final logArgs = ['log', '-p', '--format='];
    if (limit != null) {
      logArgs.insert(1, '-n');
      logArgs.insert(2, limit);
    }

    final stream =
        runner.runStream('git', logArgs, workingDirectory: directory);

    final Map<String, int> fileChurn = {};
    final Map<String, int> classChurn = {};
    final Map<String, int> blockChurn = {};

    await for (final line in stream) {
      if (line.trim().isEmpty) continue;

      if (line.startsWith('--- a/')) {
        final fileName = line.substring(6).trim();
        if (fileName != '/dev/null') {
          fileChurn[fileName] = (fileChurn[fileName] ?? 0) + 1;
        }
      } else if (line.startsWith('@@ ')) {
        final parts = line.split('@@');
        if (parts.length >= 3) {
          final context = parts.sublist(2).join('@@').trim();
          if (context.isNotEmpty) {
            blockChurn[context] = (blockChurn[context] ?? 0) + 1;

            if (context.startsWith('class ')) {
              final className =
                  context.split(' ')[1].replaceAll('{', '').trim();
              if (className.isNotEmpty) {
                classChurn[className] = (classChurn[className] ?? 0) + 1;
              }
            }
          }
        }
      }
    }

    return ChurnMetricsDto(
      fileChurn: fileChurn,
      classChurn: classChurn,
      blockChurn: blockChurn,
      totalCommits: totalCommits,
    );
  }

  /// Extracts added or modified comments from the diff, along with context.
  Future<String> extractChangedComments(String directory,
      {String? limit}) async {
    final logArgs = ['log', '-p', '--format=%H||%an||%ad||%s'];
    if (limit != null) {
      logArgs.insert(1, '-n');
      logArgs.insert(2, limit);
    }
    final result =
        await runner.run('git', logArgs, workingDirectory: directory);
    evaluateProcessResult(result);

    final rawOutput = result.stdout?.toString() ?? '';

    // Offload parsing to an Isolate
    return await Isolate.run(() => _parseChangedComments(rawOutput));
  }

  Future<ChurnMetricsWithAuthorsDto> calculateChurnWithAuthors(String directory,
      {String? limit}) async {
    final countArgs = ['rev-list', '--count'];
    if (limit != null) {
      countArgs.add('-n');
      countArgs.add(limit);
    }
    countArgs.add('HEAD');
    final commitCountResult =
        await runner.run('git', countArgs, workingDirectory: directory);
    evaluateProcessResult(commitCountResult);
    final totalCommits =
        int.tryParse(commitCountResult.stdout?.toString().trim() ?? '0') ?? 0;

    final logArgs = ['log', '-p', '--format=AUTHOR:%an'];
    if (limit != null) {
      logArgs.insert(1, '-n');
      logArgs.insert(2, limit);
    }

    final stream =
        runner.runStream('git', logArgs, workingDirectory: directory);

    final Map<String, Map<String, int>> fileChurn = {};
    final Map<String, Map<String, int>> classChurn = {};
    final Map<String, Map<String, int>> blockChurn = {};

    String currentAuthor = 'Unknown';

    await for (final line in stream) {
      if (line.trim().isEmpty) continue;

      if (line.startsWith('AUTHOR:')) {
        currentAuthor = line.substring(7).trim();
      } else if (line.startsWith('--- a/')) {
        final fileName = line.substring(6).trim();
        if (fileName != '/dev/null') {
          fileChurn.putIfAbsent(fileName, () => {});
          fileChurn[fileName]![currentAuthor] =
              (fileChurn[fileName]![currentAuthor] ?? 0) + 1;
        }
      } else if (line.startsWith('@@ ')) {
        final parts = line.split('@@');
        if (parts.length >= 3) {
          final context = parts.sublist(2).join('@@').trim();
          if (context.isNotEmpty) {
            blockChurn.putIfAbsent(context, () => {});
            blockChurn[context]![currentAuthor] =
                (blockChurn[context]![currentAuthor] ?? 0) + 1;

            if (context.startsWith('class ')) {
              final className =
                  context.split(' ')[1].replaceAll('{', '').trim();
              if (className.isNotEmpty) {
                classChurn.putIfAbsent(className, () => {});
                classChurn[className]![currentAuthor] =
                    (classChurn[className]![currentAuthor] ?? 0) + 1;
              }
            }
          }
        }
      }
    }

    Map<String, ContributionStats> toStats(Map<String, Map<String, int>> map) {
      final result = <String, ContributionStats>{};
      for (final entry in map.entries) {
        final total = entry.value.values.fold<int>(0, (sum, val) => sum + val);
        result[entry.key] =
            ContributionStats(total: total, authors: entry.value);
      }
      return result;
    }

    return ChurnMetricsWithAuthorsDto(
      fileChurn: toStats(fileChurn),
      classChurn: toStats(classChurn),
      blockChurn: toStats(blockChurn),
      totalCommits: totalCommits,
    );
  }

  /// Scans commit diffs for exposed secrets, API keys, or sensitive credentials.
  /// Offloads the heavy regex scanning to an Isolate.
  Future<List<String>> findSecrets(String directory,
      {String? limit, String? branch}) async {
    final args = ['log', '-p', '--format=%H||%an||%ad||%s'];
    if (limit != null) {
      args.insert(1, '-n');
      args.insert(2, limit);
    }
    if (branch != null && branch.isNotEmpty) {
      args.add(branch);
    }

    final result = await runner.run('git', args, workingDirectory: directory);
    evaluateProcessResult(result);

    final rawOutput = result.stdout?.toString() ?? '';

    // Offload heavy regex parsing to an Isolate
    return await Isolate.run(() => _parseSecrets(rawOutput));
  }

  /// Identifies files modified on both branches since their
  /// merge base, predicting potential merge conflicts.
  Future<Map<String, List<String>>> findConflictRiskFiles(
      String directory, String branchA, String branchB) async {
    // Find the merge base between the two branches
    final mergeBaseResult = await runner.run(
      'git',
      ['merge-base', branchA, branchB],
      workingDirectory: directory,
    );
    evaluateProcessResult(mergeBaseResult);
    final mergeBase = mergeBaseResult.stdout?.toString().trim() ?? '';

    // Files changed on branchA since merge base
    final diffAResult = await runner.run(
      'git',
      ['diff', '--name-only', mergeBase, branchA],
      workingDirectory: directory,
    );
    evaluateProcessResult(diffAResult);
    final filesA = (diffAResult.stdout?.toString() ?? '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    // Files changed on branchB since merge base
    final diffBResult = await runner.run(
      'git',
      ['diff', '--name-only', mergeBase, branchB],
      workingDirectory: directory,
    );
    evaluateProcessResult(diffBResult);
    final filesB = (diffBResult.stdout?.toString() ?? '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final setA = filesA.toSet();
    final setB = filesB.toSet();
    final both = setA.intersection(setB).toList();
    final onlyA = setA.difference(setB).toList();
    final onlyB = setB.difference(setA).toList();

    return {
      'merge_base': [mergeBase],
      'files_only_on_a': onlyA,
      'files_only_on_b': onlyB,
      'conflicting_files': both,
    };
  }

  /// Computes commit velocity over time, bucketed by the
  /// given granularity (day, week, or month).
  Future<CommitVelocityDto> calculateCommitVelocity(
    String directory, {
    String? limit,
    String? since,
    String? until,
    String granularity = 'week',
  }) async {
    final args = ['log', '--format=%H||%an||%aI'];
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

    final result = await runner.run(
      'git',
      args,
      workingDirectory: directory,
    );
    evaluateProcessResult(result);
    final rawOutput = result.stdout?.toString() ?? '';

    return await Isolate.run(
      () => _parseCommitVelocity(rawOutput, granularity),
    );
  }

  /// Reads dependency manifests from the git working tree
  /// and parses them for pinned/floating analysis.
  Future<DependencyManifestDto> parseDependencyManifests(
      String directory) async {
    // Check which manifest files exist in HEAD
    final lsResult = await runner.run(
      'git',
      ['ls-tree', '-r', '--name-only', 'HEAD'],
      workingDirectory: directory,
    );
    evaluateProcessResult(lsResult);
    final allFiles = (lsResult.stdout?.toString() ?? '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final manifestMap = <String, String>{
      'pubspec.yaml': 'dart',
      'package.json': 'npm',
      'requirements.txt': 'python',
      'go.mod': 'go',
      'Cargo.toml': 'rust',
      'Gemfile': 'ruby',
    };

    final lockFileMap = <String, String>{
      'dart': 'pubspec.lock',
      'npm': 'package-lock.json',
      'python': 'requirements.txt',
      'go': 'go.sum',
      'rust': 'Cargo.lock',
      'ruby': 'Gemfile.lock',
    };

    final ecosystems = <EcosystemReport>[];

    for (final entry in manifestMap.entries) {
      // Find manifests at any path depth
      final matches = allFiles
          .where(
            (f) => f == entry.key || f.endsWith('/${entry.key}'),
          )
          .toList();

      for (final manifestPath in matches) {
        // Read manifest content via git show
        final showResult = await runner.run(
          'git',
          ['show', 'HEAD:$manifestPath'],
          workingDirectory: directory,
        );
        evaluateProcessResult(showResult);
        final content = showResult.stdout?.toString() ?? '';

        // Check for corresponding lock file
        final lockFileName = lockFileMap[entry.value] ?? '';
        final dir = manifestPath.contains('/')
            ? manifestPath.substring(0, manifestPath.lastIndexOf('/') + 1)
            : '';
        final hasLock = allFiles.contains('$dir$lockFileName');

        final report = await Isolate.run(
          () => _parseSingleManifest(
            content,
            entry.value,
            manifestPath,
            hasLock,
          ),
        );
        ecosystems.add(report);
      }
    }

    return DependencyManifestDto(ecosystems: ecosystems);
  }

  /// Scans commit history for compliance policy violations.
  Future<ComplianceReportDto> scanComplianceIssues(
    String directory, {
    String? limit,
    List<String> allowedEmails = const [],
  }) async {
    final args = [
      'log',
      '--format=%H||%G?||%ae||%an||%aI||%s',
    ];
    if (limit != null) {
      args.insert(1, '-n');
      args.insert(2, limit);
    }

    final result = await runner.run(
      'git',
      args,
      workingDirectory: directory,
    );
    evaluateProcessResult(result);
    final rawOutput = result.stdout?.toString() ?? '';

    return await Isolate.run(
      () => _parseComplianceIssues(rawOutput, allowedEmails),
    );
  }
}

// -----------------------------------------------------------------------------
// ISOLATE ENTRY POINTS (Must be static or top-level)
// -----------------------------------------------------------------------------

List<String> _parseMegaCommits(
    String rawLog, int lineThreshold, int fileThreshold) {
  final List<String> flaggedCommits = [];

  final lines = rawLog.split('\n');
  String currentHashInfo = '';

  for (final line in lines) {
    if (line.trim().isEmpty) continue;

    // If line doesn't start with space, it's a commit hash info
    if (!line.startsWith(' ')) {
      currentHashInfo = line.trim();
    } else if (line.contains('changed') ||
        line.contains('insertion') ||
        line.contains('deletion')) {
      // Parse shortstat
      // Example: 3 files changed, 455 insertions(+), 12 deletions(-)
      int insertions = 0;
      int deletions = 0;
      int filesChanged = 0;

      final parts = line.split(',');
      for (final part in parts) {
        if (part.contains('insertion')) {
          insertions = int.tryParse(part.trim().split(' ')[0]) ?? 0;
        } else if (part.contains('deletion')) {
          deletions = int.tryParse(part.trim().split(' ')[0]) ?? 0;
        } else if (part.contains('file changed') ||
            part.contains('files changed')) {
          filesChanged = int.tryParse(part.trim().split(' ')[0]) ?? 0;
        }
      }

      if (((insertions + deletions) >= lineThreshold ||
              filesChanged >= fileThreshold) &&
          currentHashInfo.isNotEmpty) {
        final hashParts = currentHashInfo.split('||');
        if (hashParts.length >= 4) {
          final hash = hashParts[0];
          final author = hashParts[1];
          final date = hashParts[2];
          final message = hashParts.sublist(3).join('||');
          flaggedCommits.add('$hash - $author ($date): $message');
        } else {
          flaggedCommits.add(currentHashInfo);
        }
        currentHashInfo = '';
      }
    }
  }
  return flaggedCommits;
}

String _parseChangedComments(String rawLog) {
  final lines = rawLog.split('\n');
  final buffer = StringBuffer();

  String currentCommitHeader = '';
  String currentFile = '';
  List<String> currentBlock = [];
  bool blockHasComment = false;

  final commentRegex = RegExp(r'(?:\/\/|/\*|\*/|^\s*\*\s|#\s|<!--|--\s|^\s*#)');

  void flushBlock() {
    if (blockHasComment && currentBlock.isNotEmpty) {
      buffer.writeln('Commit: $currentCommitHeader');
      buffer.writeln('File: $currentFile');
      buffer.writeln(currentBlock.join('\n'));
      buffer.writeln('-' * 40);
    }
    currentBlock.clear();
    blockHasComment = false;
  }

  for (final line in lines) {
    if (line.trim().isEmpty) continue;

    if (line.contains('||') &&
        !line.startsWith(' ') &&
        !line.startsWith('+') &&
        !line.startsWith('-') &&
        !line.startsWith('@@') &&
        !line.startsWith('diff') &&
        !line.startsWith('index')) {
      flushBlock();
      final parts = line.split('||');
      if (parts.length >= 4) {
        currentCommitHeader =
            '${parts[0]} - ${parts[1]} (${parts[2]}): ${parts.sublist(3).join('||')}';
      } else {
        currentCommitHeader = line.trim();
      }
    } else if (line.startsWith('+++ b/')) {
      flushBlock();
      currentFile = line.substring(6).trim();
    } else if (line.startsWith('@@ ')) {
      flushBlock();
      currentBlock.add(line);
    } else if (currentBlock.isNotEmpty) {
      currentBlock.add(line);
      if (line.startsWith('+')) {
        final content = line.substring(1); // remove '+'
        if (commentRegex.hasMatch(content)) {
          blockHasComment = true;
        }
      }
    }
  }
  flushBlock();

  return buffer.toString().trim();
}

List<String> _parseSecrets(String rawLog) {
  final lines = rawLog.split('\n');
  final List<String> detectedSecrets = [];

  String currentCommitHeader = '';
  String currentFile = '';

  // Comprehensive regex for detecting secrets
  // Includes AWS keys, generic bearer tokens, private keys, etc.
  final secretRegex = RegExp(
    r'(?:'
    r'AKIA[0-9A-Z]{16}|' // AWS Access Key
    r'xox[baprs]-[0-9a-zA-Z]{10,48}|' // Slack Token
    r'EAACEdEose0cBA[0-9A-Za-z]+|' // Facebook Access Token
    r'(?:sk|pk)_(?:test|live)_[0-9a-zA-Z]{24}|' // Stripe Key
    r'ya29\.[0-9a-zA-Z_-]+|' // Google OAuth token
    r'-----BEGIN (?:RSA|DSA|EC|OPENSSH|PGP) PRIVATE KEY-----|' // Private Keys
    r'ey[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|' // JWT tokens
    r'(?:api_key|apikey|secret|password|passwd|token|auth)[^a-zA-Z0-9]{1,3}[a-zA-Z0-9_\-\.]{12,}' // Generic assignment to secrets
    r')',
    caseSensitive: false,
  );

  for (final line in lines) {
    if (line.trim().isEmpty) continue;

    if (line.contains('||') &&
        !line.startsWith(' ') &&
        !line.startsWith('+') &&
        !line.startsWith('-') &&
        !line.startsWith('@@') &&
        !line.startsWith('diff') &&
        !line.startsWith('index')) {
      final parts = line.split('||');
      if (parts.length >= 4) {
        currentCommitHeader =
            '${parts[0]} - ${parts[1]} (${parts[2]}): ${parts.sublist(3).join('||')}';
      } else {
        currentCommitHeader = line.trim();
      }
    } else if (line.startsWith('+++ b/')) {
      currentFile = line.substring(6).trim();
    } else if (line.startsWith('+') && !line.startsWith('+++')) {
      final content = line.substring(1); // remove '+'

      final matches = secretRegex.allMatches(content);
      for (final match in matches) {
        // Redact the secret for reporting to avoid exposing it again
        final secretVal = match.group(0) ?? '';
        final redacted = secretVal.length > 6
            ? '${secretVal.substring(0, 3)}***${secretVal.substring(secretVal.length - 3)}'
            : '***';

        detectedSecrets.add(
            'Commit: $currentCommitHeader\nFile: $currentFile\nFound Potential Secret: $redacted');
      }
    }
  }

  return detectedSecrets;
}

// -----------------------------------------------------------------------------
// Commit velocity Isolate entry point
// -----------------------------------------------------------------------------

CommitVelocityDto _parseCommitVelocity(String rawLog, String granularity) {
  final lines = rawLog.split('\n');
  final Map<String, Map<String, int>> bucketAuthors = {};

  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final parts = line.split('||');
    if (parts.length < 3) continue;

    final author = parts[1].trim();
    final dateStr = parts[2].trim();

    // Parse ISO 8601 date
    final date = DateTime.tryParse(dateStr);
    if (date == null) continue;

    String periodKey;
    switch (granularity) {
      case 'day':
        periodKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      case 'month':
        periodKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      case 'week':
      default:
        // ISO week: find the Monday of the week
        final weekday = date.weekday;
        final monday = date.subtract(Duration(days: weekday - 1));
        periodKey =
            '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    }

    bucketAuthors.putIfAbsent(periodKey, () => {});
    bucketAuthors[periodKey]![author] =
        (bucketAuthors[periodKey]![author] ?? 0) + 1;
  }

  // Sort by period
  final sortedKeys = bucketAuthors.keys.toList()..sort();
  final buckets = <TimeBucket>[];
  final List<int> commitCounts = [];

  for (final key in sortedKeys) {
    final authors = bucketAuthors[key]!;
    final total = authors.values.fold<int>(0, (sum, v) => sum + v);
    commitCounts.add(total);
    buckets.add(TimeBucket(
      period: key,
      totalCommits: total,
      authors: authors,
    ));
  }

  final totalCommits = commitCounts.fold<int>(0, (sum, v) => sum + v);
  final avg = buckets.isEmpty ? 0.0 : totalCommits / buckets.length;

  // Determine trend from first half vs second half
  String trend = 'stable';
  if (buckets.length >= 4) {
    final mid = buckets.length ~/ 2;
    final firstHalfAvg =
        commitCounts.take(mid).fold<int>(0, (sum, v) => sum + v) / mid;
    final secondHalfAvg =
        commitCounts.skip(mid).fold<int>(0, (sum, v) => sum + v) /
            (buckets.length - mid);
    if (secondHalfAvg > firstHalfAvg * 1.2) {
      trend = 'accelerating';
    } else if (secondHalfAvg < firstHalfAvg * 0.8) {
      trend = 'decelerating';
    }
  }

  // Detect anomalies (> 2 standard deviations)
  final anomalies = <TimeBucket>[];
  if (commitCounts.length >= 3) {
    final mean = avg;
    final variance = commitCounts.fold<double>(
            0.0, (sum, v) => sum + (v - mean) * (v - mean)) /
        commitCounts.length;
    final stdDev = sqrt(variance);
    final threshold = mean + 2 * stdDev;

    for (int i = 0; i < buckets.length; i++) {
      if (commitCounts[i] > threshold) {
        anomalies.add(buckets[i]);
      }
    }
  }

  return CommitVelocityDto(
    buckets: buckets,
    totalCommits: totalCommits,
    averagePerPeriod: avg,
    trend: trend,
    anomalies: anomalies,
  );
}

// -----------------------------------------------------------------------------
// Dependency manifest Isolate entry point
// -----------------------------------------------------------------------------

EcosystemReport _parseSingleManifest(
  String content,
  String ecosystemType,
  String manifestPath,
  bool hasLock,
) {
  int pinned = 0;
  int floating = 0;

  switch (ecosystemType) {
    case 'dart':
      // Parse pubspec.yaml dependencies
      final depRegex = RegExp(
        r'^\s+\w[\w_]*:\s*(.+)$',
        multiLine: true,
      );
      bool inDeps = false;
      for (final line in content.split('\n')) {
        if (line.startsWith('dependencies:') ||
            line.startsWith('dev_dependencies:')) {
          inDeps = true;
          continue;
        }
        if (inDeps &&
            line.isNotEmpty &&
            !line.startsWith(' ') &&
            !line.startsWith('\t')) {
          inDeps = false;
          continue;
        }
        if (inDeps) {
          final match = depRegex.firstMatch(line);
          if (match != null) {
            final version = match.group(1)?.trim() ?? '';
            if (_isPinnedVersion(version)) {
              pinned++;
            } else {
              floating++;
            }
          }
        }
      }

    case 'npm':
      // Parse package.json dependencies
      final depRegex = RegExp(
        r'"[^"]+"\s*:\s*"([^"]+)"',
      );
      bool inDeps = false;
      int braceDepth = 0;
      for (final line in content.split('\n')) {
        if (line.contains('"dependencies"') ||
            line.contains('"devDependencies"')) {
          inDeps = true;
          braceDepth = 0;
          continue;
        }
        if (inDeps) {
          braceDepth +=
              '{'.allMatches(line).length - '}'.allMatches(line).length;
          if (braceDepth < 0) {
            inDeps = false;
            continue;
          }
          final match = depRegex.firstMatch(line);
          if (match != null) {
            final version = match.group(1) ?? '';
            if (_isNpmPinned(version)) {
              pinned++;
            } else {
              floating++;
            }
          }
        }
      }

    case 'python':
      // Parse requirements.txt
      for (final line in content.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) {
          continue;
        }
        if (trimmed.contains('==')) {
          pinned++;
        } else {
          floating++;
        }
      }

    case 'go':
      // Parse go.mod require block
      for (final line in content.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.startsWith('require') ||
            trimmed.startsWith(')') ||
            trimmed.startsWith('(') ||
            trimmed.isEmpty ||
            trimmed.startsWith('module') ||
            trimmed.startsWith('go ') ||
            trimmed.startsWith('//')) {
          continue;
        }
        // Go modules are always pinned
        pinned++;
      }

    case 'rust':
      // Parse Cargo.toml [dependencies]
      bool inDeps = false;
      for (final line in content.split('\n')) {
        final trimmed = line.trim();
        if (trimmed == '[dependencies]' || trimmed == '[dev-dependencies]') {
          inDeps = true;
          continue;
        }
        if (trimmed.startsWith('[') && inDeps) {
          inDeps = false;
          continue;
        }
        if (inDeps && trimmed.contains('=')) {
          if (trimmed.contains('"=') ||
              RegExp(r'"\d+\.\d+\.\d+"').hasMatch(trimmed)) {
            pinned++;
          } else {
            floating++;
          }
        }
      }

    case 'ruby':
      // Parse Gemfile
      final gemRegex = RegExp(r"gem\s+'[^']+'");
      for (final line in content.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty ||
            trimmed.startsWith('#') ||
            trimmed.startsWith('source') ||
            trimmed.startsWith('group')) {
          continue;
        }
        if (gemRegex.hasMatch(trimmed)) {
          // Check if version is specified
          final parts = trimmed.split(',');
          if (parts.length > 1) {
            final versionPart = parts[1].trim();
            if (versionPart.startsWith("'~>")) {
              floating++;
            } else {
              pinned++;
            }
          } else {
            floating++; // No version = floating
          }
        }
      }
  }

  return EcosystemReport(
    type: ecosystemType,
    manifestFile: manifestPath,
    totalDependencies: pinned + floating,
    pinnedCount: pinned,
    floatingCount: floating,
    hasLockFile: hasLock,
  );
}

bool _isPinnedVersion(String version) {
  // Exact version like 1.0.0 or hosted with version
  if (version.isEmpty) return false;
  // Caret/range specifiers are floating
  if (version.startsWith('^') || version.startsWith('>')) {
    return false;
  }
  // "any" is floating
  if (version == 'any') return false;
  // Path or git dependencies are considered pinned
  if (version.startsWith('path:') || version.startsWith('git:')) {
    return true;
  }
  // Exact semver
  return RegExp(r'^\d+\.\d+\.\d+').hasMatch(version);
}

bool _isNpmPinned(String version) {
  if (version.startsWith('^') ||
      version.startsWith('~') ||
      version.startsWith('>') ||
      version == '*' ||
      version == 'latest') {
    return false;
  }
  return true;
}

// -----------------------------------------------------------------------------
// Conventional commits Isolate entry point
// -----------------------------------------------------------------------------

Map<String, List<Map<String, String>>> parseConventionalCommits(String rawLog) {
  final features = <Map<String, String>>[];
  final fixes = <Map<String, String>>[];
  final breakingChanges = <Map<String, String>>[];
  final other = <Map<String, String>>[];

  final lines = rawLog.split('\n');
  final conventionalRegex = RegExp(
    r'^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|revert)'
    r'(\([^)]+\))?!?:\s*(.+)$',
    caseSensitive: false,
  );

  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final parts = line.split('||');
    if (parts.length < 3) continue;

    final hash = parts[0].trim();
    final author = parts[1].trim();
    final message = parts.sublist(2).join('||').trim();

    final entry = {
      'hash': hash,
      'author': author,
      'message': message,
    };

    // Check for breaking changes
    if (message.toUpperCase().contains('BREAKING CHANGE') ||
        message.contains('!:')) {
      breakingChanges.add(entry);
      continue;
    }

    final match = conventionalRegex.firstMatch(message);
    if (match != null) {
      final type = match.group(1)!.toLowerCase();
      switch (type) {
        case 'feat':
          features.add(entry);
        case 'fix':
          fixes.add(entry);
        default:
          other.add(entry);
      }
    } else {
      other.add(entry);
    }
  }

  return {
    'features': features,
    'fixes': fixes,
    'breaking_changes': breakingChanges,
    'other': other,
  };
}

// -----------------------------------------------------------------------------
// Compliance Isolate entry point
// -----------------------------------------------------------------------------

ComplianceReportDto _parseComplianceIssues(
    String rawLog, List<String> allowedEmails) {
  final lines = rawLog.split('\n');
  final unsigned = <ComplianceViolation>[];
  final emptyMsg = <ComplianceViolation>[];
  final unrecognized = <ComplianceViolation>[];
  int total = 0;

  final allowedSet = allowedEmails.toSet();

  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final parts = line.split('||');
    // Format: %H||%G?||%ae||%an||%aI||%s
    if (parts.length < 6) continue;
    total++;

    final hash = parts[0].trim();
    final sigStatus = parts[1].trim();
    final email = parts[2].trim();
    final author = parts[3].trim();
    final date = parts[4].trim();
    final message = parts.sublist(5).join('||').trim();

    final violation = ComplianceViolation(
      hash: hash,
      author: author,
      email: email,
      message: message,
      date: date,
    );

    // N = no signature, U = untrusted, E = expired,
    // X = expired key, R = revoked, B = bad
    // G = good, empty = no check
    if (sigStatus != 'G') {
      unsigned.add(violation);
    }

    if (message.isEmpty) {
      emptyMsg.add(violation);
    }

    if (allowedSet.isNotEmpty && !allowedSet.contains(email)) {
      unrecognized.add(violation);
    }
  }

  return ComplianceReportDto(
    totalCommitsScanned: total,
    unsignedCommits: unsigned,
    emptyMessageCommits: emptyMsg,
    unrecognizedAuthorCommits: unrecognized,
  );
}
