/// ----------------------------------------------------------------------------
/// scorecard.dart
/// ----------------------------------------------------------------------------
/// Shared measurement model for the report-quality harness. Records, per tool
/// call, whether the response was returned inline or offloaded to disk and how
/// much context it cost, then derives the metrics that actually predict
/// small-model success: hops-to-report and inline-completeness.
library;

import 'dart:convert';

/// A single measured tool call.
class CallRecord {
  final String tool;

  /// Bytes returned directly into the model's context.
  final int responseBytes;

  /// The tool offloaded its result to disk (a small model must make a second
  /// read to see any content).
  final bool offloaded;

  /// Size of the offloaded file the model would have to read to see the real
  /// content (0 when nothing was offloaded).
  final int offloadedFileBytes;

  /// The response (inline body, or the offload preview after the decorator
  /// envelope change) already carries ranked, band-classified `top_findings`,
  /// so a model can narrate a report without any further interpretation.
  final bool actionable;

  CallRecord({
    required this.tool,
    required this.responseBytes,
    required this.offloaded,
    required this.offloadedFileBytes,
    required this.actionable,
  });

  /// Bytes the model actually consumes worst-case. An actionable offload is
  /// narrated straight from its inline summary/preview, so only a non-actionable
  /// offload adds the cost of reading the file itself.
  int get readBytes => (offloaded && !actionable)
      ? responseBytes + offloadedFileBytes
      : responseBytes;

  /// Classifies a raw tool response string.
  factory CallRecord.fromResponse(String tool, String response) {
    var offloaded = false;
    var actionable = false;
    var offloadedFileBytes = 0;
    try {
      final decoded = jsonDecode(response);
      if (decoded is Map) {
        offloaded = decoded.containsKey('file_size_bytes') &&
            decoded.containsKey('file');
        if (offloaded) {
          offloadedFileBytes =
              (decoded['file_size_bytes'] as num?)?.toInt() ?? 0;
        }
        if (decoded.containsKey('top_findings')) {
          actionable = true;
        }
        final preview = decoded['preview'];
        if (preview is Map && preview.containsKey('top_findings')) {
          actionable = true;
        }
      }
    } catch (_) {
      // Non-JSON response: treat as inline, non-actionable.
    }
    return CallRecord(
      tool: tool,
      responseBytes: utf8.encode(response).length,
      offloaded: offloaded,
      offloadedFileBytes: offloadedFileBytes,
      actionable: actionable,
    );
  }
}

/// The aggregated scorecard for one report flow (baseline or meta-tool).
class Scorecard {
  final String label;
  final List<CallRecord> calls = [];

  Scorecard(this.label);

  void record(CallRecord call) => calls.add(call);

  int get toolCalls => calls.length;

  /// A follow-up read is only forced when a response offloaded AND did not
  /// carry actionable findings inline: an actionable offload (the report
  /// meta-tools, whose preview echoes ranked findings) needs no second read.
  int get followupReads =>
      calls.where((c) => c.offloaded && !c.actionable).length;

  /// Total round-trips a model makes to produce the report.
  int get hopsToReport => toolCalls + followupReads;

  int get totalResponseBytes =>
      calls.fold(0, (sum, c) => sum + c.responseBytes);

  /// Worst-case bytes the model reads: inline responses plus every offloaded
  /// file it must open to see real content.
  int get worstCaseReadBytes => calls.fold(0, (sum, c) => sum + c.readBytes);

  /// Rough token estimate (~4 bytes/token) of everything the model must read.
  int get estimatedTokens => (worstCaseReadBytes / 4).round();

  /// The report can be written from inline payloads alone — no offloaded file
  /// needs reading, and at least one response is actionable.
  bool get inlineComplete =>
      followupReads == 0 && calls.any((c) => c.actionable);

  Map<String, dynamic> toJson() => {
        'label': label,
        'tool_calls': toolCalls,
        'followup_reads': followupReads,
        'hops_to_report': hopsToReport,
        'response_bytes': totalResponseBytes,
        'worst_case_read_bytes': worstCaseReadBytes,
        'estimated_tokens': estimatedTokens,
        'inline_complete': inlineComplete,
      };
}
