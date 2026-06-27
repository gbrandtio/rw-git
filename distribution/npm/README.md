# @gbrandtio/rw-git-mcp

**Model Context Protocol (MCP) server for rw-git**

This package provides an embedded Model Context Protocol (MCP) server that allows AI agents and IDEs (like Claude Desktop, Cursor, and Antigravity) to interact directly with your git repositories. It communicates over standard I/O using JSON-RPC 2.0.

`rw-git-mcp` provides a comprehensive suite of tools for AI agents to analyze and manipulate your repository, including core git commands (init, clone, checkout), code quality metrics, dependency drift analysis, compliance auditing, and LLM-assisted code review evaluations.

## Installation

You do not need a Dart or Flutter environment to run this package. It acts as an installer that automatically downloads a pre-compiled, highly-optimized native executable for your operating system and architecture.

### Option 1: Run dynamically via `npx` (Recommended for MCP Clients)
This is the easiest way to integrate the server into tools like Claude Desktop or Cursor:
```bash
npx -y @gbrandtio/rw-git-mcp
```

### Option 2: Install Globally
To install the server globally on your machine:
```bash
npm install -g @gbrandtio/rw-git-mcp
```
After installation, you can run the server simply by typing `rw-git-mcp` in your terminal.

## MCP Client Configuration

### Claude Desktop
Add the following to your `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "rw_git": {
      "command": "npx",
      "args": ["-y", "@gbrandtio/rw-git-mcp"]
    }
  }
}
```

### Cursor
Add the following to your Cursor's `mcp.json` or `.cursor/mcp.json`:
```json
{
  "mcpServers": {
    "rw_git": {
      "command": "npx",
      "args": ["-y", "@gbrandtio/rw-git-mcp"]
    }
  }
}
```

## Features & Tools

The MCP server exposes a massive suite of git and analysis tools to your AI assistant:
- **Repository Operations:** Init, clone, checkout, fetch tags, execute raw commands.
- **Analysis & Metrics:** PR risk analysis, technical debt tracking, commit velocity, "bus factor" estimation, merge conflict prediction.
- **Security & Compliance:** Scan commits for exposed secrets, unsigned commits, and dependency drift.
- **AI Code Review:** Evaluate comment quality and detect LLM-generated documentation.

For more details, visit the [main repository on GitHub](https://github.com/gbrandtio/rw-git).
