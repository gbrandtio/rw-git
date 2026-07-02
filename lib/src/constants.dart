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
const String rwGitMcpVersion = '3.0.10';

/// JSON-RPC 2.0 error codes used by the MCP server. Per the JSON-RPC
/// specification these are all negative; MCP-specific server errors live in
/// the -32000..-32099 range reserved for implementation-defined errors.
const int jsonRpcMethodNotFound = -32601;
const int jsonRpcInvalidParams = -32602;
const int jsonRpcServerError = -32000;
const int mcpResourceNotFound = -32002;

/// Minutes in a day, used to convert commit-timestamp differences into
/// fractional days for the SZZ bug-lifetime metrics.
const int minutesPerDay = 24 * 60;

/// RA-SZZ moved-line detection: a deleted line is only treated as "moved by a
/// refactoring" (and excluded from blame) when its whitespace-normalized
/// content is at least this long. Shorter lines (`}`, `return;`, `else {`)
/// are language boilerplate that recurs naturally, so a match on them says
/// nothing about code movement.
const int raSzzMovedLineMinimumLength = 8;

/// Below this size (bytes), a wrapped MCP tool's full JSON output is
/// returned inline instead of offloaded to disk, avoiding a wasted
/// file-read round trip for small payloads (~2-3K tokens worst case at 8KB).
/// This is the default; individual tools can override it via
/// [perToolOffloadThresholdBytes] (ADR-0011).
const int offloadSizeThresholdBytes = 8192;

/// Offload threshold for the one-call report meta-tools. Their offload
/// summary already carries the classified findings inline (ADR-0005), so an
/// inline full report duplicates that content without adding signal; a lower
/// threshold keeps even mid-sized reports out of the context window.
const int reportToolOffloadThresholdBytes = 4096;

/// Offload threshold for compact history tools whose output (commit lists,
/// aggregate stats) is typically consumed whole by the model; a higher
/// threshold avoids a pointless write-then-read round trip for payloads the
/// model would immediately fetch in full anyway.
const int compactHistoryToolOffloadThresholdBytes = 16384;

/// Per-tool overrides for [offloadSizeThresholdBytes], keyed by MCP tool
/// name (ADR-0011). Tools absent from this map use the global default.
const Map<String, int> perToolOffloadThresholdBytes = {
  'generate_repository_audit': reportToolOffloadThresholdBytes,
  'generate_technical_report': reportToolOffloadThresholdBytes,
  'generate_security_report': reportToolOffloadThresholdBytes,
  'generate_pm_report': reportToolOffloadThresholdBytes,
  'generate_code_review_report': reportToolOffloadThresholdBytes,
  'get_commits_between': compactHistoryToolOffloadThresholdBytes,
  'get_stats': compactHistoryToolOffloadThresholdBytes,
};
