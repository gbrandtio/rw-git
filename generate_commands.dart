import 'dart:io';

void main() {
  final commands = {
    'branch': {
      'type': 'List<String>',
      'return':
          "result.stdout?.toString().split('\\n').where((l) => l.trim().isNotEmpty).toList() ?? []",
      'args': "['branch']"
    },
    'status': {
      'type': 'String',
      'return': "result.stdout?.toString() ?? ''",
      'args': "['status', '--short']"
    },
    'pull': {
      'type': 'bool',
      'return': "result.exitCode == 0",
      'args': "['pull']"
    },
    'push': {
      'type': 'bool',
      'return': "result.exitCode == 0",
      'args': "['push']"
    },
    'diff': {
      'type': 'String',
      'return': "result.stdout?.toString() ?? ''",
      'args': "['diff']"
    },
    'merge': {
      'type': 'bool',
      'return': "result.exitCode == 0",
      'args': "['merge']"
    },
    'stash': {
      'type': 'bool',
      'return': "result.exitCode == 0",
      'args': "['stash']"
    },
    'blame': {
      'type': 'String',
      'return': "result.stdout?.toString() ?? ''",
      'args': "['blame']"
    },
    'show': {
      'type': 'String',
      'return': "result.stdout?.toString() ?? ''",
      'args': "['show']"
    },
  };

  for (final entry in commands.entries) {
    final name = entry.key;
    final type = entry.value['type']!;
    final returnStr = entry.value['return']!;
    final argsStr = entry.value['args']!;
    final className = '${name[0].toUpperCase()}${name.substring(1)}Command';

    final content = '''
import '../core/git_command.dart';
import '../core/process_runner.dart';

class $className extends GitCommand<$type> {
  $className(super.runner);

  @override
  Future<$type> run(String directory, {bool streamOutput = false}) async {
    final result = await runner.run('git', $argsStr,
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    return $returnStr;
  }
}
''';

    File('lib/src/commands/${name}_command.dart').writeAsStringSync(content);
  }
  print('Generated command classes.');
}
