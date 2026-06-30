import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Documentation Formatting', () {
    final docsToTest = [
      File('README.md'),
    ];

    test('README.md should wrap at 80 columns', () {
      final exceptions = [
        RegExp(r'https?://'), // URLs
        RegExp(r'<img\s+'), // HTML Images
        RegExp(r'<a\s+href'), // HTML Links
        RegExp(r'!\[.*?\]\(.*?\)'), // Markdown Images
        RegExp(r'^\|.*\|$'), // Markdown Tables
        RegExp(r'^\[.*?\]:\s*https?://'), // Markdown link references
      ];

      final violations = <String>[];

      for (final file in docsToTest) {
        if (!file.existsSync()) continue;

        final lines = file.readAsLinesSync();
        bool inCodeBlock = false;

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];

          // Toggle code block state
          if (line.trim().startsWith('```')) {
            inCodeBlock = !inCodeBlock;
            continue;
          }

          if (inCodeBlock) {
            continue; // Ignore line length inside code blocks
          }

          if (line.length > 80) {
            // Check if line matches any exception
            final isException = exceptions.any((regex) => regex.hasMatch(line));

            if (!isException) {
              violations
                  .add('${file.path}:${i + 1}: length ${line.length}\n> $line');
            }
          }
        }
      }

      if (violations.isNotEmpty) {
        print('Found ${violations.length} violations:');
        for (final v in violations) {
          print(v);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Found lines exceeding 80 characters. Wrap them appropriately.',
      );
    });
  });
}
