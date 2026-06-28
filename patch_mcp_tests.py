import os
import glob

test_dir = 'test/mcp/tools'
files = glob.glob(f'{test_dir}/*_test.dart')

patch = """
    test('has correct properties', () {
      expect(tool.name, isNotEmpty);
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema, isNotEmpty);
    });
  });
}
"""

for file in files:
    with open(file, 'r') as f:
        content = f.read()
    
    # Don't patch if already testing name
    if 'tool.name' in content or 'evaluate_comments_tools_test' in file or 'git_tools_test' in file:
        continue
        
    # Find the end of the group
    if content.endswith('  });\n}\n'):
        content = content[:-8] + patch
        with open(file, 'w') as f:
            f.write(content)
        print(f"Patched {file}")

