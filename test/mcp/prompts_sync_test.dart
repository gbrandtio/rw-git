import 'dart:io';

import 'package:rw_git/src/intelligence/interpretation/report_tool_sources.dart';
import 'package:test/test.dart';

import '../../tool/prompt_codegen.dart';

/// Guards the single-source-of-truth invariant for agent workflows, on two
/// axes:
///   1. every `.agents/skills/<name>/SKILL.md` must equal its
///      `SKILL.template.md` expanded with the shared partials in
///      `.agents/skills/_shared/` and the `generate:` markers rendered from
///      [reportToolSources] (plus the generated-file notice);
///   2. every MCP prompt Dart file in `lib/src/mcp/prompts/` must match the
///      expanded template's name/description/body.
/// If either drifts, run `dart run tool/sync_prompts.dart` to regenerate.
void main() {
  String readPartial(String relativePath) =>
      File('.agents/skills/_shared/$relativePath').readAsStringSync();

  String renderGenerated(String directive, String reportType) =>
      switch (directive) {
        'deep_dive_tools' => renderDeepDiveTools(reportType),
        _ => throw FormatException('Unknown generate directive: $directive'),
      };

  String expandedTemplate(String skillName) => expandGenerated(
      expandIncludes(
          File('.agents/skills/$skillName/SKILL.template.md')
              .readAsStringSync(),
          readPartial),
      renderGenerated);

  group('SKILL.md files are generated from their templates', () {
    for (final skillName in promptSkillNames) {
      test('$skillName SKILL.md matches its expanded template', () {
        final skill = File('.agents/skills/$skillName/SKILL.md');
        expect(skill.existsSync(), isTrue,
            reason: 'generated skill missing: ${skill.path}');
        expect(skill.readAsStringSync(),
            renderGeneratedSkill(expandedTemplate(skillName)),
            reason: 'SKILL.md drifted from SKILL.template.md. '
                'Run: dart run tool/sync_prompts.dart');
      });
    }
  });

  group('prompts are generated from the canonical templates', () {
    for (final skillName in promptSkillNames) {
      test('$skillName prompt matches its expanded template', () {
        final prompt = File('lib/src/mcp/prompts/${dartFileName(skillName)}');
        expect(prompt.existsSync(), isTrue,
            reason: 'generated prompt missing: ${prompt.path}');

        final canonical = parseSkill(expandedTemplate(skillName));
        final onDisk = extractFromPromptSource(prompt.readAsStringSync());

        expect(onDisk.name, canonical.name);
        expect(onDisk.description, canonical.description);
        expect(onDisk.body.trimRight(), canonical.body.trimRight(),
            reason: 'Prompt body drifted from SKILL.template.md. '
                'Run: dart run tool/sync_prompts.dart');
      });
    }

    test('shared partials are actually shared (contract appears once)', () {
      // The contract block must come from the single partial, not be
      // re-duplicated per template: templates reference it by marker.
      for (final skillName in promptSkillNames) {
        final template = File('.agents/skills/$skillName/SKILL.template.md')
            .readAsStringSync();
        expect(template, contains('<!-- include:reporting_contract.md -->'),
            reason: '$skillName template must include the shared contract');
        expect(
            template.contains('If a payload is missing these fields'), isFalse,
            reason: '$skillName template must not inline the contract text');
      }
    });

    test('deep-dive escalation rides every reporting skill', () {
      for (final skillName in promptSkillNames) {
        final expanded = expandedTemplate(skillName);
        expect(expanded, contains('<deep_dive'),
            reason: '$skillName lost its capable-model deep-dive section');
        expect(expanded, contains('read_report_slice'),
            reason: '$skillName deep-dive must route through '
                'read_report_slice');
      }
    });

    test('generated notice never leaks into prompt bodies', () {
      for (final skillName in promptSkillNames) {
        final prompt = File('lib/src/mcp/prompts/${dartFileName(skillName)}');
        final onDisk = extractFromPromptSource(prompt.readAsStringSync());
        expect(onDisk.body.contains('GENERATED FILE'), isFalse,
            reason: 'agents must not pay tokens for the generation notice');
      }
    });

    test('drift is detectable (negative control)', () {
      final canonical = parseSkill(expandedTemplate(_anySkill));
      final tampered = SkillDoc(
          canonical.name, canonical.description, '${canonical.body}\nDRIFT');
      expect(tampered.body.trimRight() == canonical.body.trimRight(), isFalse);
    });
  });

  group('expandIncludes', () {
    test('substitutes markers and trims partial trailing newlines', () {
      final expanded = expandIncludes(
          'a\n<!-- include:x.md -->\nb', (path) => 'partial for $path\n');
      expect(expanded, 'a\npartial for x.md\nb');
    });

    test('leaves text without markers untouched', () {
      expect(
          expandIncludes('plain', (_) => fail('must not be called')), 'plain');
    });
  });

  group('generated deep-dive tool lists are catalog-native', () {
    test(
        'the consolidated skill carries a deep_dive tool list for every '
        'report type, each matching reportToolSources exactly, in order', () {
      final expanded = expandedTemplate(_anySkill);
      for (final entry in reportToolSources.entries) {
        final expectedLine =
            'Raw tools for this report: ${entry.value.map((t) => '`$t`').join(', ')}.';

        expect(expanded, contains(expectedLine),
            reason: '$_anySkill must carry a deep_dive tool list generated '
                'from reportToolSources[\'${entry.key}\']');
      }
    });

    test('expandGenerated throws on an unknown report type', () {
      expect(() => renderDeepDiveTools('not_a_real_report_type'),
          throwsA(isA<FormatException>()));
    });

    test('expandGenerated throws on an unknown directive', () {
      expect(
          () => expandGenerated(
              '<!-- generate:not_a_directive report=technical -->',
              renderGenerated),
          throwsA(isA<FormatException>()));
    });
  });
}

const _anySkill = 'rw-git-mcp-reporting';
