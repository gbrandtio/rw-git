import '../../../constants.dart';
import '../../../core/rw_git_logger.dart';
import '../mcp_request_context.dart';
import 'mcp_rule.dart';

/// logging_set_level_rule.dart
/// Handles `logging/setLevel` (ADR-0012): the host selects the minimum
/// severity it wants to receive as `notifications/message`. Unknown level
/// names are rejected as invalid params rather than coerced, so a
/// misconfigured host learns immediately instead of silently getting the
/// wrong verbosity.
class LoggingSetLevelRule implements McpRule {
  @override
  bool matches(String? method) => method == 'logging/setLevel';

  @override
  Future<void> handle(
      McpRequestContext ctx, dynamic id, Map<String, dynamic> params) async {
    final level = McpLogLevel.fromWireName(params['level'] as String?);
    if (level == null) {
      ctx.sendError(
          id,
          jsonRpcInvalidParams,
          'Invalid log level: ${params['level']}. Expected one of: '
          '${McpLogLevel.values.map((l) => l.wireName).join(', ')}.');
      return;
    }
    ctx.minimumLogLevel = level;
    ctx.sendResponse(id, const {});
  }
}
