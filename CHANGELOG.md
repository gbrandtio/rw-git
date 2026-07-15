# 3.4.6
- **PERFORMANCE (SZZ Algorithm):** Fully refactored `SzzAlgorithm` execution model to use `package:pool` for global concurrency management. Eliminated head-of-line blocking by resolving commit lines into flat, concurrent `git blame` tasks governed by a bounded resource pool (`Pool(20)`), maximizing CPU utilization without exhausting OS fork limits or crashing CI runners.

# 3.4.5
- **FIX (SZZ Algorithm):** Fixing SZZ algorithm to use only the `targetFiles` list and calculate bug-hotspots only for them, in case the `targetFiles` has been provided. This is helpful for Github Actions that want to check only the files that the commit is touching (and nothing else). Previously, it would blame the lines that the commit is touching, go to previous commits, and blame all the files of the previous commit.

# 3.4.4
- **BREAKING (Metrics):** NPath complexity now folds guard-clause branches (those ending in `return`, `throw`, `break`, `continue`, `raise`) additively instead of multiplicatively, modeling the reality that terminated branches do not combine with downstream paths. This produces lower, more accurate scores for well-structured code and diverges from PMD's standard computation. See ADR-0019.

# 3.4.3
- **FIX (NPath Calculation):** Fixing NPath calculation bugs.

# 3.4.2
- **Improvement:** Introduce optional revisionRange throughout history analysis: CodeVolatilityAlgorithm.execute now accepts revisionRange and targetFiles and forwards them to git.

# 3.4.1
- **Improvement:** Add support for filtering analysis by target files and revision ranges.
- **Improvement:** SzzAlgorithm add targetFiles parameter to restrict fix-commit search to specific files via git pathspecs
- **Improvement:** MegaCommitsHeuristic add revisionRange parameter to restrict analysis to a specific revision range
- **Improvement:** SuspiciousCommitsHeuristic add revisionRange parameter to both findSuspiciousCommits and extractChangedComments methods

# 3.4.0
- **FEAT (Metrics):** Added a shared `NestingResolver` that computes control-flow nesting depth per token in a single pass, with per-language strategies declared via a new `BlockStructure` on `LanguageProfile`: brace-delimited (control/lambda/neutral frame classification), indentation-based (indent/dedent synthesis from newline indent stamps, with bracket-continuation handling), and keyword-terminated (`end`/`fi`/`done`, with statement-position filtering of Ruby/Lua modifier forms). Exported via `lexical_metrics.dart`. See ADR-0018.
- **BREAKING (Metrics):** Rewrote `CognitiveComplexityAlgorithm` against the SonarSource specification on top of resolved depths. Function bodies, argument lists, and literals no longer count as nesting; `else`/`elif` score a flat +1 with `else if` collapsed to one increment; `switch` counts once and `case` arms do not; ternary `?` counts (disambiguated from nullable-type markers) and `??` scores +1; C preprocessor `#if` is ignored. Python nesting is now visible (previously the metric degenerated to cyclomatic counting for indentation languages). Scores are not comparable with pre-3.4.0 values.
- **BREAKING (Metrics):** `IndentationComplexityAlgorithm` now reports genuine control-flow nesting from the shared resolver instead of raw brace counting, and returns consistent keys (`max_nesting_depth`, `average_nesting_depth`) for empty input.
- **Improvement (Lexer):** `FsmLexer` stamps each newline token with the indentation width of the line it opens (`Token.indentWidth`; tabs expand to the next multiple of 8, blank/comment-only lines stamp -1), preserving the structural whitespace signal for indentation-based languages without emitting whitespace tokens.
- **FIX (Profiles):** Removed dead `'?'`/`'??'` entries from `controlFlowKeywords` (they lex as operators and could never match identifier lookups); added `lambdaIntroducers` (`=>`, `->`) and keyword-end block vocabularies to the default profiles.
- **BREAKING (Metrics):** Rewrote `NpathComplexityAlgorithm` to utilize `NestingResolver` to accurately compute acyclic paths across depths using a stack-based model, correctly differentiating between multiplicative paths (sequential decisions) and additive paths (nested decisions).
- **FIX (Metrics):** `AbcScoreAlgorithm` now correctly classifies function and method calls as Branches (B) via token lookahead, and control-flow/logical operators as Conditions (C), perfectly aligning with the Fitzpatrick (1997) ABC metric specification.
- **DOCS (ADRs):** Updated ADR-0018 to confirm Cyclomatic Complexity deliberately excludes depth factors, and removed a forward-looking promise regarding future algorithm adoptions.

# 3.3.2
- **Improvement:** Move FsmLexer from hardcoded C-family comment/string masking to injected LexicalProfile objects, enabling language-specific accuracy without code forks. Simultaneously optimize the hot tokenization path to operate exclusively on code units (integers) instead of String indexing, eliminating per-character allocations.
- **Improvement:** Add LexicalProfile definitions for 10 languages (C, Python, Go, Ruby, Lua, Shell, XML, etc.), each with correct line-comment prefixes, block delimiters, and string syntax. Extend DefaultProfiles with new language support and file extensions, refactoring extension lookup to iterate through all profiles.
- **Improvement:** Improve number literal scanning to handle radix prefixes (0x, 0b, 0o), digit separators, decimals, and scientific notation as atomic tokens. Replace substring-based character tests with precomputed lookup tables.

# 3.3.1
- **Feat (GitHub):** Moved from @gbrandtio personal github, to @rw-core organisation in github.
- **Feat (Distribution):** Updated the npm package to reflect the new organisation name, along with pubspec assets and git jobs.
- **CHORE (Distribution):** Removed flutter dependency and pumped dart version to >=3.10.0 <4.0.0

# 3.3.0
- **FEAT (Library):** Exposed the pure lexical metrics algorithms (`FsmLexer`, `CyclomaticComplexityAlgorithm`, `HalsteadComplexityAlgorithm`, etc.) via `lexical_metrics.dart` so 3rd party packages can build custom static analysis pipelines.
- **FEAT (Library):** Added a new `LexicalMetricsRunner` facade that allows 3rd party consumers to easily compute the full lexical complexity suite (McCabe, Maintainability Index, ABC Score, NPath, Cognitive, Halstead) synchronously for any given file and source string, without the overhead of Isolate spawning or git-churn sampling logic.

# 3.2.5
- **Improvement (Quality):** Removed duplication of context for hints/prompts/skills. Removed capped limits for hints in order to enhance quality of output.

# 3.2.4
- **PERF (Quality):** Drastically improved the execution time of intelligence tools across large Git repositories (e.g. >10,000 commits) by refactoring `ChurnHeuristic` to use `git log --name-only` instead of the heavy `git log -p`. This eliminates huge amounts of text-parsing overhead.
- **BREAKING (Core/MCP):** Removed `classChurn` and `blockChurn` from `ChurnMetricsDto` and `ChurnMetricsWithAuthorsDto` across the codebase, as the granular tracking of functions and classes was removed to optimize analysis at the file level. The `analyze_code_quality` tool now exclusively reports `high_churn_files`.
- **PERF (Quality):** Introduced chunked concurrency in `SzzAlgorithm.execute()`. The algorithm now groups fix-commits into batches (batch size of 10) to execute `_traceIntroducingCommits` in parallel, significantly improving performance for deep histories by preventing excessive OS command spawning.
- **Improvement:** Improving skills, prompts, hints in order to provide more details and guide the LLM better.

# 3.2.3
- **FIX (Core):** Fixed an issue where `git diff` and `git log` commands would crash on binary or unreadable files (e.g., `.doc` files) due to failing `textconv` or external diff drivers. The `StandardProcessRunner` now universally injects `--no-ext-diff` and `--no-textconv` into diff-generating Git commands to ensure Git gracefully reports binary differences and continues processing all files in the repository without terminating the command sequence.

# 3.2.2
- **FIX (documentation):** Fixing README.md documentation and branding in order to render correctly in pub.dev.

# 3.2.1
- **BREAKING (MCP):** `find_bugs_by_developer` is removed and merged into
  **`analyze_bug_hotspots`** via a new optional `author` parameter (plus
  `positiveRegex`/`negativeRegex`, previously only available on the removed
  tool). Both tools ran the identical RA-SZZ pipeline (`SzzAlgorithm`) and
  only differed in whether the resulting matches were aggregated or
  filtered by author; `analyze_bug_hotspots` now does both in one call,
  returning an additional `developer_bug_analysis` section when `author` is
  supplied. Clients calling `find_bugs_by_developer` must switch to
  `analyze_bug_hotspots` with the `author` parameter. `BugHotspotsHeuristic`
  is refactored into a pure `aggregate(List<SzzMatch>)` function (no longer
  owns the `SzzAlgorithm` call), so the shared SZZ pass now runs once per
  `analyze_bug_hotspots` invocation instead of twice.
- **DOCS (Tools):** Merged `doc/tools/history/find_bugs_by_developer.md`
  into `doc/tools/history/analyze_bug_hotspots.md`, folding in the
  developer-filtering phase and the Zimmermann et al. (2007) *Cross-Project
  Defect Prediction* citation. Updated the `find_bugs_by_developer.md`
  cross-references in `doc/tools/history/generate_changelog.md` to point at
  `analyze_bug_hotspots.md`. `README.md` no longer lists
  `find_bugs_by_developer` and documents the `author` filter under
  `analyze_bug_hotspots`.
- **Fixed:** `get_contributions_by_author` now actually implements the
    `git shortlog -sn --no-merges [--since=<date>] [--until=<date>]` behavior
    its documentation already described. `ShortlogCommand` previously ran a
    bare `git shortlog HEAD -s` and silently ignored its own `extraArgs`
    parameter — sort-by-count (`-n`), merge-commit exclusion (`--no-merges`),
    and date-range filtering were all doc-only. This was a doc/implementation
    gap fix (not a new feature): `since`/`until` are validated with the same
    shared `isValidDateInput` and forwarded through `RwGit.contributionsByAuthor`
    exactly like the report tools.
- **Added:** The five report meta-tools (`generate_technical_report`,
  `generate_pm_report`, `generate_code_review_report`,
  `generate_security_report`, `generate_repository_audit`) now accept
  optional `since`/`until` parameters for date-bounded analysis (e.g.
  "report for 2024" via `since: "2024-01-01", until: "2025-01-01"`, or "the
  previous 6 months" via `since: "6 months ago"`). Values are validated
  (shared `isValidDateInput` in `lib/src/mcp/utils/date_range_validation.dart`)
  and forwarded verbatim to git's own `--since=`/`--until=` date parsing — no
  natural-language date math is implemented in Dart. The effective window is
  echoed back in the report's `metadata` when supplied. Every underlying
  analyzer the report orchestrator composes (churn, bus factor, SZZ bug
  hotspots, logical coupling, code volatility, refactoring detection,
  architecture drift, secrets scanning, compliance scanning, mega/suspicious
  commit detection) now accepts the same `since`/`until` parameters.
- **Changed (MCP offload contract):** The offload `preview` built by
  `McpToolFileOffloadDecorator` no longer strips the per-finding `rationale`
  field or caps the `hints` list at 3 entries — both are now carried in
  full, matching the uncapped full-report contract. The now-unused
  `previewStrippedFindingKeys`/`previewHintsLimit` constants are removed
  from `lib/src/constants.dart`.

# 3.2.0
- **BREAKING (MCP surface, prompts):** The five reporting prompts/skills are
  consolidated into the single `rw-git-mcp-reporting` prompt and agent skill.
  `rw-git-mcp-technical-reporting`, `rw-git-mcp-pm-reporting`,
  `rw-git-mcp-security-reporting`, and `rw-git-mcp-code-review-reporting`
  no longer appear in `prompts/list`; the consolidated workflow carries a
  goal-to-tool selection table and one generated `<deep_dive>` raw-tool list
  per report type (sourced from `reportToolSources`, ADR-0015). The five
  templates were one workflow parameterized on persona and tool name;
  clients pinned to a removed prompt name must switch to
  `rw-git-mcp-reporting`. The npm package's bundled skills follow
  automatically via its `prepack` copy of `.agents/skills`.
- **BREAKING (MCP surface, tools):** `analyze_pr_diff` is removed — its
  composite score duplicated signals the report meta-tools now classify
  individually (churn, hotspot history, ownership, secrets), and its
  remaining references had already drifted. All stale
  `predict_merge_conflicts` leftovers (interpretation-guide compound rule,
  tool-description mentions) are purged with it.
- **FEAT (Reports, full lexical suite):** The bounded top-churn sampler
  (ADR-0014) now computes the complete research-backed complexity suite —
  ABC score (Fitzpatrick 1997), NPath (Nejmeh 1988), cognitive complexity
  (Campbell 2018), and the Halstead delivered-bugs estimate (Halstead
  1977) — alongside McCabe and the maintainability index.
  `lexicalComplexity` findings carry the worst-banding metric with the full
  suite in evidence; bands are named constants per ADR-0010.
- **FEAT (Reports, new signal sources):** Three analyses that previously fed
  no report are now classified into the technical report and audit (clean
  code additionally into the code review report): architecture drift over
  layers inferred from churned file paths (God Component / Hub-Like
  Dependency / Scattered Functionality plus coupling ratio/density bands —
  Garcia et al. 2009; Perry & Wolf 1992), clean-code heuristics on the same
  bounded sample (Martin 2008; Fowler 1999; Koschke 2007, including a new
  duplicate-lines issue in `analyze_clean_code` itself), and Tarjan
  import-cycle detection on Dart repositories (Tarjan 1972; Lakhotia 1993).
  The drift and clean-code analyses were extracted from their MCP tools
  into library-first algorithms (`ArchitectureDriftAlgorithm`,
  `CleanCodeAnalyzer`) per ADR-0005; the tools are now thin wrappers with
  unchanged wire formats.
- **FEAT (Reports, ranked refactoring targets):** Report payloads with both
  churn and complexity signals (technical, code review, audit) gain an
  additive `refactoring_targets` field: files ranked by churn percentile x
  complexity percentile (genuine McCabe where sampled, else the
  repo-relative proxy, each percentiled within its own population) —
  Tornhill's hotspot prioritization (Tornhill 2015; Ostrand, Weyuker & Bell
  2004), capped at 5 with a 0.25 minimum product.
- **FIX (Reports, source-only complexity scope):** Complexity
  interpretation is now scoped to source-code files via the new
  `SourceFileFilter` (a denylist of definitely-not-code files — prose,
  config, lockfiles, media; unknown extensions still pass, so no
  unprofiled language is silently dropped). Hotspot analysis is defined
  over source files (Tornhill 2015), but the control-flow keyword proxy
  matches English prose ("if", "for", "while"), so a constantly-churning
  `CHANGELOG.md` could top `refactoring_targets` and skew the
  repo-median complexity band. The filter applies in the interpretation
  layer only — `RefactoringTargetRanker` (all percentile populations),
  the complexity classifier's repo median, and the bounded top-churn
  sample (ADR-0014), which no longer spends slots lexing prose; raw
  tools such as `analyze_code_quality` still report `file_complexity`
  for every file unfiltered.
- **FEAT (Reports, new compound rules):** Three research-backed correlator
  rules join the existing five: author-level knowledge-loss risk (one
  author solely owning 2+ bug-hotspot files → Critical; Avelino 2016;
  Fritz 2010; Mockus & Herbsleb 2002), minor-contributors x hotspot (High;
  Bird et al. 2011 x Śliwerski 2005), and burnout x bug-introduction
  co-occurrence (High; Claes 2018; Eyolfson, Tan & Lam 2011 — deliberately
  a repo-level co-occurrence, since SZZ dates are UTC-normalized while the
  burnout window is author wall-clock). The ownership classifier gains
  Bird's minor-contributor finding (3+ contributors each under 5% share →
  Elevated). The audit now also runs commit velocity so the burnout rule
  can fire there.
- **FIX (Reports, orchestration):** One churn computation per report (the
  per-author breakdown carries the plain totals — previously technical and
  code-review ran two `git log -p` passes); the code-review report now
  applies the RA-SZZ refactoring-context downgrade it was missing;
  independent analyses run concurrently; and compound findings finally
  contribute report `hints` (their joined `"a + b"` source string is split
  back into catalog keys — previously compounds, the highest-priority
  findings, contributed no hints at all).
- **DOCS (Hints & guide):** `tool_hints_catalog` enriched with the new
  report bands and cross-tool joins (ownership x hotspot, burnout x
  hotspot, drift entanglement ratios); `doc/INTERPRETATION_GUIDE.md` gains
  sections for every new band and compound rule; `doc/tools/REFERENCES.md`
  drops its dangling `TOOLS_ACADEMIC_FOUNDATIONS.md` links and section
  column and adds Eyolfson, Tan & Lam (MSR 2011).

# 3.1.1
- **FIX (MCP transport, notification replies):** `McpServer` no longer
  replies to unrecognized JSON-RPC notifications (messages with no `id`
  field, e.g. `notifications/cancelled`, `notifications/roots/list_changed`,
  `notifications/progress`). Previously, any notification not matched by a
  rule fell through to the generic `Method not found` error path, which
  serialized `id: null` since the incoming message had no `id` key at all —
  producing `{"jsonrpc":"2.0","id":null,"error":{...}}`, a message that is
  neither a valid JSON-RPC response nor request and that MCP clients reject
  outright, taking the server offline from the client's perspective. Per
  JSON-RPC 2.0, notifications must never receive a reply; `_handleRequest`
  (`lib/src/mcp/mcp_server.dart`) now checks `request.containsKey('id')` and
  silently drops (logging to `errorSink` only) any unmatched notification,
  while unmatched requests still receive the `Method not found` error as
  before.

# 3.1.0
- **BREAKING (Reports, structured hints):** `hints` in every
  `generate_*_report` response changes from a flat string array to an
  object with `interpretation`/`caveats`/`pair_with` keys, mirroring the
  shape `ToolHints.toJson()` already used for raw single-tool calls. The
  previous aggregation (`ReportPayload._selectHints`) picked **one** string
  total per contributing tool — a caveat always won over a pair_with
  suggestion for the same tool — and hard-capped the combined list at 6,
  regardless of how many analyses fed the report (`generate_repository_audit`
  unions ~13). The new aggregation (`ReportPayload._aggregateHints`) collects
  every distinct interpretation/caveat/pair_with string from every
  contributing tool's `toolHintsCatalog` entry, deduplicated per category
  and deliberately uncapped, so a pair_with suggestion can never be
  crowded out by that same tool's own caveat.
- **FEAT (Skills, catalog-native deep dives):** Each reporting skill's
  `<deep_dive>` raw-tool list is now generated from a new
  `reportToolSources` map (`lib/src/intelligence/interpretation/
  report_tool_sources.dart`) via a `<!-- generate:deep_dive_tools
  report=... -->` marker in `SKILL.template.md`, instead of hand-written
  prose. The prose had already drifted from what each report actually
  runs: technical-reporting's list omitted `analyze_file_ownership` (used);
  pm-reporting's omitted `analyze_bug_hotspots` (used) and listed
  `analyze_release_delta` (never called); code-review-reporting's listed
  `analyze_pr_diff`/`evaluate_comments` (never called) and omitted
  `analyze_code_quality`/`detect_secrets_in_commits`/
  `analyze_bug_hotspots`/`analyze_file_ownership` (all used); the top-level
  audit skill's listed `analyze_architecture_drift` (never called). A new
  test (`report_tool_sources_test.dart`) statically cross-checks the map
  against `ReportOrchestrator`'s actual classifier calls per report, and
  `prompts_sync_test.dart` asserts every generated deep-dive list matches
  the map exactly, so this class of drift can no longer recur silently.
- **REMOVED (predict_merge_conflicts):** The `predict_merge_conflicts` tool,
  `ConflictRiskHeuristic`, and `ConflictRiskClassifier` are deleted, along
  with the `base_branch`/`target_branch` parameters of
  `generate_code_review_report` that existed solely to feed it. It was the
  only report-feeding tool whose contribution was fully opt-in (only ran
  when both branch parameters were supplied) and relied on purely textual
  `git merge-tree` three-way merge prediction, which the tool's own catalog
  entry already documented as missing/flagging conflicts at a substantial
  rate. Compound Rule 6 (predicted conflict × bug hotspot) is removed with
  it.
- **FEAT (Skills, depth escalation):** Each of the five reporting skills
  gains a short trailing `<deep_dive optional="true" audience="capable
  models">` section: the default path stays the compact one-call
  narrate-the-report workflow (the small-LLM path, unchanged in cost), and
  capable models get an explicit route to the report's raw analysis tools
  plus `read_report_slice` drill-down. One skillset serves both model
  classes; no duplicated skill surface.
- **REFACTOR (Skills, single-sourcing v2):** The five reporting skills are
  now generated from `SKILL.template.md` files that reference shared
  partials in `.agents/skills/_shared/` (`reporting_contract.md`,
  `reporting_prepare_step.md`, `reporting_deep_dive_intro.md`) — the
  contract/prepare/deep-dive boilerplate previously copied verbatim across
  all five skills (and mirrored into five generated prompts) now lives
  once. `tool/sync_prompts.dart` expands the template and writes **both**
  the agent-facing `SKILL.md` (with a generated-file notice, stripped from
  prompt bodies) and the Dart prompt; `prompts_sync_test` guards both
  axes. The shared contract text now also names the `basis` citation field.
- **FEAT (Reports, real complexity science):** The technical, code-review,
  and audit reports now include **genuine McCabe cyclomatic complexity and
  maintainability-index findings** (`lexicalComplexity` category, standard
  absolute bands: CC > 10/20/50 → Elevated/High/Critical; MI < 85/65 →
  Elevated/High). The new `BoundedLexicalMetricsSampler` (ADR-0014) lexes
  only the top-`maxLexicalMetricsFilesPerReport` files by churn (skipping
  files over `maxLexicalMetricsFileSizeBytes`, path-traversal-safe, in a
  background isolate), so report runtime stays bounded. Previously the
  lexical metrics engine was reachable only via
  `calculate_universal_lexical_metrics` and never appeared in any report;
  report "complexity" was solely the diff-keyword proxy (which remains, as
  a repo-relative signal).
- **FEAT (Reports, orphaned analyzers wired in):**
  - PM report gains **delivery cadence** findings from
    `CommitVelocityHeuristic`: declining trend (Elevated), Gini author
    concentration > 0.6 (High), burnout-window share > 15% (High).
  - Code-review report accepts optional `base_branch`/`target_branch` and
    classifies **predicted merge conflicts** (`ConflictRiskHeuristic`):
    textual conflicts High, logical overlaps Elevated.
  - Technical report gains **refactoring awareness**
    (`RefactoringDetectionAlgorithm`): churn/volatility findings on
    refactored files are downgraded one band (the RA-SZZ insight), and 5+
    refactoring commits surface as an Elevated tech-debt-paydown signal.
  - Repository audit gains **commit hygiene** aggregates: mega commits and
    suspicious commits, one bounded finding per family.
- **FEAT (Interpretation, new compound rules):** Rule 5 — genuine McCabe
  High-or-worse + top-decile churn on the same file → **Critical**
  `real_complexity_x_churn`; Rule 6 — predicted conflict + bug hotspot →
  **High** `conflict_x_bug_hotspot`.
- **CHORE (Docs process):** Plain git-operation tools (`core` category) are
  now exempt from the per-tool `doc/tools/` document requirement (their
  `inputSchema` is the complete contract); `tools_docs_sync_test` encodes
  the exemption list. Follows the doc cleanup that removed those documents.
- **FEAT (Intelligence, research visibility):** Every classified `Finding`
  now carries its academic grounding in the payload: a compact `basis`
  citation tag (e.g. `Truck-factor estimation (Avelino et al. 2016)`) that
  rides inline in every report preview, and a fuller one-to-two-sentence
  `rationale` with the citation that lives only in the offloaded full
  report (the offload preview strips it, `previewStrippedFindingKeys`).
  All ten classifiers and all four compound-risk rules own their citation
  constants (`researchBasis` / `researchRationale`); citations resolve in
  `doc/tools/REFERENCES.md`. Previously the research backing the bands was
  documented but never visible in any tool response.
- **FEAT (MCP, spec compliance):** `tools/call` now returns
  `structuredContent` alongside the standard text block for every tool that
  advertises an `outputSchema`, as MCP 2025-06-18 specifies (a declared
  schema promises structured output). Non-JSON payloads fall back to
  text-only.
- **PERF/BREAKING (MCP, tools/list):** `outputSchema` is now advertised only
  where the shape is stable, compact, and drives `structuredContent`
  (ADR-0013): the five report meta-tools, the tiny git-operation results,
  `get_stats`, `is_git_repository`, `fetch_tags`, and
  `calculate_universal_lexical_metrics`. The ~21 broad-but-shallow bespoke
  schemas added in the previous release are removed — the offload `preview`
  already conveys that structure at response time for free. The serialized
  `tools/list` payload drops from ~41,000 to ~35,635 bytes (~11,500 → ~9,900
  tokens); the regression budget
  (`test/mcp/tools_list_size_test.dart`) tightens from 48,000 to 40,000
  bytes.
- **PERF/BREAKING (MCP, offload preview):** The offload summary's `preview`
  now carries a single `structure` map (`key -> 'array(<n>)' | 'object' |
  <scalar type>`) instead of the redundant `top_level_keys` /
  `array_lengths` / `value_types` trio — each key appears once instead of up
  to three times, cutting the recurring inline cost of every offloaded call.
  The structural index is built by the shared
  `lib/src/mcp/utils/json_structure_preview.dart` helper, which
  `read_report_slice` now also uses for its path-miss `available_keys`
  response. The `summary`/`top_findings`/`compound_findings` passthrough is
  unchanged.
- **PERF (MCP, offload hint):** The ~300-character `hint` repeated in every
  offload summary is replaced by the short centralized
  `offloadedReportHint` constant (`lib/src/constants.dart`); the full
  offload contract lives once in `get_rw_git_documentation` instead of
  being re-sent per call.

# 3.0.10
- **FEAT (Intelligence):** Upgraded the SZZ implementation from MA-SZZ to
  **RA-SZZ** (Refactoring-Aware SZZ: Neto et al., SANER 2018), removing the
  future-work note in `doc/tools/history/find_bugs_by_developer.md`. Two new
  refactoring guards: deleted lines whose content re-appears among the fix
  commit's added lines are treated as moved code and excluded from blame
  (lines under 8 normalized characters are exempt and boilerplate recurs
  naturally, threshold in `raSzzMovedLineMinimumLength`); and attributions
  whose introducing commit subject matches refactoring keywords are
  discarded (subjects fetched once per commit and cached; unresolvable
  subjects fail open). Both are lexical, language-agnostic stand-ins for
  RefDiff's AST-based operation detection which is the same trade-off as
  `analyze_refactoring`. Affects `analyze_bug_hotspots` and
  `find_bugs_by_developer`; blame now targets only surviving deleted lines
  (grouped into contiguous ranges) instead of whole pre-image hunk spans.
- **REFACTOR/FEAT (MCP):** `generate_changelog` now delegates its fix
  enrichment to the shared `SzzAlgorithm` core instead of an inline mini-SZZ
  that lacked the MA-SZZ flags and all RA-SZZ guards. `SzzAlgorithm` gained a
  public per-commit entry point (`traceFixCommit`) so tools that select fix
  commits themselves reuse the exact same pipeline; the class doc now states
  it is the package's single SZZ implementation. **BREAKING (output):** each
  `bug_introducing_commits` entry is now an object with `introducing_commit`
  (full 40-char hash), `introduced_date`, and `days_bug_lived` — the
  temporal-context contract `doc/tools/history/generate_changelog.md` always
  documented — instead of a bare abbreviated-hash string.
- **CHORE (Models):** Removed the dead `BugIntroductionDto`
  (`lib/src/models/bug_introduction_dto.dart`) because it is unexported, untested, and
  unused since the SZZ pipeline moved to `SzzMatch`; it still carried the
  misleading `timeTakenToFixInHours` name.
- **BREAKING (Intelligence/MCP):** Renamed the SZZ "time to fix" metrics to
  **bug lifetime**, reported in **days**. The metric measures the span from
  the bug-introducing commit to the bug-fixing commit (Kim & Whitehead,
  *How long did it take to fix bugs?*, MSR 2006 - median lifetimes of
  100–200 days are normal), not the effort spent fixing - labelling it
  "time to fix" in hours made every report read as thousands of hours of
  fix effort. `BugHotspotDto` fields and JSON keys are now
  `*_average_bug_lifetime_in_days`; `find_bugs_by_developer` returns
  `bug_lifetime_in_days` (fractional days) instead of `time_to_fix_in_hours`;
  the `BugHotspotClassifier` metric/evidence keys and
  `doc/INTERPRETATION_GUIDE.md` follow (ADR-0010 process). The severity bands
  are unchanged — they are relative (1–2x / >2x the repository's own
  average), so the unit change alters no classification.
- **FEAT (MCP):** Per-tool offload thresholds (ADR-0011), resolving the
  single-global-threshold trade-off recorded in ADR-0001.
  `McpToolFileOffloadDecorator` takes an `offloadThresholdBytes` override,
  wired from the `perToolOffloadThresholdBytes` map in
  `lib/src/constants.dart`: report meta-tools offload above 4 KiB (their
  offload summary already carries the findings inline), `get_stats` and
  `get_commits_between` stay inline up to 16 KiB (their output is consumed
  whole), everything else keeps the 8 KiB default. The advertised
  `(>NKB offloaded to disk.)` note now reflects each tool's actual gate.
- **FEAT (MCP):** Structured logging with host-controlled verbosity
  (ADR-0012). Library logging now flows through the `RwGitLogger` facade
  (still mirrored to `dart:developer`); the server advertises the `logging`
  capability, handles `logging/setLevel` (invalid levels rejected as
  JSON-RPC invalid params), and forwards events as `notifications/message`
  filtered by the host-selected minimum level (default: `warning`).
  `GitCommand` start/finish events are `debug`, failures are `error`.
- **DOCS (Process):** `AGENTS.md` Rule 13 forbids future-work statements
  ("will be implemented in the future", "planned", "TODO") in documents;
  deferred capabilities must be raised with the user and either implemented
  or recorded as an explicit decision.

# 3.0.9
- **DOCS (Tools):** Brought `doc/tools/` back in sync with the registered tool surface: merged the three stale comment-tool documents into `doc/tools/static_analysis/evaluate_comments.md`, folded `analyze_code_quality_with_authors.md` into `analyze_code_quality.md` (the `includeAuthors: true` section), added the five missing report meta-tool documents under `doc/tools/reports/`, and added `doc/tools/system/read_report_slice.md`. `README.md` now lists the report meta-tools, the merged `evaluate_comments` tool, and `read_report_slice`.
- **TEST (Docs sync):** Added `test/mcp/tools_docs_sync_test.dart`, asserting bidirectionally that every tool registered in `server_registry.dart` has a matching `doc/tools/**/<name>.md` and vice versa; `AGENTS.md` now codifies the matching Tool Documentation Sync rule and restates the coverage requirement in terms of the `coverage.yml` CI gate.
- **DOCS (ADRs):** Added ADR-0009 (tool-registry ordering is a deliberate small-LLM discoverability ranking — report tools first) and ADR-0010 (interpretation thresholds: classifier code is the single source of truth; `INTERPRETATION_GUIDE.md` must be updated with a stated justification in the same commit).
- **DOCS (Citations):** Consolidated the master academic reference list into `doc/tools/REFERENCES.md` as the single canonical citation index; `TOOLS_ACADEMIC_FOUNDATIONS.md` §7 now points there.
- **CHORE (Skills/Prompts):** Each reporting skill now carries a `<contract>` section pinning the ADR-0001/ADR-0005 payload contract (`summary`/`top_findings`/`compound_findings`, offload `preview`) with a drift fallback; the installation skill references `defaultCommitLimit` in `lib/src/constants.dart` instead of hard-coding the 500-commit default. Prompts regenerated via `tool/sync_prompts.dart`.
- **FIX (Quality):** Added `example/README.md` in order to be able to render multiple examples (core git commands usage, intelligence commands usage) in pub.dev.
- **FEAT (MCP, small-model efficiency):** Added five one-call **report meta-tools** — `generate_repository_audit`, `generate_technical_report`, `generate_security_report`, `generate_pm_report`, `generate_code_review_report`. Each runs the relevant analyses, then applies every severity band and cross-tool compound-risk rule **in Dart**, and returns a small, ranked, already-classified payload (`summary`, `top_findings`, `compound_findings`). This moves interpretation, correlation, and ranking out of the LLM: a small/local model produces a full report from a single call instead of orchestrating ~10 raw tools, reading offloaded files, and applying a 900-word interpretation guide itself. Measured on this repo: a technical report drops from ~9 hops / ~318K worst-case read-tokens to **1 hop / ~1.9K tokens, inline-complete**.
- **FEAT (Intelligence):** New deterministic interpretation layer under `lib/src/intelligence/interpretation/` — a `Severity`/`Finding` model, per-metric classifiers (bus factor, ownership, bug hotspots, complexity, churn, logical coupling, volatility, dependency freshness, compliance, secrets), a `CompoundFindingCorrelator` encoding the four cross-tool AND-rules, and a `ReportOrchestrator`/`ReportPayload`. All reuse the existing analysis algorithms (library-first) and are exported from `package:rw_git/rw_git.dart`.
- **FEAT (MCP):** The offload decorator now surfaces `top_findings`/`compound_findings`/`summary` into the offload `preview`, so an offloaded report stays **actionable inline** — a small model narrates it without a second file read.
- **BREAKING (MCP):** Merged the three comment tools (`evaluate_comment_quality`, `evaluate_comment_necessity`, `evaluate_comment_llm_generation`) into a single **`evaluate_comments`** tool with an `aspects` parameter (defaults to all). Merged `analyze_code_quality_with_authors` into **`analyze_code_quality`** via an `includeAuthors` flag. Net tool-selection surface: −3 near-duplicates, +5 report tools, and `tools/list` is now ~34.6KB (~8.7k tokens) — smaller than the previous ~9k despite the new capability.
- **CHORE (MCP):** Extracted the ~900-word interpretation guide out of the `get_rw_git_documentation` runtime output into `doc/INTERPRETATION_GUIDE.md`; the tool now leads with the report meta-tools and points raw-tool users at the reference. Trimmed the repeated offload boilerplate on every wrapped tool's description.
- **CHORE (Skills/Prompts):** Rewrote all five reporting skills (and their generated prompts) to call the matching report meta-tool and narrate its findings, dropping the "read offloaded files iteratively" and "apply the interpretation bands" instructions that small models could not reliably follow.
- **FEAT (Tooling):** Added `tool/measure_report_quality.dart` (+ `tool/harness/`), a deterministic in-process harness that measures hops-to-report, inline-completeness, and worst-case read-tokens for the raw-tool vs meta-tool flows — the before/after proof and a CI-friendly regression gate.

# 3.0.8
- **FEAT (Library):** Exposed the intelligence/analysis algorithms (bus factor, bug hotspots, logical coupling, code volatility, etc.) directly from `package:rw_git/rw_git.dart`, so consumers can use the same analyses the MCP tools rely on without running the MCP server.
- **FEAT (Intelligence):** Added package freshness check for `analyze_dependency_drift` tool.
- **FEAT (MCP):** `McpToolFileOffloadDecorator` now returns small responses (under 8KB, `offloadSizeThresholdBytes`) inline instead of unconditionally offloading them to disk, eliminating a wasted file-write/file-read round trip for low-volume tools like `get_stats` and `get_contributions_by_author`.
- **FIX (MCP):** Implemented the `return_full_json` opt-out argument on `McpToolFileOffloadDecorator`. It was documented (and referenced in earlier CHANGELOG entries) but never actually wired into the decorator's `execute()` or `inputSchema` — passing it had no effect. It now correctly skips file offloading and returns the full JSON inline.
- **FEAT (MCP):** Offload summaries now include a `preview` field (top-level keys, value types, array lengths) so LLMs can target reads without guessing the offloaded file's shape.
- **FEAT (MCP):** Added `read_report_slice` tool to fetch a targeted key-path/array-slice from a previously offloaded report file, instead of reading the entire file into context.
- **CHORE (MCP):** Shrunk the offload boilerplate appended to all 27 wrapped tools' descriptions from a ~70-word paragraph to one sentence pointing at `get_rw_git_documentation`, reducing the fixed token cost of every `tools/list` call.
- **DOCS:** Updated `get_rw_git_documentation` with the new size threshold, `return_full_json`, `read_report_slice`, and an advisory `format: summary|full` parameter-naming convention for future tools.
- **PERF (MCP):** Cut the fixed `tools/list` cost from ~43KB (~12k tokens) to ~30KB (~8.4k tokens) by deferring the offload contract to `get_rw_git_documentation` instead of stamping a verbose paragraph plus two long property descriptions onto all 35 tool schemas. A regression test (`tools_list_size_test.dart`) now guards the budget. This lowers the floor enough for 8–16K-context local models to hold the full tool surface.
- **FEAT (MCP):** `tools/list` now advertises standard tool **annotations** (`readOnlyHint`/`idempotentHint`) — 30 read-only analysis tools are marked auto-approvable and 5 repository-mutating tools (clone/checkout/init/fetch) are flagged — plus an `outputSchema` on `analyze_bus_factor`. Metadata is attached centrally via `McpToolWithMetadata` without touching individual tools.
- **FEAT (MCP):** Bumped the implemented protocol revision to **2025-06-18** with version negotiation (older revisions still accepted), accurate capability advertisement, and `serverInfo.version` sourced from a single constant.
- **FEAT (MCP):** Offloaded reports are now exposed as MCP **Resources** (`resources/list` / `resources/read`); offload summaries include a `resource_uri`. Only files produced this session are readable. The existing `read_report_slice` path is unchanged for small/local models.
- **FEAT (MCP):** Optional `tools/list` **pagination** (opaque cursor) via the `RW_GIT_TOOLS_PAGE_SIZE` env var, for clients with very small context windows. Off by default (full list returned).
- **REFACTOR (MCP):** Extracted tool/prompt registration into a single `buildDefaultRegistry()` shared by the `rw_git_mcp` executable and the test suite, removing duplication between production and tests.
- **CHORE (Build):** Agent workflows now have a single source of truth — MCP prompt Dart sources are generated from the canonical `.agents/skills/<name>/SKILL.md` via `tool/sync_prompts.dart`, with a drift-guard test (`prompts_sync_test.dart`).
- **DOCS:** Documented all five reporting prompts and the six bundled skills in `README.md`; added a "Adding or modifying prompts and skills" section to `CONTRIBUTING.md`; added `doc/SMALL_LLM_EFFICIENCY_EVALUATION.md` (token-cost model and local/frontier model suitability matrix).

# 3.0.7
- **REFACTOR:** Refactored the MCP tools implementation, adhering to SRP principles and making the repository future-proof and easily extendable.
- **FEAT (Quality):** Based on academic papers, enhanced the MCP tools underlying technical foundations and documented under `doc/tools`.

# 3.0.6
- **TEST (Quality):** Added `documentation_formatting_test.dart` to enforce 80 column wrapping for the README file.
- **DOCS:** Formatted `README.md` and `.agents/skills/**/SKILL.md` to adhere strictly to the 80 column wrap limit.
- **FEAT (MCP):** Added `find_bugs_by_developer` tool to track bugs introduced by specific developers using a sophisticated SZZ algorithm. Extracted SZZ logic into a reusable `SzzAlgorithm` core class.
- **FEAT (MCP):** Added average time to fix a bug / time taken to fix a bug for both bug-hotspots and bugs-per-developer tools.
- **FEAT (SKILL):** Added specialized skills for different aspects of reporting to cover a variety of stakeholders needs.
- **FEAT (Quality):** Removed duplicate SKILL and README files from root repo and distribution/npm. These are now packaged for npm with a pre-package step.
- **REFACTOR (MCP):** Updated the `get_rw_git_documentation` tool to dynamically generate its markdown list of available tools from the `McpRegistry`, eliminating duplicate documentation across the codebase.
- **FIX (MCP):** Implemented safe argument extraction (`getStringArgument`, `getOptionalStringArgument`) for all MCP tools to provide clear, actionable error messages to LLMs when required arguments are missing or malformed, instead of crashing with a cryptic Dart type cast error (`type 'Null' is not a subtype of type 'String' in type cast`).
- **FEAT (MCP):** Implemented `McpToolFileOffloadDecorator` to automatically offload heavy analytical tool JSON responses to the local filesystem by default, preventing LLM context window overflow.
- **FEAT (MCP):** Added `output_file` and `return_full_json` arguments to all verbose analysis tools to allow LLMs to control context ingestion and orchestration paths.
- **FEAT (MCP):**: Implemented 4 new Mining Software Repositories (MSR) algorithms with corresponding MCP tools:
    - **Analyze Logical Coupling**: Detects files that frequently change together to identify architectural decay.
    - **Analyze Bus Factor**: Calculates the project's Truck Factor to highlight knowledge concentration risks.
    - **Analyze Code Volatility**: Predicts defect-prone files based on historical code churn and author count.
    - **Analyze Refactoring**: Detects structural refactorings and code simplifications approximating AST differencing.

# 3.0.5
- **FIX (Quality):** Fixed an issue where the secret scanner (`detect_secrets_in_commits`) produced false positives for integrity hashes in lockfiles (like `package-lock.json`), generic placeholder variables in test files, and CI workflow variables. The scanner now uses improved context-aware risk scoring to exclude lockfiles, broadens test exclusions, and filters out common placeholder patterns.
- **FIX (SKILL):** Overhauled the reporting SKILL to guide LLMs efficiently, especially small/less capable ones which drift easily.

# 3.0.4
- **FEAT (MCP)**: Because many small LLMs completely ignore the file offloading, made the behaviour default and mandatory. This approach saves tokens and increases efficiency.

## 3.0.3
- **FIX (MCP):** Fixed issue with small LLMs hallucinating tool calls and not reading the offloaded JSON results.
- **CHORE (Agent Skills):** Updated agent skills to provide more comprehensive documentation and guidance.

## 3.0.2
- **FIX (MCP):** Implemented safe argument extraction (`getStringArgument`, `getOptionalStringArgument`) for all MCP tools to provide clear, actionable error messages to LLMs when required arguments are missing or malformed, instead of crashing with a cryptic Dart type cast error (`type 'Null' is not a subtype of type 'String' in type cast`).
- **FEAT (MCP):** Implemented `McpToolFileOffloadDecorator` to automatically offload heavy analytical tool JSON responses to the local filesystem by default, preventing LLM context window overflow.
- **FEAT (MCP):** Added `output_file` and `return_full_json` arguments to all verbose analysis tools to allow LLMs to control context ingestion and orchestration paths.

## 3.0.1
- **FIX (MCP/NPM):** Resolved an issue where `npx @rw-core/rw-git-mcp` would fail with an `ENOEXEC` error. The npm package's `install.js` script now correctly handles non-200 HTTP responses and expects the raw, uncompressed binary executable to be available on GitHub Releases.
- **CHORE (Distribution):** Updated the GitHub Actions release workflow (`release_mcp.yml`) to upload the raw uncompressed executables in addition to the `.tar.gz` and `.zip` archives.

## 3.0.0
- **BREAKING (Core):** All major Git commands (`branch`, `status`, `diff`, `blame`, `show`, `getCommitsBetween`, `stats`) now return strongly-typed model classes (`GitBranch`, `GitStatus`, `GitDiff`, `GitBlame`, `GitCommit`, etc.) instead of raw Strings or `List<String>`.
- **BREAKING (MCP):** The MCP server now returns structured JSON representations of these Git domain models, enabling LLMs to deterministically parse and reason about Git repository state.
- **PERF (Core):** Migrated internal Git parsing logic to use `Isolate.run()` for large CLI outputs (over 10,000 characters), significantly reducing main-thread blocking in heavy Git operations.
- **FEAT (Core):** Added new models (`GitCommit`, `GitTag`, `GitBranch`, `GitStatus`, `GitFileChange`, `GitDiff`, `GitFileDiff`, `GitBlame`, `GitBlameLine`) under `lib/src/models/git/` to provide a robust object-oriented representation of Git objects.

## 2.0.2
- **FEAT (MCP):** Added AST & architecture analysis tools and metrics (`analyze_dart_ast_quality`, `analyze_architecture_drift`, `analyze_clean_code`).
- **FEAT (MCP):** Added `calculate_universal_lexical_metrics` tool to compute language-agnostic code quality metrics (Cyclomatic, Halstead, Cognitive, Maintainability Index) using a fast zero-allocation FSM Lexer.
- **BREAKING (Core & MCP):** Completely removed `cloneAndGetStatistics` method from `RwGit` facade and its corresponding MCP tool (`clone_and_get_statistics`) as this functionality is fully covered by the core `clone` and `stats` methods.
- **DOCS:** Added explicit documentation restricting LLMs from running intrusive custom commands (e.g., `git push`).
- **CHORE:** Improved and expanded the report orchestration MCP skill with new tools.
- **CHORE:** Added comprehensive tests to achieve 100% test coverage.

## 2.0.1
- **FEAT (MCP):** Added native support for MCP Resources and Prompts protocol capabilities.
- **DOCS:** Added comprehensive agent skills for installing the `rw-git` MCP server and for orchestrating comprehensive repository reports.
- **CHORE (Core):** Removed `git2dart` FFI integration and reverted to process-based executions with latest path dependency.
- **CHORE:** Fixed NPM package configuration, README, and GitHub Actions release workflows (`release_mcp.yml`).

## 2.0.0
- **FEAT (MCP):** Added `analyze_pr_diff` tool to analyze PR diffs for risk signals by combining churn history, bus factor, and secret detection into per-file composite risk scores.
- **FEAT (MCP):** Added `predict_merge_conflicts` tool to identify files modified on both branches since their merge base, predicting potential merge conflicts before a merge attempt.
- **FEAT (MCP):** Added `analyze_commit_velocity` tool to compute time-series commit velocity with per-author breakdown, trend analysis (accelerating/decelerating/stable), and anomaly detection.
- **FEAT (MCP):** Added `analyze_dependency_drift` tool to parse dependency manifests (pubspec.yaml, package.json, requirements.txt, go.mod, Cargo.toml, Gemfile) for supply chain risk analysis.
- **FEAT (MCP):** Added `generate_changelog` tool to generate structured changelogs using Conventional Commits conventions (feat/fix/BREAKING CHANGE).
- **FEAT (MCP):** Added `audit_compliance` tool to scan commit history for unsigned commits, empty messages, and unrecognized author emails.
- **FEAT (MCP):** Added `analyze_file_ownership` tool to cross-reference CODEOWNERS with git blame history for ownership drift detection.
- **FEAT (Core):** Added `findConflictRiskFiles`, `calculateCommitVelocity`, `parseDependencyManifests`, `scanComplianceIssues` methods to `CodeQualityTracker`.
- **FEAT (MCP):** Added `detect_secrets_in_commits` tool to scan commit history for exposed secrets using Isolates.
- **FEAT (MCP):** Added an optional `includeCodeDiff` boolean parameter to the code quality tools to provide actual git diffs for LLM code smell analysis, replacing the previous hardcoded hallucination-prone prompt.
- **BREAKING (MCP):** `analyze_code_quality`, `analyze_code_quality_with_authors`, and all `evaluate_comment_*` tools now return structured JSON instead of prescriptive prose prompts. This aligns them with the `analyze_release_delta` and `analyze_bus_factor` output conventions and significantly reduces token consumption.
- **PERF (MCP):** Replaced `git log --stat` with `git log --shortstat --format=%H %s` in the code quality tools, reducing the raw commit log payload by ~95% for large repositories.
- **FIX (MCP):** Removed the hardcoded "Staff Software Engineer" persona from all analysis and comment evaluation tools to avoid conflicting with the calling LLM's own identity.
- **FIX (MCP):** The `topN` parameter now applies consistently to all lists (suspicious commits, mega commits, high-churn files, classes, and blocks). Previously, suspicious and mega lists were unbounded when `topN` was not set.
- **REFACTOR (MCP):** `BaseEvaluateCommentsTool` hook method changed from `getPromptInstructions()` (returning a String) to `getEvaluationCriteria()` (returning `List<String>`).
- **REFACTOR (MCP):** `BaseAnalyzeCodeQualityTool` hook methods changed from `getChurnMetricsString()`/`getPromptInstructions()` to `getChurnData()`/`getAnalysisGuidance()` returning structured Maps.
- **RENAME (MCP):** The `includeRawLog` parameter has been renamed to `includeCommitLog` to better reflect the compact `--shortstat` format.

- **FEAT (Core):** Implemented the `Result<T, E>` pattern (`Result.getOrThrow()`) across all internal commands and public facades, removing raw Exceptions and unhandled `ProcessException`s from the execution flow.
- **FEAT (Core):** Added 9 new highly-requested git operations to `RwGit`: `branch`, `status`, `pull`, `push`, `diff`, `merge`, `stash`, `blame`, and `show`.
- **FEAT (Core):** Upgraded `GitCommand` execution to support path sanitization (directory traversal protection), observability via `dart:developer` timing logs, and extensibility hooks (`onBeforeRun`, `onAfterRun`).
- **FEAT (Core):** Unified argument handling by allowing `List<String> extraArgs` in all internal git commands.
- **PERF (Quality):** Optimized `CodeQualityTracker.calculateChurn` and `calculateChurnWithAuthors` to stream `git log` output asynchronously, eliminating Out of Memory crashes on massive repositories.
- **FIX (Quality):** Fixed a bug in `RwGitParser.parseGitShortLogStdout` where multi-word author names were incorrectly truncated.
- **CHORE:** Removed `dynamic` typing entirely from the codebase, updated `lints` to `^5.0.0`, and strictly enforced `dart analyze --fatal-infos`.

- Architecture: `RwGit` is now an abstract factory interface, preparing the core library for non-CLI Git operations.
- Architecture: Added `CliRwGit` to encapsulate existing `Process.run` functionality, ensuring no breaking changes to default behavior.
- Tooling: Added `executables` declaration in `pubspec.yaml` to allow running the MCP server globally via `dart pub global activate rw_git`.
- Distribution: Created GitHub Actions workflow `.github/workflows/release_mcp.yml` for automated cross-platform binary compilation.
- Distribution: Created scaffolding for npm packaging.

- [REFACTOR] `analyze_code_quality` and `analyze_code_quality_with_authors` tools to use Template Method pattern (`BaseAnalyzeCodeQualityTool`) eliminating duplicated code logic.

- Exposing RwGitParser through the rw_git package for enhanced flexibility.

- Memory Efficiency: Refactored `CodeQualityTracker` to use an asynchronous stream state-machine (`runStream`) for processing `git log` outputs. This eliminates unbounded memory consumption when analyzing massive diffs in large repositories.
- MCP: Changed the `analyze_code_quality` and `analyze_code_quality_with_authors` tools to use `git log --stat` instead of `git log -p` for their LLM context payload. This significantly reduces token usage and improves LLM accuracy when assessing commit size versus message quality.
- MCP: Rephrased the `get_rw_git_documentation` instructions to prevent LLMs from erroneously attempting to write Python scripts to manually construct JSON-RPC requests to the MCP server.

- MCP: Applied the `limit` parameter to `CodeQualityTracker` methods so that code quality metrics correctly reflect the specified recent commits window instead of parsing the entire repository history.
- MCP: `analyze_code_quality` and `analyze_code_quality_with_authors` now successfully bound their analysis to the requested commit `limit`.

- MCP: Added 10 individual, strongly-typed tools to directly invoke `RwGit` facade methods (`init_repository`, `clone_repository`, `get_stats`, etc.) to provide LLMs with perfect parameter schemas.
- MCP: Cleaned up `execute_git_command` to strictly accept raw git CLI args, preventing hallucination of facade function names.
- MCP: Transformed `get_rw_git_documentation` into a unified Agent Guide to route LLMs natively across all tools.

- Added `streamOutput` opt-in flag across all `RwGit` methods to support real-time streaming of Git standard output and standard error to the console.
- Refactored `ProcessRunner` to use `Process.start` to support seamless output streaming without blocking.
- MCP: Updated tool descriptions to include explicit invocation instructions for better LLM context.
- MCP: Improved code quality tracker outputs for suspicious and mega commits to include author, date, and commit message.

## 1.2.0
- **FEAT**: Added `evaluate_comment_llm_generation` MCP tool to detect LLM artifacts in comments.
- **FEAT**: Added `evaluate_comment_quality` MCP tool to analyze the quality of newly added or modified comments.
- **FEAT**: Added `evaluate_comment_necessity` MCP tool to evaluate whether comments are redundant and if code could be self-documenting instead.
- **REFACTOR**: Consolidated CodeQuality tools.

## 1.1.0
- [REFACTOR] `analyze_code_quality` and `analyze_code_quality_with_authors` tools to use Template Method pattern (`BaseAnalyzeCodeQualityTool`) eliminating duplicated code logic.

## 1.0.4
- MCP: Combined `retrieve_commits_for_ai_review` functionality into `analyze_code_quality` and `analyze_code_quality_with_authors` to provide an internal AI prompt combined with code quality metrics and recent commits for a comprehensive code review context. 
- MCP: Removed `retrieve_commits_for_ai_review`.

## 1.0.2
- Fixed various bugs surfaced from unit testing.
- Code coverage 100%.
- Improved performance and logical output of some commands.

## 1.0.1
- Support for common git commands and operations:
  - `git init`
  - `git clone`
  - `git fetch tags`
  - Count commits between two tags
  - Retrieve statistics regarding code changes (insertions, deletions, number of files changed).
