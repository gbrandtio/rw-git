import 'dart:developer' as developer;

/// ----------------------------------------------------------------------------
/// rw_git_logger.dart
/// ----------------------------------------------------------------------------
/// Structured logging facade for the library (ADR-0012).
///
/// Library code logs through [RwGitLogger] instead of calling
/// `developer.log` directly. Every message keeps flowing to
/// `dart:developer` (so DevTools/IDE observability is unchanged), and an
/// optional [RwGitLogListener] lets the MCP server forward the same events
/// to the connected host as `notifications/message`, filtered by the level
/// the host selected via `logging/setLevel`.

/// MCP log severities, in ascending order of severity as defined by the MCP
/// specification (which adopts the RFC 5424 syslog levels). The enum order is
/// the filtering order: a message passes when its index is >= the minimum
/// level's index.
enum McpLogLevel {
  debug,
  info,
  notice,
  warning,
  error,
  critical,
  alert,
  emergency;

  /// The level name used on the MCP wire (`logging/setLevel` params and
  /// `notifications/message` payloads).
  String get wireName => name;

  /// Resolves a wire-format level name; returns null for unknown names so
  /// the caller can reject the request as invalid params instead of
  /// guessing a severity.
  static McpLogLevel? fromWireName(String? raw) {
    for (final level in McpLogLevel.values) {
      if (level.name == raw) return level;
    }
    return null;
  }

  /// The equivalent `dart:developer` numeric level (package:logging scale),
  /// so IDE log views keep ranking severities correctly.
  int get developerLogLevel => switch (this) {
        McpLogLevel.debug => 500,
        McpLogLevel.info => 800,
        McpLogLevel.notice => 850,
        McpLogLevel.warning => 900,
        McpLogLevel.error => 1000,
        McpLogLevel.critical ||
        McpLogLevel.alert ||
        McpLogLevel.emergency =>
          1200,
      };
}

/// Receives every structured log event, regardless of level; the listener
/// decides what to forward (the MCP server applies the host-selected
/// minimum level there).
typedef RwGitLogListener = void Function(
    McpLogLevel level, String message, Object? error);

/// Process-wide logging facade. A singleton (rather than injection into
/// every `GitCommand`) keeps the logging concern out of dozens of
/// constructor signatures; the swappable [listener] preserves testability.
class RwGitLogger {
  RwGitLogger._();

  static final RwGitLogger instance = RwGitLogger._();

  /// Name under which events appear in `dart:developer` logs and in the
  /// MCP `notifications/message` `logger` field.
  static const String loggerName = 'rw_git';

  /// Optional structured sink, e.g. the MCP server's notification sender.
  RwGitLogListener? listener;

  void log(McpLogLevel level, String message, {Object? error}) {
    developer.log(
      message,
      name: loggerName,
      level: level.developerLogLevel,
      error: error,
    );
    listener?.call(level, message, error);
  }

  void debug(String message) => log(McpLogLevel.debug, message);

  void info(String message) => log(McpLogLevel.info, message);

  void warning(String message, {Object? error}) =>
      log(McpLogLevel.warning, message, error: error);

  void error(String message, {Object? error}) =>
      log(McpLogLevel.error, message, error: error);
}
