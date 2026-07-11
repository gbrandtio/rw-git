import 'dart:io';

void main() {
  final dir = Directory('lib/src/intelligence/interpretation/classifiers');
  for (final file in dir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    var content = file.readAsStringSync();
    if (content.startsWith("import '../models/analysis_type.dart';\n")) {
      content = content.replaceFirst(
        "import '../models/analysis_type.dart';\n",
        "",
      );
      content = content.replaceFirst(
        "library;\n",
        "library;\n\nimport '../models/analysis_type.dart';\n",
      );
      file.writeAsStringSync(content);
      print('Fixed ${file.path}');
    }
  }
}
