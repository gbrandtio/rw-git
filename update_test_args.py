import os
import glob
import re

test_dir = 'test/mcp/tools'
files = glob.glob(os.path.join(test_dir, '*.dart'))

replacements = {
    'localCheckoutDirectory': 'directory',
    'localDirectoryToCloneInto': 'directory',
    'directoryToInit': 'directory',
    'directoryToCheck': 'directory'
}

for filepath in files:
    with open(filepath, 'r') as f:
        content = f.read()

    original_content = content
    for old, new in replacements.items():
        content = content.replace(f"'{old}'", f"'{new}'")
        content = content.replace(f'"{old}"', f'"{new}"')
        content = content.replace(f'({old})', f'({new})')
        content = content.replace(f"contains('{old}')", f"contains('{new}')")
        content = content.replace(f"containsKey('{old}')", f"containsKey('{new}')")
        content = content.replace(f"containsPair('{old}'", f"containsPair('{new}'")
        content = content.replace(f"{old}:", f"{new}:")

    if content != original_content:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Updated {filepath}")

