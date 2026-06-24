import '../core/git_command.dart';
import '../core/process_runner.dart';

class CheckoutCommand extends GitCommand<bool> {
  final String branchToCheckout;

  CheckoutCommand(super.runner, {required this.branchToCheckout});

  @override
  Future<bool> execute(String directory) async {
    // Ensure branchToCheckout doesn't start with hyphen to prevent flag injection.
    // We cannot use '--' before the branch name because git treats it as a pathspec.
    final sanitizedBranch = branchToCheckout.startsWith('-') ? 'refs/heads/$branchToCheckout' : branchToCheckout;
    final result = await runner.run('git', ['checkout', sanitizedBranch], workingDirectory: directory);
    evaluateProcessResult(result);
    return result.exitCode == 0;
  }
}
