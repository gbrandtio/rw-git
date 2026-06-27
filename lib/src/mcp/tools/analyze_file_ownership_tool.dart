import 'dart:convert';
import 'dart:isolate';
import '../../../rw_git.dart';

/// analyze_file_ownership_tool.dart
/// Cross-references CODEOWNERS with git blame history
/// to detect ownership drift.

class AnalyzeFileOwnershipTool implements McpTool {
  final CodeQualityTracker tracker;
  final RwGit rwGit;

  AnalyzeFileOwnershipTool(this.tracker, this.rwGit);

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
    final directory = arguments['directory'] as String;
    final limit = arguments['limit']?.toString() ?? '100';

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

    // 2. Get churn data with authors
    final churn = await tracker.calculateChurnWithAuthors(
      directory,
      limit: limit,
    );

    // 3. Parse CODEOWNERS and cross-reference
    final churnMap = <String, Map<String, int>>{};
    for (final entry in churn.fileChurn.entries) {
      churnMap[entry.key] = entry.value.authors;
    }

    final result = await Isolate.run(
      () => _analyzeOwnership(
        codeownersContent,
        codeownersFound,
        churnMap,
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
  Map<String, Map<String, int>> churnMap,
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

  for (final entry in churnMap.entries) {
    final fileName = entry.key;
    final authors = entry.value;

    // Find declared owners for this file
    final declaredOwners = _findOwners(fileName, rules);

    // Find actual top contributor
    String topContributor = '';
    int topChanges = 0;
    for (final authorEntry in authors.entries) {
      if (authorEntry.value > topChanges) {
        topChanges = authorEntry.value;
        topContributor = authorEntry.key;
      }
    }

    final totalChanges = authors.values.fold<int>(0, (s, v) => s + v);

    // Detect ownership drift
    bool hasDrift = false;
    if (declaredOwners.isNotEmpty && topContributor.isNotEmpty) {
      // Check if top contributor matches any owner
      // Owners can be @username or email format
      final ownerMatches = declaredOwners.any(
        (owner) =>
            owner.contains(topContributor) ||
            topContributor.contains(
              owner.replaceAll('@', ''),
            ),
      );
      hasDrift = !ownerMatches;
    }

    if (hasDrift) {
      driftCount++;
    }

    if (declaredOwners.isEmpty && codeownersFound) {
      unownedFiles.add(fileName);
    }

    files.add({
      'file': fileName,
      'declared_owners': declaredOwners,
      'actual_top_contributor': topContributor,
      'total_changes': totalChanges,
      'ownership_drift': hasDrift,
    });
  }

  // Sort by total changes descending
  files.sort(
    (a, b) => (b['total_changes'] as int).compareTo(a['total_changes'] as int),
  );

  return {
    'codeowners_found': codeownersFound,
    'total_files_analyzed': files.length,
    'drift_count': driftCount,
    'unowned_files': unownedFiles,
    'files': files,
  };
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
