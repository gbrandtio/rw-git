import 'dart:convert';
import 'dart:isolate';
import '../../../../rw_git.dart';
import '../../utils/mcp_argument_extensions.dart';

/// analyze_file_ownership_tool.dart
/// Cross-references CODEOWNERS with git blame history
/// to detect ownership drift.

class AnalyzeFileOwnershipTool implements McpTool {
  final ProcessRunner runner;
  final RwGit rwGit;

  AnalyzeFileOwnershipTool(this.runner, this.rwGit);

  @override
  String get name => 'analyze_file_ownership';

  @override
  String get description => 'Reads the CODEOWNERS file and cross-references '
      'it with git blame history to detect ownership '
      'drift. Identifies files with no owner and files '
      'where the declared owner differs from the top '
      'committer. '
      'For a complete guide, invoke the '
      'get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The local repository path.',
          },
          'limit': {
            'type': 'number',
            'description': 'Number of commits to analyze for '
                'authorship (default: 100).',
          },
        },
        'required': ['directory'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    // We ignore the limit argument to properly analyze time periods for drift.

    // 1. Try to read CODEOWNERS from common locations
    String codeownersContent = '';
    bool codeownersFound = false;

    for (final path in [
      'CODEOWNERS',
      '.github/CODEOWNERS',
      'doc/CODEOWNERS',
    ]) {
      try {
        codeownersContent = (await rwGit.runCommand(
          directory,
          ['show', 'HEAD:$path'],
        ))
            .getOrThrow();
        codeownersFound = true;
        break;
      } on RwGitException {
        // File doesn't exist at this path
        continue;
      }
    }

    // 2. Get churn data with authors for 1 year and 90 days
    final churn1Year = await ChurnHeuristic(runner).calculateChurnWithAuthors(
      directory,
      since: '1.year.ago',
    );
    final churn90Days = await ChurnHeuristic(runner).calculateChurnWithAuthors(
      directory,
      since: '90.days.ago',
    );

    // 3. Parse CODEOWNERS and cross-reference
    final churnMap1Year = <String, Map<String, int>>{};
    for (final entry in churn1Year.fileChurn.entries) {
      churnMap1Year[entry.key] = entry.value.authors;
    }

    final churnMap90Days = <String, Map<String, int>>{};
    for (final entry in churn90Days.fileChurn.entries) {
      churnMap90Days[entry.key] = entry.value.authors;
    }

    final result = await Isolate.run(
      () => _analyzeOwnership(
        codeownersContent,
        codeownersFound,
        churnMap1Year,
        churnMap90Days,
      ),
    );

    return jsonEncode(result);
  }
}

// -----------------------------------------------------------------------------
// Isolate entry point
// -----------------------------------------------------------------------------

Map<String, dynamic> _analyzeOwnership(
  String codeownersContent,
  bool codeownersFound,
  Map<String, Map<String, int>> churnMap1Year,
  Map<String, Map<String, int>> churnMap90Days,
) {
  // Parse CODEOWNERS rules
  final rules = <_OwnerRule>[];
  if (codeownersFound) {
    for (final line in codeownersContent.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final pattern = parts[0];
        final owners = parts.sublist(1).toList();
        rules.add(_OwnerRule(pattern, owners));
      }
    }
  }

  final files = <Map<String, dynamic>>[];
  final unownedFiles = <String>[];
  int driftCount = 0;

  for (final entry in churnMap1Year.entries) {
    final fileName = entry.key;
    final authors1Year = entry.value;
    final authors90Days = churnMap90Days[fileName] ?? {};

    // Find declared owners for this file
    final declaredOwners = _findOwners(fileName, rules);

    // Find actual top contributor (1 year)
    String topContributor1Year = _getTopContributor(authors1Year);
    // Find actual top contributor (90 days)
    String topContributor90Days = _getTopContributor(authors90Days);

    final totalChanges1Year = authors1Year.values.fold<int>(0, (s, v) => s + v);
    final totalChanges90Days =
        authors90Days.values.fold<int>(0, (s, v) => s + v);

    // Detect ownership drift against codeowners
    bool hasCodeownersDrift = false;
    if (declaredOwners.isNotEmpty && topContributor1Year.isNotEmpty) {
      // Check if top contributor matches any owner
      // Owners can be @username or email format
      final ownerMatches = declaredOwners.any(
        (owner) =>
            owner.contains(topContributor1Year) ||
            topContributor1Year.contains(
              owner.replaceAll('@', ''),
            ),
      );
      hasCodeownersDrift = !ownerMatches;
    }

    // Detect actual ownership drift (1 year vs 90 days)
    bool hasRecentDrift = false;
    if (topContributor1Year.isNotEmpty &&
        topContributor90Days.isNotEmpty &&
        topContributor1Year != topContributor90Days) {
      hasRecentDrift = true;
    }

    if (hasCodeownersDrift || hasRecentDrift) {
      driftCount++;
    }

    if (declaredOwners.isEmpty && codeownersFound) {
      unownedFiles.add(fileName);
    }

    files.add({
      'file': fileName,
      'declared_owners': declaredOwners,
      'top_contributor_1_year': topContributor1Year,
      'top_contributor_90_days': topContributor90Days,
      'total_changes_1_year': totalChanges1Year,
      'total_changes_90_days': totalChanges90Days,
      'codeowners_drift': hasCodeownersDrift,
      'recent_drift': hasRecentDrift,
    });
  }

  // Sort by total changes descending
  files.sort(
    (a, b) => (b['total_changes_1_year'] as int)
        .compareTo(a['total_changes_1_year'] as int),
  );

  return {
    'codeowners_found': codeownersFound,
    'total_files_analyzed': files.length,
    'drift_count': driftCount,
    'unowned_files': unownedFiles,
    'files': files,
  };
}

String _getTopContributor(Map<String, int> authors) {
  String topContributor = '';
  int topChanges = 0;
  for (final authorEntry in authors.entries) {
    if (authorEntry.value > topChanges) {
      topChanges = authorEntry.value;
      topContributor = authorEntry.key;
    }
  }
  return topContributor;
}

List<String> _findOwners(String filePath, List<_OwnerRule> rules) {
  // CODEOWNERS uses last-match-wins, so iterate
  // in reverse to find the applicable rule
  List<String> owners = [];
  for (final rule in rules.reversed) {
    if (_matchesPattern(filePath, rule.pattern)) {
      owners = rule.owners;
      break;
    }
  }
  return owners;
}

bool _matchesPattern(String filePath, String pattern) {
  // Simplified prefix/suffix matching:
  // - "*.dart" matches any .dart file
  // - "/lib/" matches files under lib/
  // - "lib/src/mcp/" matches files under that path
  // - "*" matches everything
  if (pattern == '*') return true;

  if (pattern.startsWith('*.')) {
    final ext = pattern.substring(1);
    return filePath.endsWith(ext);
  }

  if (pattern.startsWith('/')) {
    return filePath.startsWith(pattern.substring(1));
  }

  if (pattern.endsWith('/')) {
    return filePath.startsWith(pattern) || filePath.contains('/$pattern');
  }

  return filePath == pattern ||
      filePath.endsWith('/$pattern') ||
      filePath.startsWith(pattern);
}

class _OwnerRule {
  final String pattern;
  final List<String> owners;

  _OwnerRule(this.pattern, this.owners);
}
