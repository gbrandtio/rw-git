import 'dart:math';

import '../../../constants.dart';
import '../mcp_request_context.dart';
import 'mcp_rule.dart';

/// tools_list_rule.dart
/// Returns the tool listing, paginated when [McpRequestContext.toolsPageSize]
/// is configured.
class ToolsListRule implements McpRule {
  @override
  bool matches(String? method) => method == 'tools/list';

  @override
  Future<void> handle(
      McpRequestContext ctx, dynamic id, Map<String, dynamic> params) async {
    final all = ctx.registry.getToolListings();
    final pageSize = ctx.toolsPageSize;

    if (pageSize == null || pageSize <= 0 || pageSize >= all.length) {
      ctx.sendResponse(id, {'tools': all});
      return;
    }

    final cursor = params['cursor'];
    int start = 0;
    if (cursor != null) {
      final decoded = ctx.decodeCursor(cursor);
      if (decoded == null || decoded < 0 || decoded > all.length) {
        ctx.sendError(id, jsonRpcInvalidParams, 'Invalid params: bad cursor');
        return;
      }
      start = decoded;
    }

    final end = min(start + pageSize, all.length);
    final result = <String, dynamic>{'tools': all.sublist(start, end)};
    if (end < all.length) {
      result['nextCursor'] = ctx.encodeCursor(end);
    }
    ctx.sendResponse(id, result);
  }
}
