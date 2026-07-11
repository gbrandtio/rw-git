import 'dart:io';

void removeImport(String file, String importString) {
  final f = File(file);
  final content = f.readAsStringSync();
  f.writeAsStringSync(content.replaceAll(importString, ''));
}

void main() {
  removeImport(
    'lib/src/intelligence/interpretation/models/report_payload.dart',
    "import 'analysis_type.dart';\n",
  );
  removeImport(
    'test/intelligence/interpretation/analysis_hints_catalog_test.dart',
    "import 'package:rw_git/src/intelligence/interpretation.dart';\n",
  );
  removeImport(
    'test/intelligence/interpretation/finding_basis_test.dart',
    "import 'package:rw_git/src/intelligence/interpretation/models/analysis_type.dart';\n",
  );
  removeImport(
    'test/intelligence/interpretation/refactoring_context_classifier_test.dart',
    "import 'package:rw_git/src/intelligence/interpretation/models/analysis_type.dart';\n",
  );
  removeImport(
    'test/mcp/mcp_tool_hints_decorator_test.dart',
    "import 'package:rw_git/src/intelligence/interpretation.dart';\n",
  );
}
