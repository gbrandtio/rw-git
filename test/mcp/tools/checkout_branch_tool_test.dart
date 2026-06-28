// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('CheckoutBranchTool', () {
    late ProcessRunner runner;
    late RwGit rwGit;
    late CheckoutBranchTool tool;

    setUp(() {
      final mock = ProcessRunner.mock() as MockProcessRunner;
      mock.setMockResult(
          'git', ['checkout', 'main'], 0, 'Switched to branch main', '');
      runner = mock;
      rwGit = RwGit(runner: runner);
      tool = CheckoutBranchTool(rwGit);
    });

    test('execute returns success', () async {
      final result = await tool.execute(
          {'localCheckoutDirectory': 'test_dir', 'branchToCheckout': 'main'});
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['success'], isTrue);
    });

    test('has correct properties', () {
      expect(tool.name, isNotEmpty);
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema, isNotEmpty);
    });
  });
}
