import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// The sampler is what keeps report-grade lexical metrics bounded
/// (ADR-0014): only the top-N churn files are lexed, oversized files are
/// skipped, and paths may never escape the repository directory.
void main() {
  const sampler = BoundedLexicalMetricsSampler();
  late Directory tempDir;

  const branchySource = '''
int classify(int a, int b) {
  if (a > 0 && b > 0) {
    return 1;
  } else if (a < 0 || b < 0) {
    return -1;
  }
  for (var i = 0; i < a; i++) {
    while (b > 0) {
      b--;
    }
  }
  return 0;
}
''';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lexical_sampler_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> writeSource(String relativePath, String content) async {
    final file = File(p.join(tempDir.path, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  test('computes metrics for the top-churn files, keyed by the churn path',
      () async {
    await writeSource('lib/a.dart', branchySource);
    await writeSource('lib/b.dart', 'int x() { return 1; }\n');

    final metrics = await sampler
        .sampleTopChurnFiles(tempDir.path, {'lib/a.dart': 10, 'lib/b.dart': 5});

    expect(metrics.length, 2);
    final byPath = {for (final m in metrics) m.filePath: m};
    // The churn key is preserved verbatim so findings join on the same
    // subject as churn findings.
    expect(byPath.keys, containsAll(['lib/a.dart', 'lib/b.dart']));
    expect(byPath['lib/a.dart']!.cyclomaticComplexity,
        greaterThan(byPath['lib/b.dart']!.cyclomaticComplexity));
    expect(byPath['lib/a.dart']!.maintainabilityIndex, greaterThan(0));
  });

  test('honours the maxFiles bound, taking the highest-churn files first',
      () async {
    await writeSource('lib/high.dart', branchySource);
    await writeSource('lib/low.dart', branchySource);

    final metrics = await sampler.sampleTopChurnFiles(
      tempDir.path,
      {'lib/high.dart': 100, 'lib/low.dart': 1},
      maxFiles: 1,
    );

    expect(metrics.single.filePath, 'lib/high.dart');
  });

  test('skips oversized files instead of lexing them', () async {
    await writeSource('lib/huge.dart', branchySource);
    await writeSource('lib/small.dart', branchySource);

    final metrics = await sampler.sampleTopChurnFiles(
      tempDir.path,
      {'lib/huge.dart': 100, 'lib/small.dart': 1},
      maxFileSizeBytes: 10,
    );

    expect(metrics, isEmpty);
  });

  test('skips deleted files without failing the report', () async {
    await writeSource('lib/present.dart', branchySource);

    final metrics = await sampler.sampleTopChurnFiles(
        tempDir.path, {'lib/deleted.dart': 100, 'lib/present.dart': 1});

    expect(metrics.single.filePath, 'lib/present.dart');
  });

  test('rejects churn paths escaping the repository directory', () async {
    final outside = File(p.join(tempDir.parent.path, 'outside_sampler.dart'));
    await outside.writeAsString(branchySource);
    addTearDown(() => outside.delete());

    final metrics = await sampler
        .sampleTopChurnFiles(tempDir.path, {'../outside_sampler.dart': 100});

    expect(metrics, isEmpty);
  });

  test('returns empty for empty churn', () async {
    expect(await sampler.sampleTopChurnFiles(tempDir.path, const {}), isEmpty);
  });
}
