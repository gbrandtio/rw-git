import '../../../constants.dart';
import '../mcp_request_context.dart';
import 'mcp_rule.dart';

/// initialize_rule.dart
/// Handles the `initialize` handshake, negotiating the protocol version and
/// advertising server capabilities.
class InitializeRule implements McpRule {
  @override
  bool matches(String? method) => method == 'initialize';

  @override
  Future<void> handle(
    McpRequestContext ctx,
    dynamic id,
    Map<String, dynamic> params,
  ) async {
    // Echo the client's protocol version when we support it; otherwise fall
    // back to our latest implemented revision.
    final requested = params['protocolVersion'] as String?;
    final version =
        supportedMcpProtocolVersions.contains(requested)
            ? requested!
            : mcpProtocolVersion;
    ctx.sendResponse(id, {
      'protocolVersion': version,
      'capabilities': {
        'tools': {'listChanged': false},
        'resources': {'listChanged': false},
        'prompts': {'listChanged': false},
        'logging': {},
      },
      'serverInfo': {'name': 'rw_git_mcp', 'version': rwGitMcpVersion},
    });
  }
}
