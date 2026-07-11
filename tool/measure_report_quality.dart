/// ----------------------------------------------------------------------------
/// measure_report_quality.dart
/// ----------------------------------------------------------------------------
/// Reproduces, in-process and deterministically, the difference in agentic
/// effort between the raw-tool report workflow (what a small model must
/// orchestrate today) and the new one-call report meta-tools. It is the
/// before/after proof for the small-model efficiency overhaul and the CI gate
/// that keeps `top_findings` returning inline.
///
/// Usage:
///   dart run tool/measure_report_quality.dart [--dir <path>] [--limit <n>]
///   dart run tool/measure_report_quality.dart --json
///
/// A `--live` Ollama driver lives in tool/harness/mcp_stdio_client.dart and is
/// intentionally never run in CI.
library;

import 'dart:convert';
import 'dart:io';

import 'package:rw_git/rw_git.dart';

import 'harness/scorecard.dart';

/// The raw tools a technical report orchestrates today (directory + limit
/// only), plus the interpretation-guide fetch the workflow requires.
const _rawTechnicalTools = [
  'analyze_code_quality',
  'analyze_bug_hotspots',
  'analyze_logical_coupling',
  'analyze_code_volatility',
  'analyze_refactoring',
];

Future<void> main(List<String> args) async {
  final dir = _argValue(args, '--dir') ?? Directory.current.path;
  final limit = _argValue(args, '--limit') ?? '200';
  final asJson = args.contains('--json');

  final registry = buildDefaultRegistry();

  Future<String> call(String tool, Map<String, dynamic> toolArguments) async {
    final resolvedTool = registry.getTool(tool);
    if (resolvedTool == null) throw StateError('Tool not registered: $tool');
    return resolvedTool.execute(toolArguments);
  }

  // Baseline: raw tools + the interpretation guide the model must apply itself.
  final baseline = Scorecard('baseline (raw tools + interpretation guide)');
  for (final tool in _rawTechnicalTools) {
    final resp = await call(tool, {'directory': dir, 'limit': limit});
    baseline.record(CallRecord.fromResponse(tool, resp));
  }
  final doc = await call('get_rw_git_documentation', const {});
  baseline.record(CallRecord.fromResponse('get_rw_git_documentation', doc));

  // Meta: a single pre-interpreted call.
  final meta = Scorecard('meta-tool (generate_technical_report)');
  final metaResp = await call('generate_technical_report', {
    'directory': dir,
    'limit': limit,
  });
  meta.record(CallRecord.fromResponse('generate_technical_report', metaResp));

  final toolsListBytes =
      utf8.encode(jsonEncode(registry.getToolListings())).length;

  if (asJson) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'directory': dir,
        'commit_limit': limit,
        'tools_list_bytes': toolsListBytes,
        'baseline': baseline.toJson(),
        'meta': meta.toJson(),
      }),
    );
    return;
  }

  _printReport(dir, limit, toolsListBytes, baseline, meta);
}

void _printReport(
  String dir,
  String limit,
  int toolsListBytes,
  Scorecard baseline,
  Scorecard meta,
) {
  String row(Scorecard s) => '${s.hopsToReport.toString().padLeft(8)}'
      '${s.toolCalls.toString().padLeft(12)}'
      '${s.followupReads.toString().padLeft(12)}'
      '${s.estimatedTokens.toString().padLeft(12)}'
      '${(s.inlineComplete ? 'yes' : 'no').padLeft(10)}';

  stdout.writeln('');
  stdout.writeln('rw-git report-quality scorecard');
  stdout.writeln('  directory : $dir');
  stdout.writeln('  limit     : $limit commits');
  stdout.writeln(
    '  tools/list: $toolsListBytes bytes '
    '(~${(toolsListBytes / 4).round()} tokens)',
  );
  stdout.writeln('');
  stdout.writeln(
    'flow                    hops  toolCalls followupR   ~tokens '
    'inlineOK',
  );
  stdout.writeln('-' * 74);
  stdout.writeln('baseline           ${row(baseline)}');
  stdout.writeln('meta-tool          ${row(meta)}');
  stdout.writeln('-' * 74);

  final hopsSaved = baseline.hopsToReport - meta.hopsToReport;
  final tokenSaved = baseline.estimatedTokens - meta.estimatedTokens;
  stdout.writeln(
    'improvement: -$hopsSaved hops, '
    '~$tokenSaved fewer tokens, '
    'inline-complete: ${baseline.inlineComplete ? 'yes' : 'no'} -> '
    '${meta.inlineComplete ? 'yes' : 'no'}',
  );
  stdout.writeln('');
}

String? _argValue(List<String> args, String flag) {
  final flagIndex = args.indexOf(flag);
  if (flagIndex >= 0 && flagIndex + 1 < args.length) {
    return args[flagIndex + 1];
  }
  return null;
}
