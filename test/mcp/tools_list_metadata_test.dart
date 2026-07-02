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

    test(
        'per-tool offload thresholds are wired into the advertised '
        'descriptions', () {
      // ADR-0011: report meta-tools offload aggressively, compact history
      // tools stay inline longer, everything else keeps the 8 KiB default.
      // The advertised description is the contract the model sees.
      expect(byName('generate_pm_report')['description'], contains('>4KB'));
      expect(byName('get_stats')['description'], contains('>16KB'));
      expect(byName('analyze_bug_hotspots')['description'], contains('>8KB'));
    });

    test(
        'outputSchema is advertised only for stable shapes that drive '
        'structuredContent (ADR-0013)', () {
      // Report meta-tools and a handful of fixed-shape tools carry a schema.
      for (final name in [
        'generate_repository_audit',
        'generate_technical_report',
        'generate_security_report',
        'generate_pm_report',
        'generate_code_review_report',
        'get_stats',
        'is_git_repository',
        'fetch_tags',
        'calculate_universal_lexical_metrics',
        'init_repository',
        'clone_repository',
      ]) {
        final schema = byName(name)['outputSchema'] as Map<String, dynamic>?;
        expect(schema, isNotNull, reason: '$name should advertise a schema');
        expect(schema!['type'], 'object', reason: name);
      }

      // Analysis tools whose broad shape the offload preview already conveys
      // at response time must not pay the fixed tools/list cost of a schema.
      for (final name in [
        'analyze_bus_factor',
        'analyze_bug_hotspots',
        'analyze_code_quality',
        'analyze_commit_velocity',
        'detect_secrets_in_commits',
        'analyze_dart_ast_quality',
        'read_report_slice',
        'get_rw_git_documentation',
      ]) {
        expect(byName(name).containsKey('outputSchema'), isFalse,
            reason: '$name must not advertise an outputSchema');
      }
    });

    test('report meta-tool schema pins the classified-findings contract', () {
      final schema = byName('generate_technical_report')['outputSchema']
          as Map<String, dynamic>;
      final properties = schema['properties'] as Map;
      expect(
          properties.keys,
          containsAll(
              ['report_type', 'summary', 'top_findings', 'compound_findings']));
    });
  });
}
