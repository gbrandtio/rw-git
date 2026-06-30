/// Standard constants used throughout the rw_git library and MCP tools.
const String defaultCommitLimit = '500';
const int defaultTopN = 5;

/// Below this size (bytes), a wrapped MCP tool's full JSON output is
/// returned inline instead of offloaded to disk, avoiding a wasted
/// file-read round trip for small payloads (~2-3K tokens worst case at 8KB).
const int offloadSizeThresholdBytes = 8192;
