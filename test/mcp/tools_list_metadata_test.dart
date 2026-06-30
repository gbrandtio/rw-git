import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// Verifies the standard MCP metadata the server advertises in `tools/list`:
/// read-only analysis tools carry `readOnlyHint: true` (so clients may
/// auto-approve them), repository-mutating tools carry `readOnlyHint: false`,
/// and tools with a stable shape may expose an `outputSchema`.
void main() {
  final listings =
      buildDefaultRegistry(runner: MockProcessRunner()).getToolListings();
  Map<String, dynamic> byName(String name) =>
      listings.firstWhere((t) => t['name'] == name);

  group('tools/list metadata', () {
    test('read-only tools are annotated readOnlyHint:true', () {
      for (final name in [
        'analyze_bug_hotspots',
        'analyze_bus_factor',
        'detect_secrets_in_commits',
        'get_stats',
        'is_git_repository',
        'get_rw_git_documentation',
        'read_report_slice',
      ]) {
        final ann = byName(name)['annotations'] as Map<String, dynamic>?;
        expect(ann, isNotNull, reason: '$name should be annotated');
        expect(ann!['readOnlyHint'], isTrue,
            reason: '$name should be read-only');
      }
    });

    test('mutating tools are annotated readOnlyHint:false', () {
      for (final name in [
        'init_repository',
        'clone_repository',
        'checkout_branch',
        'fetch_tags',
      ]) {
        final ann = byName(name)['annotations'] as Map<String, dynamic>?;
        expect(ann, isNotNull, reason: '$name should be annotated');
        expect(ann!['readOnlyHint'], isFalse, reason: '$name mutates state');
      }
    });

    test('a stable-shape tool advertises an outputSchema', () {
      final schema =
          byName('analyze_bus_factor')['outputSchema'] as Map<String, dynamic>?;
      expect(schema, isNotNull);
      expect(schema!['type'], 'object');
      expect((schema['properties'] as Map).containsKey('bus_factor'), isTrue);
    });
  });
}
