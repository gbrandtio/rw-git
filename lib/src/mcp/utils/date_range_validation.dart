/// date_range_validation.dart
/// Shared validator for the `since`/`until` date-range arguments accepted by
/// history-scoped MCP tools. Values are forwarded verbatim to git's own
/// `--since=`/`--until=` parser (ISO-8601 and relative-date phrases), so this
/// only guards against malformed or flag-injection-shaped input before it
/// reaches a process argument list; it is a shape check, not a calendar
/// validity check (e.g. "2024-13-45" passes here and is rejected by git).
library;

/// Accepts ISO-8601 dates (`YYYY-MM-DD`), git relative-date phrases
/// (`"N second/minute/hour/day/week/month/year(s) ago"`), and `"yesterday"`.
bool isValidDateInput(String value) {
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return true;
  }
  if (RegExp(
    r'^\d+\s+(second|minute|hour|day|week|month|year)s?\s+ago$',
    caseSensitive: false,
  ).hasMatch(value)) {
    return true;
  }
  return RegExp(r'^yesterday$', caseSensitive: false).hasMatch(value);
}
