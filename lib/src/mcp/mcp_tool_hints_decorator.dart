import 'dart:convert';

import '../intelligence/interpretation/models/tool_hints.dart';
import '../intelligence/interpretation/catalogs/analysis_hints_catalog.dart';
import '../intelligence/interpretation/models/analysis_type.dart';
import 'mcp_tool.dart';

/// A decorator that splices research-grounded [ToolHints] into a tool's
/// successful JSON payload under a `hints` key.
///
/// Static per-tool guidance (`toolHintsCatalog`) complements the dynamic,
/// per-finding `basis`/`rationale` classifiers already attach to findings:
/// hints describe how to read the tool's output class in general (research
/// thresholds, known limitations, complementary tools), while `basis`/
/// `rationale` describe what one specific observed value means.
///
/// Only wraps tools mapped to an [AnalysisType] present in [analysisHintsCatalog]
/// `server_registry.dart`); error responses and non-JSON output pass
/// through untouched, since appending interpretation guidance to a result
/// that doesn't exist would be noise at best and misleading at worst.
class McpToolHintsDecorator implements McpTool {
  final McpTool _inner;

  final AnalysisType analysisType;

  McpToolHintsDecorator(this._inner, this.analysisType)
    : assert(
        analysisHintsCatalog.containsKey(analysisType),
        '${_inner.name} (mapped to $analysisType) has no analysisHintsCatalog entry to inject',
      );

  @override
  String get name => _inner.name;

  @override
  String get description => _inner.description;

  @override
  Map<String, dynamic> get inputSchema => _inner.inputSchema;

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final rawOutput = await _inner.execute(arguments);

    dynamic decoded;
    try {
      decoded = jsonDecode(rawOutput);
    } catch (_) {
      return rawOutput;
    }

    if (decoded is! Map || decoded.containsKey('error')) {
      return rawOutput;
    }

    final catalogHints = analysisHintsCatalog[analysisType];
    if (catalogHints == null) {
      return rawOutput;
    }

    final result = Map<String, dynamic>.from(decoded);
    result['hints'] = _merge(result['hints'], catalogHints).toJson();
    return jsonEncode(result);
  }

  /// Unions each hint category from a tool's own (typically conditional)
  /// `hints` payload with the catalog's static entry, so neither source
  /// overwrites the other. Duplicate strings are collapsed.
  ToolHints _merge(dynamic existing, ToolHints catalogHints) {
    List<String> category(String key, List<String> catalogList) {
      final ownList =
          existing is Map && existing[key] is List
              ? [...(existing[key] as List).whereType<String>()]
              : const <String>[];
      return {...ownList, ...catalogList}.toList();
    }

    return ToolHints(
      interpretation: category('interpretation', catalogHints.interpretation),
      caveats: category('caveats', catalogHints.caveats),
      pairWith: category('pair_with', catalogHints.pairWith),
    );
  }
}
