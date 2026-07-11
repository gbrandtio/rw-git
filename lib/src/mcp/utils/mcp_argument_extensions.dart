/// mcp_argument_extensions.dart
/// Extension methods for safe argument extraction in MCP tools.
library;

extension McpArgumentExtensions on Map<String, dynamic> {
  /// Extracts a required string argument from the map.
  /// Throws an [ArgumentError] with a clear message if the argument is missing or not a string.
  /// This helps LLMs understand exactly which argument they missed or malformed.
  String getStringArgument(String key) {
    if (!containsKey(key) || this[key] == null) {
      throw ArgumentError('Missing required string argument: $key');
    }
    final value = this[key];
    if (value is! String) {
      throw ArgumentError(
        'Argument $key must be a string, but got: ${value.runtimeType}',
      );
    }
    return value;
  }

  /// Extracts an optional string argument from the map.
  /// Returns null if the argument is missing.
  /// Throws an [ArgumentError] with a clear message if the argument is present but not a string.
  String? getOptionalStringArgument(String key) {
    if (!containsKey(key) || this[key] == null) {
      return null;
    }
    final value = this[key];
    if (value is! String) {
      throw ArgumentError(
        'Argument $key must be a string if provided, but got: ${value.runtimeType}',
      );
    }
    return value;
  }

  /// Extracts an optional bool argument from the map.
  /// Returns null if the argument is missing.
  /// Throws an [ArgumentError] with a clear message if the argument is present but not a bool.
  bool? getOptionalBoolArgument(String key) {
    if (!containsKey(key) || this[key] == null) {
      return null;
    }
    final value = this[key];
    if (value is! bool) {
      throw ArgumentError(
        'Argument $key must be a bool if provided, but got: ${value.runtimeType}',
      );
    }
    return value;
  }
}
