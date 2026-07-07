import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// Verifies the report meta-tools' contract (name/schema/annotations) and that
/// each produces a valid, pre-interpreted payload against the current repo.
void main() {
  final runner = StandardProcessRunner();

  final tools = <String, McpTool>{
    'generate_technical_report': GenerateTechnicalReportTool(runner),
    'generate_pm_report': GeneratePmReportTool(runner),
    'generate_code_review_report': GenerateCodeReviewReportTool(runner),
    'generate_security_report': GenerateSecurityReportTool(runner),
    'generate_repository_audit': GenerateRepositoryAuditTool(runner),
  };

  group('report meta-tools contract', () {
    tools.forEach((name, tool) {
      test('$name exposes name, description and directory schema', () {
        expect(tool.name, name);
        expect(tool.description, isNotEmpty);
        final props = tool.inputSchema['properties'] as Map<String, dynamic>;
        expect(props.containsKey('directory'), isTrue);
        expect((tool.inputSchema['required'] as List), contains('directory'));
      });

      test('$name exposes since/until in its schema', () {
        final props = tool.inputSchema['properties'] as Map<String, dynamic>;
        expect(props.containsKey('since'), isTrue);
        expect(props.containsKey('until'), isTrue);
      });
    });
  });

  group('report meta-tools execution', () {
    test('technical report returns a pre-interpreted payload', () async {
      final raw = await tools['generate_technical_report']!
          .execute({'directory': './', 'limit': '80'});
      final json = jsonDecode(raw) as Map<String, dynamic>;

      expect(json['report_type'], 'technical');
      expect(json.containsKey('summary'), isTrue);
      expect(json['top_findings'], isA<List>());
      expect(json['compound_findings'], isA<List>());
      // Every finding is already classified with a severity band.
      for (final f in (json['top_findings'] as List)) {
        expect((f as Map).containsKey('severity'), isTrue);
        expect(f.containsKey('subject'), isTrue);
        expect(f.containsKey('band'), isTrue);
      }
    });

    test('pm report returns a pre-interpreted payload', () async {
      final raw = await tools['generate_pm_report']!
          .execute({'directory': './', 'limit': '80'});
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['report_type'], 'pm');
      expect(json['top_findings'], isA<List>());
    });

    test('ReportOrchestrator is reusable from the library directly', () async {
      final payload =
          await ReportOrchestrator(runner).technicalReport('./', limit: '60');
      expect(payload.reportType, 'technical');
      expect(payload.toJson()['guidance'], isA<String>());
    });

    test('technical report accepts since/until and echoes them in metadata',
        () async {
      final raw = await tools['generate_technical_report']!.execute({
        'directory': './',
        'limit': '80',
        'since': '2024-01-01',
        'until': '2024-12-31',
      });
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['report_type'], 'technical');
      final metadata = json['metadata'] as Map<String, dynamic>;
      expect(metadata['since'], '2024-01-01');
      expect(metadata['until'], '2024-12-31');
    });

    test('technical report omits since/until from metadata when not supplied',
        () async {
      final raw = await tools['generate_technical_report']!
          .execute({'directory': './', 'limit': '80'});
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final metadata = json['metadata'] as Map<String, dynamic>;
      expect(metadata.containsKey('since'), isFalse);
      expect(metadata.containsKey('until'), isFalse);
    });

    test('technical report rejects an invalid since value', () async {
      final raw = await tools['generate_technical_report']!.execute({
        'directory': './',
        'since': 'not-a-date',
      });
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['error'], contains('Invalid "since"'));
    });

    test('pm report rejects an invalid until value', () async {
      final raw = await tools['generate_pm_report']!.execute({
        'directory': './',
        'until': 'not-a-date',
      });
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['error'], contains('Invalid "until"'));
    });
  });
}
