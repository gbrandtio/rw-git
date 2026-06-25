import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('CloneSpecificBranchTool', () {
    late ProcessRunner runner;
    late RwGit rwGit;
    late CloneSpecificBranchTool tool;

    setUp(() {
      final mock = ProcessRunner.mock() as MockProcessRunner;
      mock.setMockResult('git', ['clone', '--', 'https://github.com/repo'], 0, 'Cloning...', '');
      mock.setMockResult('git', ['checkout', 'main'], 0, 'Switched to branch main', '');
      runner = mock;
      rwGit = RwGit(runner: runner);
      tool = CloneSpecificBranchTool(rwGit);
    });

    test('execute returns success', () async {
      final result = await tool.execute({
        'localDirectoryToCloneInto': 'test_dir',
        'repository': 'https://github.com/repo',
        'branchToCheckout': 'main'
      });
      final json = jsonDecode(result);
      expect(json['success'], isTrue);
    });
  });
}
