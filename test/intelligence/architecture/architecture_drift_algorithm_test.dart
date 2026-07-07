import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/constants.dart';
import 'package:rw_git/src/core/result.dart';
import 'package:rw_git/src/vcs/git_query.dart';
import 'package:test/test.dart';

/// The architecture-drift algorithm is the library-first core (ADR-0005)
/// shared by the `analyze_architecture_drift` MCP tool and the report
/// meta-tools. These tests pin the smell thresholds (Garcia, Oliveira &
/// Murta 2009) and the layer-inference heuristic the reports rely on, so a
/// change to either is a deliberate ADR-0010 act.
class _MockGitQuery implements GitQuery {
  final String logOutput;
  List<String>? lastArgs;

  _MockGitQuery(this.logOutput);

  @override
  Future<Result<String, RwGitException>> run(
    String directory,
    List<String> args,
  ) async {
    lastArgs = args;
    return Success(logOutput);
  }
}

void main() {
  final layers = {
    'ui': RegExp('^ui/'),
    'data': RegExp('^data/'),
    'domain': RegExp('^domain/'),
    'infra': RegExp('^infra/'),
  };

  test('flags commits spanning multiple layers and builds the matrix',
      () async {
    const log = 'aaa||cross-layer change\n'
        'ui/screen.dart\n'
        'data/repo.dart\n'
        '\n'
        'bbb||single-layer change\n'
        'ui/other.dart\n';
    final drift = await ArchitectureDriftAlgorithm(_MockGitQuery(log))
        .execute('.', layers);

    expect(drift.totalCommitsAnalyzed, 2);
    expect(drift.driftCommits, hasLength(1));
    expect(drift.driftCommits.single.layersCoupled, ['data', 'ui']);
    expect(drift.couplingMatrix['ui']!['data'], 1);
    expect(drift.couplingRatio, 0.5);
  });

  test('forwards since and until as git flags', () async {
    final query = _MockGitQuery('');
    await ArchitectureDriftAlgorithm(query)
        .execute('.', layers, since: '2024-01-01', until: '2024-12-31');
    expect(query.lastArgs, contains('--since=2024-01-01'));
    expect(query.lastArgs, contains('--until=2024-12-31'));
  });

  test('empty history yields the empty result', () async {
    final drift = await ArchitectureDriftAlgorithm(_MockGitQuery(''))
        .execute('.', layers);
    expect(drift.totalCommitsAnalyzed, 0);
    expect(drift.driftCommits, isEmpty);
    expect(drift.smells, isEmpty);
  });

  test(
      'God Component: a layer in more than half of drift commits '
      '(Garcia et al. 2009)', () async {
    const log = 'aaa||one\nui/a.dart\ndata/b.dart\n\n'
        'bbb||two\nui/c.dart\ndomain/d.dart\n\n'
        'ccc||three\nui/e.dart\ninfra/f.dart\n';
    final drift = await ArchitectureDriftAlgorithm(_MockGitQuery(log))
        .execute('.', layers);

    final god = drift.smells.where((s) => s.type == 'God Component');
    expect(god.single.layer, 'ui');
  });

  test('Scattered Functionality: commits touching 3+ layers', () async {
    const log = 'aaa||wide\nui/a.dart\ndata/b.dart\ndomain/c.dart\n';
    final drift = await ArchitectureDriftAlgorithm(_MockGitQuery(log))
        .execute('.', layers);

    final scattered =
        drift.smells.where((s) => s.type == 'Scattered Functionality');
    expect(scattered.single.count, 1);
  });

  group('inferLayerPatterns', () {
    test('descends generic containers and uses the first meaningful dir', () {
      final patterns = ArchitectureDriftAlgorithm.inferLayerPatterns([
        'lib/src/mcp/server.dart',
        'lib/src/mcp/registry.dart',
        'lib/src/intelligence/interpretation.dart',
        'tool/codegen.dart',
      ]);

      expect(patterns.keys,
          containsAll(['lib/src/mcp', 'lib/src/intelligence', 'tool']));
      expect(
          patterns['lib/src/mcp']!.hasMatch('lib/src/mcp/server.dart'), isTrue);
      expect(patterns['lib/src/mcp']!.hasMatch('lib/src/mcpx/other.dart'),
          isFalse);
    });

    test('excludes tests, docs, build output, and dot-directories', () {
      final patterns = ArchitectureDriftAlgorithm.inferLayerPatterns([
        'test/mcp/a_test.dart',
        'doc/guide.md',
        'build/out.js',
        '.github/workflows/ci.yml',
        'lib/src/core/a.dart',
        'lib/src/vcs/b.dart',
      ]);

      expect(patterns.keys, ['lib/src/core', 'lib/src/vcs']);
    });

    test('returns empty below the minimum layer count', () {
      expect(
          ArchitectureDriftAlgorithm.inferLayerPatterns(
              ['lib/src/core/a.dart', 'lib/src/core/b.dart', 'README.md']),
          isEmpty);
    });

    test('caps inferred layers at the configured maximum', () {
      final paths = [
        for (var layer = 0; layer < 20; layer++)
          for (var file = 0; file <= layer; file++)
            'module$layer/file$file.dart',
      ];
      final patterns = ArchitectureDriftAlgorithm.inferLayerPatterns(paths);

      expect(patterns, hasLength(maxInferredArchitectureLayers));
      // Ranked by file count: the most-populated modules survive the cap.
      expect(patterns.keys, contains('module19'));
      expect(patterns.keys, isNot(contains('module0')));
    });
  });
}
