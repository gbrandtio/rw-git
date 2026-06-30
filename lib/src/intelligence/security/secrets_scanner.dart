import 'dart:isolate';
import 'dart:math';
import 'package:rw_git/src/core/process_runner.dart';

/// ----------------------------------------------------------------------------
/// secrets_scanner.dart
/// ----------------------------------------------------------------------------
class SecretsScanner {
  final ProcessRunner runner;

  SecretsScanner(this.runner);

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
    r'(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{36}|' // GitHub Tokens
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
      // Add Context-Aware Risk Scoring (ignoring test/, etc.)
      final isTestOrMock = currentFile.contains('test/') ||
          currentFile.contains('tests/') ||
          currentFile.contains('__tests__/') ||
          currentFile.contains('spec/') ||
          currentFile.endsWith('_test.dart') ||
          currentFile.contains('.test.') ||
          currentFile.contains('.spec.') ||
          currentFile.contains('mock') ||
          currentFile.contains('fixture') ||
          currentFile.endsWith('.md');

      // Exclude lock files entirely
      final isLockFile = currentFile.endsWith('package-lock.json') ||
          currentFile.endsWith('yarn.lock') ||
          currentFile.endsWith('pnpm-lock.yaml') ||
          currentFile.endsWith('pubspec.lock') ||
          currentFile.endsWith('Cargo.lock') ||
          currentFile.endsWith('go.sum') ||
          currentFile.endsWith('Gemfile.lock');

      if (isTestOrMock || isLockFile) continue;

      final content = line.substring(1); // remove '+'

      final matches = secretRegex.allMatches(content);
      for (final match in matches) {
        final secretVal = match.group(0) ?? '';

        // Filter out CI variables and placeholder keys
        final lowerSecret = secretVal.toLowerCase();
        if (lowerSecret.contains(r'${{') ||
            lowerSecret.contains(r'${') ||
            lowerSecret.contains('placeholder') ||
            lowerSecret.contains('example') ||
            lowerSecret.contains('dummy') ||
            lowerSecret.contains('your_')) {
          continue;
        }

        // Redact the secret for reporting to avoid exposing it again
        final redacted = secretVal.length > 6
            ? '${secretVal.substring(0, 3)}***${secretVal.substring(secretVal.length - 3)}'
            : '***';

        detectedSecrets.add(
            'Commit: $currentCommitHeader\nFile: $currentFile\nFound Potential Secret (Regex): $redacted');
      }

      // Configurable Shannon Entropy Detection
      // Look for long alphanumeric strings (base64, hex, etc.)
      final wordRegex = RegExp(r'[a-zA-Z0-9_\-\.\+]{20,}');
      final wordMatches = wordRegex.allMatches(content);
      for (final match in wordMatches) {
        final word = match.group(0)!;

        // Filter out CI variables and placeholder keys for entropy too
        final lowerWord = word.toLowerCase();
        if (lowerWord.contains(r'${{') ||
            lowerWord.contains(r'${') ||
            lowerWord.contains('placeholder') ||
            lowerWord.contains('example') ||
            lowerWord.contains('dummy') ||
            lowerWord.contains('your_')) {
          continue;
        }

        // Exclude common long non-secrets like very long URLs or paths if needed,
        // but for now, rely on high entropy.
        final entropy = _calculateEntropy(word);
        if (entropy > 4.5 && !secretRegex.hasMatch(word)) {
          // Threshold 4.5 is typical for base64/hex keys
          final redacted =
              '${word.substring(0, 3)}***${word.substring(word.length - 3)}';
          detectedSecrets.add(
              'Commit: $currentCommitHeader\nFile: $currentFile\nFound Potential Secret (High Entropy: ${entropy.toStringAsFixed(2)}): $redacted');
        }
      }
    }
  }

  return detectedSecrets;
}

double _calculateEntropy(String s) {
  if (s.isEmpty) return 0.0;
  final frequencies = <String, int>{};
  for (int i = 0; i < s.length; i++) {
    final char = s[i];
    frequencies[char] = (frequencies[char] ?? 0) + 1;
  }
  double entropy = 0.0;
  for (final count in frequencies.values) {
    final p = count / s.length;
    entropy -= p * (log(p) / ln2);
  }
  return entropy;
}
