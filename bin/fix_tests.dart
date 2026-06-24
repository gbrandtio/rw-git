import 'dart:io';

void main() {
  final dir = Directory('test');
  if (!dir.existsSync()) return;
  
  for (final file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      var content = file.readAsStringSync();
      content = content.replaceAll('rwGit.gitCommon.', 'rwGit.');
      content = content.replaceAll('rwGit.gitStats.', 'rwGit.');
      file.writeAsStringSync(content);
    }
  }
  print('Done fixing tests.');
}
