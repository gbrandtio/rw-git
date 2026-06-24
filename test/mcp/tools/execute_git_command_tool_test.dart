import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('ExecuteGitCommandTool', () {
    late ProcessRunner runner;
    late RwGit rwGit;
    late ExecuteGitCommandTool tool;

    setUp(() {
      final mock = ProcessRunner.mock() as MockProcessRunner;
      mock.setMockResult('git', ['status'], 0, 'Mock stdout', '');
      runner = mock;
      rwGit = RwGit(runner: runner);
      tool = ExecuteGitCommandTool(rwGit);
    });

    test('has correct name and description', () {
      expect(tool.name, 'execute_git_command');
      expect(tool.description, contains('Execute an arbitrary git command'));
    });

    test('has valid inputSchema', () {
      final schema = tool.inputSchema;
      expect(schema['type'], 'object');
      expect((schema['required'] as List).contains('directory'), isTrue);
      expect((schema['required'] as List).contains('args'), isTrue);
    });

    test('execute passes arguments correctly and returns stdout', () async {
      final result = await tool.execute({
        'directory': '/test/dir',
        'args': ['status']
      });

      expect(result, 'Mock stdout');
    });

    test('execute throws GitCommandException on error', () async {
      final mock = ProcessRunner.mock() as MockProcessRunner;
      mock.setMockResult('git', ['log'], 128, '', 'Mock stderr');
      final errorRwGit = RwGit(runner: mock);
      tool = ExecuteGitCommandTool(errorRwGit);

      expect(
        () => tool.execute({
          'directory': '/test/dir',
          'args': ['log'],
        }),
        throwsA(isA<RwGitException>()),
      );
    });
  });
}
