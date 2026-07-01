/// Standard constants used throughout the rw_git library and MCP tools.
const String defaultCommitLimit = '500';
const int defaultTopN = 5;

/// MCP protocol revision implemented by the server. Bump when the wire
/// behaviour is updated to a newer specification.
const String mcpProtocolVersion = '2025-06-18';

/// Older protocol revisions the server still accepts during negotiation, so
/// clients pinned to them continue to work.
const List<String> supportedMcpProtocolVersions = [
  '2025-06-18',
  '2025-03-26',
  '2024-11-05',
];

/// Server version advertised in the MCP `initialize` handshake. Keep in sync
/// with the `version` field in `pubspec.yaml`.
const String rwGitMcpVersion = '3.0.9';

/// JSON-RPC 2.0 error codes used by the MCP server. Per the JSON-RPC
/// specification these are all negative; MCP-specific server errors live in
/// the -32000..-32099 range reserved for implementation-defined errors.
const int jsonRpcMethodNotFound = -32601;
const int jsonRpcInvalidParams = -32602;
const int jsonRpcServerError = -32000;
const int mcpResourceNotFound = -32002;

/// Below this size (bytes), a wrapped MCP tool's full JSON output is
/// returned inline instead of offloaded to disk, avoiding a wasted
/// file-read round trip for small payloads (~2-3K tokens worst case at 8KB).
const int offloadSizeThresholdBytes = 8192;
