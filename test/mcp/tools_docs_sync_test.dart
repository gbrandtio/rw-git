import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// Guards the Tool Documentation Sync rule in `AGENTS.md`: every registered
/// *analysis* MCP tool must have a matching per-tool document at
/// `doc/tools/<category>/<tool_name>.md`, and no per-tool document may
/// describe a tool that is no longer registered. This keeps the documentation
/// tree from drifting when tools are added, renamed, merged, or removed.
///
/// Plain git-operation tools are exempt: they wrap a single well-known git
/// command with no algorithm or interpretation to document, and their
/// inputSchema is the complete contract.
void main() {
  /// The registered tools that wrap plain git operations (the `core`
  /// category) — deliberately undocumented under doc/tools/.
  const Set<String> plainGitOperationToolNames = {
    'init_repository',
    'is_git_repository',
    'clone_repository',
    'clone_specific_branch',
    'checkout_branch',
    'fetch_tags',
    'get_commits_between',
  };

  group('doc/tools stays in sync with the registered tool surface', () {
    final registeredToolNames = buildDefaultRegistry(
      runner: MockProcessRunner(),
    )
        .getToolListings()
        .map((tool) => tool['name'] as String)
        .toSet()
        .difference(plainGitOperationToolNames);

    final documentedToolNames = Directory('doc/tools')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.md'))
        .map((file) => p.basenameWithoutExtension(file.path))
        .where((name) => name != 'REFERENCES')
        .toSet();

    test('every registered tool has a doc/tools/**/<name>.md document', () {
      final undocumented = registeredToolNames.difference(documentedToolNames);
      expect(
        undocumented,
        isEmpty,
        reason: 'Registered tools without a per-tool document under '
            'doc/tools/: $undocumented. Add the missing document(s) in the '
            'same commit as the registration change (AGENTS.md, Tool '
            'Documentation Sync).',
      );
    });

    test('every doc/tools document matches a registered tool', () {
      final stale = documentedToolNames.difference(registeredToolNames);
      expect(
        stale,
        isEmpty,
        reason: 'doc/tools documents without a registered tool: $stale. '
            'Remove or rename them so the documentation tree cannot '
            'describe tools that no longer exist.',
      );
    });
  });
}
