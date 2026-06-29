import 'dart:convert';
import '../../../rw_git.dart';
import '../utils/mcp_argument_extensions.dart';

/// checkout_branch_tool.dart
/// Checks out a specific branch via MCP.

class CheckoutBranchTool implements McpTool {
  final RwGit rwGit;

  CheckoutBranchTool(this.rwGit);

  @override
  String get name => 'checkout_branch';

  @override
  String get description =>
      'Checks out the specified branch within the local checkout directory. '
      'For a complete guide on how to use the rw_git MCP tools, invoke the get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'localCheckoutDirectory': {
            'type': 'string',
            'description': 'The local directory containing the git repository.'
          },
          'branchToCheckout': {
            'type': 'string',
            'description': 'The name of the branch to checkout.'
          }
        },
        'required': ['localCheckoutDirectory', 'branchToCheckout']
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final localDir = arguments.getStringArgument('localCheckoutDirectory');
    final branch = arguments.getStringArgument('branchToCheckout');
    final result = (await rwGit.checkout(localDir, branch)).getOrThrow();
    return jsonEncode({'success': result});
  }
}
