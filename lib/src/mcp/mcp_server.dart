import 'dart:convert';
import 'dart:io';

import '../../rw_git.dart';
import '../constants.dart';
import 'mcp_server/mcp_request_context.dart';
import 'mcp_server/rules/initialize_rule.dart';
import 'mcp_server/rules/logging_set_level_rule.dart';
import 'mcp_server/rules/mcp_rule.dart';
import 'mcp_server/rules/notifications_initialized_rule.dart';
import 'mcp_server/rules/ping_rule.dart';
import 'mcp_server/rules/prompts_get_rule.dart';
import 'mcp_server/rules/prompts_list_rule.dart';
import 'mcp_server/rules/resources_list_rule.dart';
import 'mcp_server/rules/resources_read_rule.dart';
import 'mcp_server/rules/resources_templates_list_rule.dart';
import 'mcp_server/rules/tools_call_rule.dart';
import 'mcp_server/rules/tools_list_rule.dart';

/// mcp_server.dart
/// Handles the Model Context Protocol (MCP) JSON-RPC communication loop over standard I/O.
class McpServer {
  final McpRegistry registry;
  final Stream<List<int>> inputStream;
  final IOSink outputSink;
  final IOSink errorSink;

  /// Optional page size for `tools/list`. When null, the full tool list is
  /// returned in a single response (backwards compatible). When set, the
  /// server paginates with an opaque `nextCursor`, letting tiny-context
  /// clients fetch the tool surface in chunks.
  final int? toolsPageSize;

  late final McpRequestContext _context;
  late final List<McpRule> _rules;

  McpServer({
    required this.registry,
    Stream<List<int>>? inputStream,
    IOSink? outputSink,
    IOSink? errorSink,
    this.toolsPageSize,
  }) : inputStream = inputStream ?? stdin,
       outputSink = outputSink ?? stdout,
       errorSink = errorSink ?? stderr {
    _context = McpRequestContext(
      registry: registry,
      outputSink: this.outputSink,
      toolsPageSize: toolsPageSize,
    );
    // Forward the library's structured log events to the connected host as
    // notifications/message, filtered by the host-selected minimum level
    // (ADR-0012).
    RwGitLogger.instance.listener =
        (level, message, error) =>
            _context.sendLogNotification(level, message, error: error);
    // Order mirrors the original if-else dispatch chain.
    _rules = [
      InitializeRule(),
      NotificationsInitializedRule(),
      PingRule(),
      LoggingSetLevelRule(),
      ResourcesListRule(),
      ResourcesReadRule(),
      ResourcesTemplatesListRule(),
      PromptsListRule(),
      PromptsGetRule(),
      ToolsListRule(),
      ToolsCallRule(),
    ];
  }

  /// Starts listening to the input stream for JSON-RPC messages.
  void start() {
    inputStream.transform(utf8.decoder).transform(const LineSplitter()).listen((
      line,
    ) async {
      try {
        final request = jsonDecode(line);
        if (request is! Map<String, dynamic>) return;

        await _handleRequest(request);
      } catch (e) {
        errorSink.writeln('Error processing message: $e');
      }
    });
  }

  Future<void> _handleRequest(Map<String, dynamic> request) async {
    final id = request['id'];
    final method = request['method'] as String?;
    final params =
        (request['params'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    for (final rule in _rules) {
      if (rule.matches(method)) {
        await rule.handle(_context, id, params);
        return;
      }
    }

    if (!request.containsKey('id')) {
      // JSON-RPC notifications must never receive a reply, even an error
      // one: replying with `id: null` produces a message that is neither a
      // valid request nor a valid response, and MCP clients reject it.
      errorSink.writeln('Ignoring unhandled notification: $method');
      return;
    }
    _context.sendError(id, jsonRpcMethodNotFound, 'Method not found: $method');
  }
}
