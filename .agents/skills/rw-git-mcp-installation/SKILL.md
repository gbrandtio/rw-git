---
name: rw-git-mcp-installation
description: "Guides the agent through installing and configuring the rw_git MCP server on the user's system."
---

# `rw-git` MCP Server Installation Guide

This skill instructs you on how to set up the `rw_git` Model Context Protocol (MCP) server for a user so that their AI agents can access robust repository analysis tools.

Trigger this skill whenever a user asks to "install rw_git MCP", "connect the git MCP server", or "set up the repo analysis AI tools".

## 1. Determine the Target Environment

First, identify which AI client the user wants to connect the MCP server to. If they haven't specified, ask them. Common clients include:
- **Claude Desktop**
- **Cursor IDE**
- **Antigravity (AGY)**

Also, ensure the user has Node.js installed, as `npx` is the recommended and easiest way to run the server. If they don't have Node.js, ask if they have Homebrew or the Dart SDK.

## 2. Locate the Configuration File

Based on their client and OS, locate the correct MCP configuration file:

### Claude Desktop
- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

### Cursor IDE
- Check if `.cursor/mcp.json` exists in the current workspace. If so, update it.
- Otherwise, guide the user to add it via the Cursor UI (Settings -> Features -> MCP), as Cursor's global config files are heavily nested.

### Antigravity (AGY)
- Configuration is usually located at `~/.gemini/config/mcp.json` or within a plugin configuration.

## 3. Inject the Configuration

Once the target file is located, use your file editing tools to safely merge the following `rw_git` configuration block into the `mcpServers` object.

```json
{
  "mcpServers": {
    "rw_git": {
      "command": "npx",
      "args": [
        "-y",
        "@rw-core/rw-git-mcp"
      ]
    }
  }
}
```

> [!WARNING]
> Do NOT overwrite existing MCP servers in the configuration file. Parse the JSON carefully and only insert or update the `rw_git` key inside `mcpServers`.

### Alternative Commands
If the user prefers not to use `npx`, adjust the `command` and `args` accordingly:
- **Homebrew:** `command: "rw-git-mcp", args: []`
- **Dart global activate:** `command: "rw_git_mcp", args: []`

## 4. Verification

After updating the configuration file, instruct the user to restart their AI client (e.g., fully quit and reopen Claude Desktop or reload Cursor). 

To proactively verify that the server works on their machine, you can run a quick test via standard input:

```bash
echo '{"jsonrpc": "2.0", "id": 1, "method": "prompts/list"}' | npx -y @rw-core/rw-git-mcp
```
If the command outputs a valid JSON-RPC response containing a prompt named `rw-git-mcp-reporting`, the installation is successful!

## 5. Important Agent Context

When using `rw_git` tools, especially code quality tools, be aware that history-scanning tools apply a **default commit analysis limit** (`defaultCommitLimit` in `lib/src/constants.dart` of the rw-git repository — currently 500 commits). If the analysis requires more history, you must explicitly pass a larger `limit` argument to the tools; each tool's `limit` parameter description states the current default.
