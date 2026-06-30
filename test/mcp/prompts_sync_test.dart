import 'dart:io';

import 'package:test/test.dart';

import '../../tool/prompt_codegen.dart';

/// Guards the single-source-of-truth invariant for agent workflows: every MCP
/// prompt Dart file in `lib/src/mcp/prompts/` must stay in sync with its
/// canonical skill in `.agents/skills/<name>/SKILL.md`. If they drift, run
/// `dart run tool/sync_prompts.dart` to regenerate the prompts.
void main() {
  group('prompts are generated from canonical SKILL.md', () {
    for (final skillName in promptSkillNames) {
      test('$skillName prompt matches its skill', () {
        final skill = File('.agents/skills/$skillName/SKILL.md');
        final prompt = File('lib/src/mcp/prompts/${dartFileName(skillName)}');
        expect(skill.existsSync(), isTrue,
            reason: 'canonical skill missing: ${skill.path}');
        expect(prompt.existsSync(), isTrue,
            reason: 'generated prompt missing: ${prompt.path}');

        final canonical = parseSkill(skill.readAsStringSync());
        final onDisk = extractFromPromptSource(prompt.readAsStringSync());

        expect(onDisk.name, canonical.name);
        expect(onDisk.description, canonical.description);
        expect(onDisk.body.trimRight(), canonical.body.trimRight(),
            reason: 'Prompt body drifted from SKILL.md. '
                'Run: dart run tool/sync_prompts.dart');
      });
    }

    test('drift is detectable (negative control)', () {
      final canonical = parseSkill(
          File('.agents/skills/$_anySkill/SKILL.md').readAsStringSync());
      final tampered = SkillDoc(
          canonical.name, canonical.description, '${canonical.body}\nDRIFT');
      expect(tampered.body.trimRight() == canonical.body.trimRight(), isFalse);
    });
  });
}

const _anySkill = 'rw-git-mcp-reporting';
