# find_bugs_by_developer

## Business Logic

Answers: "Which bugs did a specific developer introduce, and how long did each one live before being fixed?" Supports targeted code review, mentoring conversations, and identifying which modules carry a developer's knowledge debt. Output is not punitive — it surfaces where extra support or pair programming is needed.

## Algorithm

Implements the **MA-SZZ algorithm** (Modified Annotated SZZ) filtered to a single author.

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
Parse the unified diff to extract deleted lines from `@@ -start,count @@` hunks. The `-w` (ignore whitespace) and `--ignore-blank-lines` flags suppress whitespace-only changes — the core MA-SZZ improvement that reduces false positives by approximately 30%.

**Phase 3 — Blame attribution:**

For each deleted line range in each changed file:
```
git blame --date=iso-strict -l -w -C -C -M -L <start>,<end> <parent_hash> -- <file>
```
- `-w` ignores whitespace in blame
- `-C -C -M` follow code copies and renames across files
- `-L` restricts blame to the deleted line range

Parse blame output to extract the introducing commit hash, author name, and date.

**Phase 4 — Developer filtering:**

Retain only blame results where the introducing author name matches the queried developer name (case-insensitive substring match).

**Output per bug:**
- Introducing commit hash and date
- Fix commit hash and date
- Affected file path
- Time-to-fix in hours: `(fix_date − introducing_date).inHours`

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

**How rw-git uses it:** The current implementation uses the negative keyword filter (`refactor|style|...`) as a lightweight proxy for RA-SZZ's full AST-diff-based refactoring detection. Full RA-SZZ integration is the next maturation step.

---

### Zimmermann, Nagappan, Gall, Giger & Murphy (2007) — *Cross-Project Defect Prediction*

**Published in:** ESEC/FSE, ACM

**Key claim:** Author identity is a statistically significant feature in defect prediction models. Certain developers — not due to skill level but due to the complexity of the modules they own — contribute disproportionately to defect density.

**How rw-git uses it:** The per-developer bug-introduction breakdown enables engineering leaders to distinguish module-driven defect patterns (a symptom of bad ownership assignment) from developer-driven patterns (a symptom of mentoring needs).
