import 'dart:io';

import 'prompt_codegen.dart';

/// sync_prompts.dart
///
/// Regenerates the MCP prompt Dart sources in `lib/src/mcp/prompts/` from their
/// canonical skill definitions in `.agents/skills/<name>/SKILL.md`, so the
/// agent-facing workflow text has a single source of truth.
///
/// Usage:
///   dart run tool/sync_prompts.dart           # write/refresh the prompt files
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

  var drift = false;
  for (final skillName in promptSkillNames) {
    final skillFile = File('${skillsDir.path}/$skillName/SKILL.md');
    if (!skillFile.existsSync()) {
      stderr.writeln('Missing canonical skill: ${skillFile.path}');
      exit(2);
    }

    final doc = parseSkill(skillFile.readAsStringSync());
    if (!bodyIsRawSafe(doc.body)) {
      stderr.writeln("$skillName: body contains \"'''\" which cannot be "
          'emitted as a raw Dart string.');
      exit(2);
    }

    final outFile = File('${promptsDir.path}/${dartFileName(skillName)}');
    final generated = generatePromptSource(doc);

    if (check) {
      if (!outFile.existsSync()) {
        stderr.writeln('Missing generated prompt: ${outFile.path}');
        drift = true;
        continue;
      }
      // Format-independent comparison: the on-disk prompt is in sync if its
      // name, description, and body match the canonical skill.
      final onDisk = extractFromPromptSource(outFile.readAsStringSync());
      final inSync = onDisk.name == doc.name &&
          onDisk.description == doc.description &&
          onDisk.body.trimRight() == doc.body.trimRight();
      if (!inSync) {
        stderr.writeln('DRIFT: ${outFile.path} is out of sync with '
            '${skillFile.path}. Run `dart run tool/sync_prompts.dart`.');
        drift = true;
      }
    } else {
      outFile.writeAsStringSync(generated);
      stdout.writeln('Generated ${outFile.path}');
    }
  }

  if (check && drift) exit(1);
  if (!check) {
    stdout
        .writeln('Done. Run: dart format --line-length=80 ${promptsDir.path}');
  }
}
