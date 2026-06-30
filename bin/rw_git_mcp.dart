import 'dart:io';

import 'package:rw_git/rw_git.dart';

/// ----------------------------------------------------------------------------
/// rw_git_mcp.dart
/// ----------------------------------------------------------------------------
/// Model Context Protocol (MCP) server for rw_git over standard I/O JSON-RPC.
/// Allows AI agents to interact with git repositories and analyze code quality.
///
/// The concrete set of tools and prompts is assembled by [buildDefaultRegistry]
/// (see `lib/src/mcp/server_registry.dart`) so production and tests share one
/// source of truth.

void main() async {
  final registry = buildDefaultRegistry();
  // Optionally page `tools/list` for clients with very small context windows.
  final pageSize =
      int.tryParse(Platform.environment['RW_GIT_TOOLS_PAGE_SIZE'] ?? '');
  final server = McpServer(registry: registry, toolsPageSize: pageSize);
  server.start();
}
