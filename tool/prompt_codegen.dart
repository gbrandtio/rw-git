/// prompt_codegen.dart
///
/// Pure, side-effect-free helpers for turning a canonical agent skill
/// template (`.agents/skills/<name>/SKILL.template.md`, expanded with the
/// shared partials in `.agents/skills/_shared/`) into both the agent-facing
/// `SKILL.md` and its MCP prompt Dart source
/// (`lib/src/mcp/prompts/<name>_prompt.dart`).
///
/// Shared by `tool/sync_prompts.dart` (the generator CLI) and
/// `test/mcp/prompts_sync_test.dart` (the drift guard) so the two can never
/// disagree about what "in sync" means.
library;

import 'package:rw_git/src/intelligence/interpretation/report_tool_sources.dart';

/// The skill names that have a corresponding MCP prompt. The single
/// `rw-git-mcp-reporting` skill covers every report type via its
/// report-selection table and per-report deep-dive subsections;
/// `rw-git-mcp-installation` is intentionally excluded — it is a human
/// setup guide, not an agent workflow.
const List<String> promptSkillNames = [
  'rw-git-mcp-reporting',
];

/// A parsed SKILL.md: its frontmatter `name`/`description` and markdown body.
class SkillDoc {
  final String name;
  final String description;
  final String body;

  const SkillDoc(this.name, this.description, this.body);
}

/// Parses the YAML-ish frontmatter and body out of a SKILL.md [raw] string.
SkillDoc parseSkill(String raw) {
  final normalized = raw.replaceAll('\r\n', '\n');
  if (!normalized.startsWith('---')) {
    throw const FormatException(
        'SKILL.md must start with a "---" frontmatter block.');
  }
  final end = normalized.indexOf('\n---', 3);
  if (end == -1) {
    throw const FormatException(
        'SKILL.md frontmatter is not terminated by "---".');
  }
  final frontmatter = normalized.substring(3, end);
  // Body starts after the line that closes the frontmatter.
  final afterClose = normalized.indexOf('\n', end + 1);
  final body = afterClose == -1
      ? ''
      : normalized.substring(afterClose + 1).replaceFirst(RegExp(r'^\n+'), '');

  String? name;
  String? description;
  for (final line in frontmatter.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('name:')) {
      name = _unquote(trimmed.substring('name:'.length).trim());
    } else if (trimmed.startsWith('description:')) {
      description = _unquote(trimmed.substring('description:'.length).trim());
    }
  }
  if (name == null || name.isEmpty) {
    throw const FormatException('SKILL.md frontmatter is missing "name".');
  }
  if (description == null || description.isEmpty) {
    throw const FormatException(
        'SKILL.md frontmatter is missing "description".');
  }
  return SkillDoc(name, description, body);
}

String _unquote(String rawValue) {
  if (rawValue.length >= 2 &&
      ((rawValue.startsWith('"') && rawValue.endsWith('"')) ||
          (rawValue.startsWith("'") && rawValue.endsWith("'")))) {
    return rawValue.substring(1, rawValue.length - 1);
  }
  return rawValue;
}

/// `rw-git-mcp-pm-reporting` -> `RwGitMcpPmReportingPrompt`.
String dartClassName(String skillName) {
  final pascal = skillName
      .split('-')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join();
  return '${pascal}Prompt';
}

/// `rw-git-mcp-pm-reporting` -> `rw_git_mcp_pm_reporting_prompt.dart`.
String dartFileName(String skillName) =>
    '${skillName.replaceAll('-', '_')}_prompt.dart';

/// Renders the full Dart source for the prompt class described by [doc].
String generatePromptSource(SkillDoc doc) {
  final className = dartClassName(doc.name);
  final fileName = dartFileName(doc.name);
  final desc = _escapeSingleQuoted(doc.description);
  // Bodies are emitted as raw triple-quoted strings; verified to be free of
  // a `'''` sequence by [bodyIsRawSafe].
  final body = doc.body;

  return '''
import '../mcp_prompt.dart';

/// $fileName
/// Provides the ${doc.name} skill as an MCP Prompt.
///
/// GENERATED FILE — do not edit by hand. Edit the canonical template at
/// `.agents/skills/${doc.name}/SKILL.template.md` and run
/// `dart run tool/sync_prompts.dart`.
class $className implements McpPrompt {
  @override
  String get name => '${doc.name}';

  @override
  String get description =>
      '$desc';

  @override
  List<Map<String, dynamic>> get messages => [
        {
          'role': 'user',
          'content': {
            'type': 'text',
            'text': _promptText,
          }
        }
      ];

  static const String _promptText = r\'\'\'
$body\'\'\';
}
''';
}

/// A raw triple-quoted Dart string cannot contain `'''`.
bool bodyIsRawSafe(String body) => !body.contains("'''");

/// Matches an include marker line in a `SKILL.template.md`:
/// `<!-- include:reporting_contract.md -->` — the path is relative to
/// `.agents/skills/_shared/`.
final RegExp includeMarkerPattern = RegExp(r'<!--\s*include:([^\s]+)\s*-->');

/// Expands every include marker in [template] by substituting the shared
/// partial returned by [readPartial] (called with the marker's relative
/// path). Pure so the generator CLI and the drift-guard test can never
/// disagree about what an expanded skill looks like.
String expandIncludes(
    String template, String Function(String relativePath) readPartial) {
  return template.replaceAllMapped(includeMarkerPattern,
      (match) => readPartial(match.group(1)!).trimRight());
}

/// Matches a generation marker in a `SKILL.template.md`, e.g.
/// `<!-- generate:deep_dive_tools report=technical -->`. Unlike
/// [includeMarkerPattern], the substituted content is derived from Dart data
/// ([reportToolSources]) rather than a static partial file, so it needs its
/// own directive name and report-type parameter.
final RegExp generateMarkerPattern =
    RegExp(r'<!--\s*generate:(\w+)\s+report=(\w+)\s*-->');

/// Expands every `<!-- generate:directive report=reportType -->` marker in
/// [template] by calling [render] with the directive name and report type.
/// Pure — mirrors [expandIncludes], so a typo'd `report=` value fails loudly
/// through whatever [render] throws rather than emitting nothing.
String expandGenerated(String template,
    String Function(String directive, String reportType) render) {
  return template.replaceAllMapped(generateMarkerPattern,
      (match) => render(match.group(1)!, match.group(2)!).trimRight());
}

/// Renders the `<deep_dive>` raw-tool list for [reportType] from
/// [reportToolSources]: one prose line naming every tool that feeds that
/// report, in map order. Every listed tool is a `toolHintsCatalog` key, so
/// calling it directly surfaces its own `pair_with` guidance (via
/// `McpToolHintsDecorator`) without needing to duplicate that prose here.
String renderDeepDiveTools(String reportType) {
  final tools = reportToolSources[reportType];
  if (tools == null) {
    throw FormatException(
        'Unknown report type in generate:deep_dive_tools marker: '
        '$reportType. Known types: ${reportToolSources.keys.join(', ')}.');
  }

  final entries = tools.map((tool) => '`$tool`');
  return 'Raw tools for this report: ${entries.join(', ')}.';
}

/// The notice inserted into every generated `SKILL.md` so a contributor
/// edits the template, not the expansion. Stripped before prompt
/// generation so agents never pay tokens for it.
const String generatedSkillNotice =
    '<!-- GENERATED FILE — do not edit by hand. Edit SKILL.template.md in '
    'this directory and run `dart run tool/sync_prompts.dart`. -->';

/// Renders the on-disk `SKILL.md` content for an [expandedTemplate]:
/// the frontmatter, the generated-file notice, then the body.
String renderGeneratedSkill(String expandedTemplate) {
  final normalized = expandedTemplate.replaceAll('\r\n', '\n');
  final frontmatterEnd = normalized.indexOf('\n---', 3);
  if (!normalized.startsWith('---') || frontmatterEnd == -1) {
    throw const FormatException(
        'SKILL.template.md must start with a "---" frontmatter block.');
  }
  final afterClose = normalized.indexOf('\n', frontmatterEnd + 1);
  final head = normalized.substring(0, afterClose + 1);
  final body =
      normalized.substring(afterClose + 1).replaceFirst(RegExp(r'^\n+'), '');
  return '$head\n$generatedSkillNotice\n\n$body';
}

String _escapeSingleQuoted(String rawValue) => rawValue
    .replaceAll('\\', '\\\\')
    .replaceAll('\$', '\\\$')
    .replaceAll("'", "\\'");

/// Extracts the `name`, `description`, and raw `_promptText` body from an
/// already-generated prompt Dart [source]. Used by the drift test to compare
/// on-disk prompts against their canonical skill without depending on exact
/// formatting.
SkillDoc extractFromPromptSource(String source) {
  final nameMatch =
      RegExp(r"String get name =>\s*'([^']*)'").firstMatch(source);
  final descMatch = RegExp(r"String get description =>\s*'((?:\\.|[^'\\])*)'")
      .firstMatch(source);
  final start = source.indexOf("r'''");
  final bodyStart = source.indexOf('\n', start) + 1;
  final bodyEnd = source.lastIndexOf("'''");
  if (nameMatch == null ||
      descMatch == null ||
      start == -1 ||
      bodyEnd <= start) {
    throw const FormatException('Could not parse generated prompt source.');
  }
  final name = nameMatch.group(1)!;
  final description = _unescapeSingleQuoted(descMatch.group(1)!);
  final body = source.substring(bodyStart, bodyEnd);
  return SkillDoc(name, description, body);
}

String _unescapeSingleQuoted(String escapedValue) => escapedValue
    .replaceAll("\\'", "'")
    .replaceAll('\\\$', '\$')
    .replaceAll('\\\\', '\\');
