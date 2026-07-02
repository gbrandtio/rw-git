import 'dart:io';

import 'prompt_codegen.dart';

/// sync_prompts.dart
///
/// Regenerates, from each canonical `.agents/skills/<name>/SKILL.template.md`
/// (plus the shared partials in `.agents/skills/_shared/`):
///   1. the agent-facing `.agents/skills/<name>/SKILL.md` (the expanded
///      template with a generated-file notice), and
///   2. the MCP prompt Dart source in `lib/src/mcp/prompts/`.
/// The template is the single source of truth; shared blocks (contract,
/// prepare step, deep-dive intro) live once under `_shared/`.
///
/// Usage:
///   dart run tool/sync_prompts.dart           # write/refresh both outputs
///   dart run tool/sync_prompts.dart --check    # verify only; exit 1 on drift
///
/// After writing, run `dart format --line-length=80 lib/src/mcp/prompts`.
void main(List<String> args) {
  final check = args.contains('--check');
  final skillsDir = Directory('.agents/skills');
  final promptsDir = Directory('lib/src/mcp/prompts');

  if (!skillsDir.existsSync()) {
    stderr
        .writeln('Run from the repository root: ${skillsDir.path} not found.');
    exit(2);
  }

  String readPartial(String relativePath) {
    final partial = File('${skillsDir.path}/_shared/$relativePath');
    if (!partial.existsSync()) {
      stderr.writeln('Missing shared partial: ${partial.path}');
      exit(2);
    }
    return partial.readAsStringSync();
  }

  var drift = false;
  for (final skillName in promptSkillNames) {
    final templateFile = File('${skillsDir.path}/$skillName/SKILL.template.md');
    if (!templateFile.existsSync()) {
      stderr.writeln('Missing canonical template: ${templateFile.path}');
      exit(2);
    }

    final expanded =
        expandIncludes(templateFile.readAsStringSync(), readPartial);
    final doc = parseSkill(expanded);
    if (!bodyIsRawSafe(doc.body)) {
      stderr.writeln("$skillName: body contains \"'''\" which cannot be "
          'emitted as a raw Dart string.');
      exit(2);
    }

    final skillFile = File('${skillsDir.path}/$skillName/SKILL.md');
    final generatedSkill = renderGeneratedSkill(expanded);
    final promptFile = File('${promptsDir.path}/${dartFileName(skillName)}');
    final generatedPrompt = generatePromptSource(doc);

    if (check) {
      if (!skillFile.existsSync() ||
          skillFile.readAsStringSync() != generatedSkill) {
        stderr.writeln('DRIFT: ${skillFile.path} is out of sync with '
            '${templateFile.path}. Run `dart run tool/sync_prompts.dart`.');
        drift = true;
      }
      if (!promptFile.existsSync()) {
        stderr.writeln('Missing generated prompt: ${promptFile.path}');
        drift = true;
        continue;
      }
      // Format-independent comparison: the on-disk prompt is in sync if its
      // name, description, and body match the canonical expanded template.
      final onDisk = extractFromPromptSource(promptFile.readAsStringSync());
      final inSync = onDisk.name == doc.name &&
          onDisk.description == doc.description &&
          onDisk.body.trimRight() == doc.body.trimRight();
      if (!inSync) {
        stderr.writeln('DRIFT: ${promptFile.path} is out of sync with '
            '${templateFile.path}. Run `dart run tool/sync_prompts.dart`.');
        drift = true;
      }
    } else {
      skillFile.writeAsStringSync(generatedSkill);
      promptFile.writeAsStringSync(generatedPrompt);
      stdout.writeln('Generated ${skillFile.path} and ${promptFile.path}');
    }
  }

  if (check && drift) exit(1);
  if (!check) {
    stdout
        .writeln('Done. Run: dart format --line-length=80 ${promptsDir.path}');
  }
}
