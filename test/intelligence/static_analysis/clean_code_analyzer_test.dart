import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// The clean-code analyzer is the library-first core (ADR-0005) shared by
/// the `analyze_clean_code` MCP tool and the report meta-tools' bounded
/// top-churn sample. These tests pin the heuristic thresholds (Martin
/// 2008; Fowler 1999; Koschke 2007) so a change is a deliberate ADR-0010
/// act.
void main() {
  const analyzer = CleanCodeAnalyzer();

  test('clean source yields zero issues', () {
    final metrics = analyzer.analyzeSource(
      'lib/clean.dart',
      'void main() {\n  print("ok");\n}\n',
    );

    expect(metrics.totalLines, 3);
    expect(metrics.issues, isEmpty);
    expect(metrics.magicNumbers, 0);
  });

  test('file longer than 300 lines is a Single Responsibility issue', () {
    final source = List.filled(
      301,
      'var uniqueLine;',
    ).asMap().entries.map((entry) => 'var uniqueLine${entry.key};').join('\n');
    final metrics = analyzer.analyzeSource('lib/long.dart', source);

    expect(metrics.totalLines, 301);
    expect(metrics.issues.single, contains('too long'));
  });

  test('nesting depth of 5+ levels is arrow code', () {
    final source = '${' ' * 20}deeplyNested();\nshallow();\n';
    final metrics = analyzer.analyzeSource('lib/nested.dart', source);

    expect(metrics.maxIndentationLevel, 5);
    expect(metrics.issues.single, contains('Deep nesting'));
  });

  test('magic numbers above 10 are flagged; comments are ignored', () {
    final magicLines = [
      for (var i = 0; i < 11; i++) 'value$i = ${i + 42};',
      '// 999 inside a comment does not count',
    ].join('\n');
    final metrics = analyzer.analyzeSource('lib/magic.dart', magicLines);

    expect(metrics.magicNumbers, 11);
    expect(metrics.issues.single, contains('magic number'));
  });

  test('duplicate lines above 10% of the file are Type-1 clones', () {
    final source = List.filled(10, 'repeatedStatement();').join('\n');
    final metrics = analyzer.analyzeSource('lib/clones.dart', source);

    expect(metrics.duplicateLines, 9);
    expect(metrics.issues.any((issue) => issue.contains('duplicate')), isTrue);
  });

  test('analyzeSources maps every entry off the main isolate', () async {
    final results = await analyzer.analyzeSources({
      'lib/a.dart': 'void a() {}\n',
      'lib/b.dart': 'void b() {}\n',
    });

    expect(results.map((m) => m.filePath), ['lib/a.dart', 'lib/b.dart']);
  });

  test('analyzeSources returns empty for an empty sample', () async {
    expect(await analyzer.analyzeSources({}), isEmpty);
  });
}
