# analyze_bug_hotspots

## Business Logic

Answers: "Which files and which authors are most associated with bugs across the entire codebase?" Surfaces systemic quality problems (the 20% of files that cause 80% of bugs) so that engineering leadership can make targeted investments in refactoring, testing, and code review focus.

Passing the optional `author` parameter narrows the same analysis to a single developer: "Which bugs did this developer introduce, and how long did each one live before being fixed?" This mode supports targeted code review, mentoring conversations, and identifying which modules carry a developer's knowledge debt. Output is not punitive — it surfaces where extra support or pair programming is needed, not who to blame.

## Algorithm

Runs the **RA-SZZ pipeline** (refactoring-aware SZZ, layered on MA-SZZ whitespace filtering) once per call, then either aggregates across all developers and files, or additionally filters to one developer when `author` is supplied.

**Phase 1 — Bug-fix commit identification:**

Scan all commit subjects with:
- Positive pattern: `fix|bug|patch|issue|resolve|close|closes|resolves` (case-insensitive), overridable via `positiveRegex`
- Negative filter: exclude commits matching `typo|docs|style|refactor|test|comment|whitespace|merge`, overridable via `negativeRegex`

Only commits that match the positive pattern AND do not match the negative filter are treated as bug-fix commits.

**Phase 2 — Deleted line extraction (MA-SZZ improvement):**

For each fix commit, run:
```
git diff -M -w --ignore-blank-lines <parent_hash> <fix_hash>
```
Parse the unified diff to extract deleted lines (with their pre-image line numbers) from `@@` hunks. The `-w` (ignore whitespace) and `--ignore-blank-lines` flags suppress whitespace-only changes — the core MA-SZZ improvement that reduces false positives by approximately 30%.

**Phase 3 — Refactoring line filter (RA-SZZ):**

A deleted line whose whitespace-normalized content re-appears among the same commit's added lines (in any file — moves cross files) was **moved by a refactoring**, not removed by the fix; it is excluded from blame. Lines shorter than 8 normalized characters (`}`, `return;`, `else {`) are exempt from this exclusion: such boilerplate recurs naturally and a match on it is not evidence of movement. This is a lexical, language-agnostic stand-in for RefDiff's AST-based refactoring-operation detection used by the original RA-SZZ.

**Phase 4 — Blame attribution:**

Surviving deleted lines are grouped into contiguous ranges (one `git blame` call per range):
```
git blame --date=iso-strict -l -w -C -C -M -L <start>,<end> <parent_hash> -- <file>
```
- `-w` ignores whitespace in blame
- `-C -C -M` follow code copies and renames across files
- `-L` restricts blame to the surviving deleted line range

Parse blame output to extract the introducing commit hash, author name, and date.

**Phase 5 — Refactoring commit filter (RA-SZZ):**

Fetch the introducing commit's subject (`git log -1`, cached per hash). If it matches the refactoring keyword pattern (`refactor|rewrite|rename|restructure|reformat|format|style|clean|cleanup|move|extract|inline`), the attribution is **discarded**: the buggy code predates the refactoring, so blaming the refactoring author would be a false attribution. An unresolvable subject keeps the attribution (fail open, preserving recall).

**Phase 6 — Aggregation (always) and optional developer filtering:**

- Aggregate per **file**:
  - `bug_introductions`: how many bugs were introduced into this file
  - `average_bug_lifetime_in_days`: mean of `(fix_date − introducing_date)` in fractional days across all bugs in this file. This is the SZZ *bug lifetime* (how long the bug existed in the codebase before being fixed), not the effort spent producing the fix; lifetimes of weeks or months are normal (Kim & Whitehead, MSR 2006)
- Aggregate per **author**:
  - `bug_introductions`: total bugs attributed to this author
- Sort files descending by `bug_introductions`; sort authors descending by `bug_introductions`
- Return top 15 files and top 10 authors
- When `author` is supplied: additionally retain only blame results where the introducing author name matches the queried developer name (case-insensitive substring match), and return them in a `developer_bug_analysis` section

**Output (always):**
- `total_fix_commits_analyzed`, `global_average_bug_lifetime_in_days`
- `top_bug_hotspot_files`, `top_bug_hotspot_authors`

**Output (only when `author` is supplied), per bug in `developer_bug_analysis.bug_introductions`:**
- Introducing commit hash and fixing commit hash
- Affected file path
- Bug lifetime in days: `(fix_date − introducing_date)` in fractional days — the time the bug existed in the codebase before being fixed (SZZ bug lifetime), not the effort spent producing the fix

## Academic Foundation

### Śliwerski, Zimmermann & Zeller (2005) — *When Do Changes Induce Fixes?*

**Published in:** MSR Workshop, ACM

**Key claim:** Systematic bug-inducing-commit identification from version history enables file-level and author-level defect attribution that cannot be derived from bug-tracker data alone, because trackers require manual issue linkage. Bug-introducing commits can be identified algorithmically by taking a bug-fix commit, finding which lines it deleted, and using `git blame` on the parent commit to find who introduced those lines.

**How rw-git uses it:** The SZZ pipeline is the sole attribution mechanism. Both the aggregate hotspot ranking and the per-developer `bug_introductions` list are direct aggregations of the same SZZ output.

---

### da Costa, McIntosh, Shang, Kulesza, Coelho & Hassan (2017) — *Evaluating the accuracy of SZZ: An empirical study on open source projects*

**Published in:** ICSME, IEEE

**Key claim:** The original SZZ algorithm has a false positive rate of 25–40% because it treats whitespace-only reformatting commits as bug introducers. Adding `--ignore-whitespace` and `--ignore-blank-lines` to the diff command reduces false positives without materially reducing true positive recall.

**How rw-git uses it:** The `-w --ignore-blank-lines` diff flags ensure that both file/author hotspot rankings and developer-scoped attributions reflect genuine bug-introducing changes, not cosmetic reformatting. This is the single highest-impact accuracy improvement for the SZZ pipeline.

---

### Neto, Brito, David, Cogo, Leite, Murta & Coelho (2018) — *The Impact of Refactoring Changes on the SZZ Algorithm*

**Published in:** SANER, IEEE

**Key claim:** SZZ's false positive rate is further reducible by 10–20% when refactoring changes are excluded from attribution: lines touched only because code moved are not bug introductions, and commits that merely restructure code are not bug origins.

**How rw-git uses it:** Three refactoring guards implement the RA-SZZ variant: the negative keyword filter excludes refactoring commits from the fix-candidate set (Phase 1); the moved-line filter excludes deleted lines that re-appear as added lines (Phase 3); and the refactoring-commit filter discards attributions whose introducing commit is itself a refactoring (Phase 5). rw-git is language-agnostic, so the line and commit filters are lexical heuristics standing in for RefDiff's AST-diff-based operation detection — the same trade-off documented for `analyze_refactoring`.

---

### Zimmermann, Nagappan, Gall, Giger & Murphy (2007) — *Predicting Defects for Eclipse*

**Published in:** PROMISE Workshop, IEEE

**Key claim:** Historical bug-count per file is one of the strongest predictors of future defects in that file. A file's past defect density is a better predictor than any single structural metric (LOC, complexity).

**How rw-git uses it:** The `bug_introductions` count per file is a direct implementation of this "historical defect count" feature. Files ranking highest in this list are the best candidates for defensive test investment.

---

### Zimmermann, Nagappan, Gall, Giger & Murphy (2007) — *Cross-Project Defect Prediction*

**Published in:** ESEC/FSE, ACM

**Key claim:** Author identity is a statistically significant feature in defect prediction models. Certain developers — not due to skill level but due to the complexity of the modules they own — contribute disproportionately to defect density.

**How rw-git uses it:** The `author`-scoped `developer_bug_analysis` section enables engineering leaders to distinguish module-driven defect patterns (a symptom of bad ownership assignment) from developer-driven patterns (a symptom of mentoring needs), rather than reading a raw per-author count as a performance signal.

---

### Ostrand, Weyuker & Bell (2004) — *Predicting the Location and Number of Faults in Large Software Systems*

**Published in:** ISSTA, ACM

**Key claim:** In large industrial systems, 20% of files account for approximately 80% of all defects (a Pareto distribution). This concentration is stable across releases and enables meaningful prioritisation.

**How rw-git uses it:** The top-N ranking of files by bug count is a direct operationalisation of Ostrand et al.'s finding. Engineering leaders can apply the 80/20 heuristic where the top quintile of the returned list covers most of the bug surface.

---

### Nagappan & Ball (2005) — *Use of Relative Code Churn Measures to Predict System Defect Density*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Code churn (lines changed per file over a release) combined with historical bug count is the most predictive feature pair in file-level defect models.

**How rw-git uses it:** `analyze_bug_hotspots` is commonly used alongside `analyze_code_volatility` (which measures churn) to produce a two-dimensional risk map: high-bug + high-churn files are the highest-priority targets.
