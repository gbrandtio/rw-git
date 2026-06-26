# NPM Wrapper for rw-git-mcp

This directory contains the scaffolding for publishing the `rw_git` MCP server as an NPM package (`@gbrandtio/rw-git-mcp`).
Publishing to NPM makes it easy for Javascript/Typescript environments to install and run the MCP server via `npx`.

## How it works
Rather than compiling Dart to JS (which could have performance implications or missing IO features), this NPM package acts as an installer wrapper.
On `postinstall`, a script (`install.js`) will detect the user's OS and architecture, and download the pre-compiled native binary from GitHub Releases (created by the `.github/workflows/release_mcp.yml` action) into the `bin/` directory.

## Setup
1. Update `package.json` with the correct GitHub repository URL.
2. Implement `install.js` to download from `https://github.com/gbrandtio/rw-git/releases/download/v${version}/...`
3. Publish to npm using `npm publish`.
