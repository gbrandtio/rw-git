# predict_merge_conflicts

## Business Logic

Answers: "Will merging this branch cause conflicts?" Pre-flight conflict prediction saves CI minutes and unblocks developers before they discover conflicts at merge time. Returns a risk level (none / low / medium / high), a list of conflict-candidate files, and any detected textual conflicts.

## Algorithm

**ConflictRiskHeuristic** runs the following pipeline:

1. **Merge base identification:**
   ```
   git merge-base <branch_a> <branch_b>
   ```
   Finds the most recent common ancestor commit.

2. **Per-branch changed file sets:**
   ```
   git diff --name-only <merge_base> <branch_a>
   git diff --name-only <merge_base> <branch_b>
   ```
   Files changed on each branch since the fork point.

3. **Logical overlaps:**
   Set intersection of the two file lists → files that both branches modified. These are conflict *candidates* (they may or may not have textual conflicts depending on which lines were changed).

4. **Textual conflict detection (git ≥ 2.38):**
   ```
   git merge-tree --write-tree <merge_base> <branch_a> <branch_b>
   ```
   Uses git's built-in three-way merge engine to detect actual line-level conflicts without modifying the working tree.

5. **Risk classification:**
   - `none` — empty intersection
   - `low` — 1–2 logical overlaps, no textual conflicts
   - `medium` — 3–9 logical overlaps, or < 3 textual conflicts
   - `high` — ≥ 10 logical overlaps, or ≥ 3 textual conflicts

## Academic Foundation

### Brun, Holmes, Ernst & Notkin (2011) — *Early Detection of Collaboration Conflicts and Risks*

**Published in:** FSE, ACM

**Key claim:** Speculative execution of pending merges — computing the result of merging branches before developers are ready to merge — enables early conflict detection. The Crystal tool shows that most merge conflicts are detectable hours or days before the actual merge attempt. Early detection dramatically reduces the cost of resolution.

**How rw-git uses it:** The entire tool is an implementation of the Crystal principle: run the merge-tree computation proactively, before the developer attempts the merge, so that conflicts surface while context is fresh.

---

### Mens (2002) — *A State-of-the-Art Survey on Software Merging*

**Published in:** IEEE Transactions on Software Engineering

**Key claim:** Merge conflicts fall into three categories: (1) textual — same lines changed in both branches; (2) semantic — code compiles but logic diverges; (3) build — incompatible API changes. Text-based tools like `git merge` detect only textual conflicts.

**How rw-git uses it:** The tool explicitly detects textual conflicts and logical overlaps (file-level candidates). Semantic conflicts are outside scope — they require cross-branch test execution. The documentation surface this limitation so callers are not overconfident.

---

### Cavalcanti, Batory & Borba (2017) — *Evaluating and Improving Semistructured Merge*

**Published in:** OOPSLA, ACM

**Key claim:** Pure text-based three-way merge (git's default) generates spurious conflicts that a structured merge engine would resolve automatically. The paper quantifies false-positive conflict rates at 11–55% depending on language and conflict type.

**How rw-git uses it:** The risk classification deliberately uses *both* logical overlaps (file-level) and textual conflicts (line-level) rather than relying on `git merge-tree` alone. File-level overlaps that do not produce textual conflicts may still indicate semantic risk — they are surfaced at `low` rather than discarded.

---

### Zimmermann, Zeller, Weissgerber & Diehl (2004) — *Mining Version Histories to Guide Software Changes*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Files that were frequently co-changed in the past are likely to need co-changing in future modifications. Logical coupling (co-change history) is a predictor of merge difficulty.

**How rw-git uses it:** The logical overlap detection (file intersection) is the merge-time manifestation of logical coupling: both branches touched the same file because they implement related features. High logical coupling between the branches' changed file sets predicts semantic conflicts even when textual conflicts are absent.
