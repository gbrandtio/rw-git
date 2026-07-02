# find_bugs_by_developer

## Business Logic

Answers: "Which bugs did a specific developer introduce, and how long did each one live before being fixed?" Supports targeted code review, mentoring conversations, and identifying which modules carry a developer's knowledge debt. Output is not punitive — it surfaces where extra support or pair programming is needed.

## Algorithm

Implements the **RA-SZZ algorithm** (Refactoring-Aware SZZ), layered on the
MA-SZZ whitespace filtering, filtered to a single author.

**Phase 1 — Bug-fix commit identification:**

Scan all commit subjects with:
- Positive pattern: `fix|bug|patch|issue|resolve|close|closes|resolves` (case-insensitive)
- Negative filter: exclude commits matching `typo|docs|style|refactor|test|comment|whitespace|merge`

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

**Phase 6 — Developer filtering:**

Retain only blame results where the introducing author name matches the queried developer name (case-insensitive substring match).

**Output per bug:**
- Introducing commit hash and date
- Fix commit hash and date
- Affected file path
- Bug lifetime in days: `(fix_date − introducing_date)` in fractional days — the time the bug existed in the codebase before being fixed (SZZ bug lifetime), not the effort spent producing the fix

## Academic Foundation

### Śliwerski, Zimmermann & Zeller (2005) — *When Do Changes Induce Fixes?*

**Published in:** MSR Workshop, ACM

**Key claim:** Bug-introducing commits can be identified algorithmically by taking a bug-fix commit, finding which lines it deleted, and using `git blame` on the parent commit to find who introduced those lines. This produces a "SZZ" (named after the authors) linkage between introducing and fixing commit.

**How rw-git uses it:** The core SZZ pipeline (fix detection → diff deleted lines → blame to introducing commit) is the direct implementation of this paper. Every `find_bugs_by_developer` result is a SZZ attribution chain.

---

### da Costa, McIntosh, Shang, Kulesza, Coelho & Hassan (2017) — *Evaluating the accuracy of SZZ: An empirical study on open source projects*

**Published in:** ICSME, IEEE

**Key claim:** The original SZZ algorithm has a false positive rate of 25–40% because it treats whitespace-only reformatting commits as bug introducers. Adding `--ignore-whitespace` and `--ignore-blank-lines` to the diff command reduces false positives without materially reducing true positive recall.

**How rw-git uses it:** The `-w --ignore-blank-lines` flags added to `git diff` implement the MA-SZZ variant from this paper. This is the single highest-impact accuracy improvement for the SZZ pipeline.

---

### Neto, Brito, David, Cogo, Leite, Murta & Coelho (2018) — *The Impact of Refactoring Changes on the SZZ Algorithm*

**Published in:** SANER, IEEE

**Key claim:** SZZ's false positive rate is further reducible by 10–20% if refactoring commits are excluded from the "fix" candidate set before running blame. The RA-SZZ and L-SZZ variants implement this.

**How rw-git uses it:** Three refactoring guards implement the RA-SZZ variant: the negative keyword filter excludes refactoring commits from the fix-candidate set (Phase 1); the moved-line filter excludes deleted lines that re-appear as added lines (Phase 3); and the refactoring-commit filter discards attributions whose introducing commit is itself a refactoring (Phase 5). rw-git is language-agnostic, so the line and commit filters are lexical heuristics standing in for RefDiff's AST-diff-based operation detection — the same trade-off documented for `analyze_refactoring`.

---

### Zimmermann, Nagappan, Gall, Giger & Murphy (2007) — *Cross-Project Defect Prediction*

**Published in:** ESEC/FSE, ACM

**Key claim:** Author identity is a statistically significant feature in defect prediction models. Certain developers — not due to skill level but due to the complexity of the modules they own — contribute disproportionately to defect density.

**How rw-git uses it:** The per-developer bug-introduction breakdown enables engineering leaders to distinguish module-driven defect patterns (a symptom of bad ownership assignment) from developer-driven patterns (a symptom of mentoring needs).
