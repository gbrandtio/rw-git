# Contributing to rw_git

Thanks for your interest in improving `rw_git`. This guide covers how to
report issues, propose changes, and get a development environment running.

## Reporting issues

Search the [issue tracker](https://github.com/gbrandtio/rw-git/issues) before
opening a new issue. When filing a bug, please include:

- The `rw_git` version (`pubspec.yaml` or `npx @gbrandtio/rw-git-mcp --version`)
- Steps to reproduce, including the Dart/Flutter SDK version
- Expected vs. actual behavior, with relevant git history/repo state if possible

## Proposing features

Open an issue describing the use case before submitting a large pull request,
especially for new MCP tools or algorithms — this avoids duplicated effort and
lets us discuss the approach (and its academic/technical grounding) up front.

## Development setup

Requirements:

- Dart SDK `>=3.3.0 <4.0.0`
- Flutter `>=3.29.0`

```bash
git clone https://github.com/gbrandtio/rw-git.git
cd rw-git
dart pub get
flutter pub get
```

### Running checks locally

These mirror the checks run in CI (`.github/workflows/dart.yml` and
`coverage.yml`):

```bash
# Formatting
dart format --output=none --set-exit-if-changed --line-length=80 .

# Static analysis
dart analyze --fatal-infos

# Tests
flutter test

# Tests with coverage
flutter test -r expanded --coverage
```

## Adding or modifying MCP tools

If your change adds or modifies a tool exposed via the MCP server:

- Follow the existing structure under `lib/src/mcp/tools/<category>/`.
- Add or update the corresponding documentation file under
  `doc/tools/<category>/<tool_name>.md`, following the established pattern:
  **Business Logic** (the question it answers), **Algorithm** (the technical
  approach), and **Academic Foundation** (citations grounding the approach,
  where applicable).
- Update `README.md`'s "Available MCP Tools" section to list the new tool.

## Adding or modifying prompts and skills

Agent workflows have a **single source of truth**: the canonical skill markdown
in `.agents/skills/<name>/SKILL.md`. The matching MCP prompt Dart class in
`lib/src/mcp/prompts/<name>_prompt.dart` is **generated** from it — do not edit
the prompt files by hand.

To add or change a workflow:

1. Edit (or create) `.agents/skills/<name>/SKILL.md`, including its
   `name`/`description` frontmatter.
2. Regenerate the prompt sources and format them:

   ```bash
   dart run tool/sync_prompts.dart
   dart format --line-length=80 lib/src/mcp/prompts
   ```

3. If you added a new workflow, register its prompt in
   `lib/src/mcp/server_registry.dart` and add its name to `promptSkillNames` in
   `tool/prompt_codegen.dart`.
4. List it under "Available Prompts" in `README.md`.

CI runs `dart run tool/sync_prompts.dart --check` (via the prompts sync test),
which fails if a prompt has drifted from its SKILL.md. The npm distribution
copies of the skills are produced automatically by the `prepack` script.

## Pull request workflow

1. Fork the repository and create a branch from `main`.
2. Make your changes, ensuring formatting, analysis, and tests pass locally.
3. Keep pull requests focused — prefer several small PRs over one large one.
4. Write a clear PR description explaining the *why*, not just the *what*.
5. Ensure CI (`dart.yml` and `coverage.yml`) passes before requesting review.

## Code style

Follow standard Dart conventions enforced by `dart format` and `dart analyze`.
Match the patterns already used in the surrounding code (naming, error
handling via the `Result` pattern, file organization) rather than introducing
new conventions.

## License

By contributing, you agree that your contributions will be licensed under the
project's [MIT License](LICENSE).
