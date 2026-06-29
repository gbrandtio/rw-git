import os
import glob
import re

tools_dir = 'lib/src/mcp/tools'
files = glob.glob(os.path.join(tools_dir, '*.dart'))

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
        # Also fix argument extraction strings
        content = content.replace(f"getStringArgument('{old}')", f"getStringArgument('{new}')")
        content = content.replace(f"getOptionalStringArgument('{old}')", f"getOptionalStringArgument('{new}')")

    if content != original_content:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Updated {filepath}")

