# get_stats

## Business Logic

Answers: "How much code changed between these two releases, and in which languages?". Provides language-stratified change volume, insertions and deletions per file extension enabling scope estimation, release sizing, and language-specific effort analysis.

## Algorithm

1. `git diff --shortstat <ref1> <ref2>` aggregate total insertions, deletions, and files changed.
2. `git diff --stat <ref1> <ref2>` per-file breakdown with insertion and deletion counts.
3. Group per-file stats by file extension using regex: extract the extension from each file path.
4. Aggregate `insertions` and `deletions` per extension group.
5. Return: aggregate totals + per-extension breakdown sorted descending by total lines changed.

Special grouping: files without extensions (e.g., `Makefile`, `Dockerfile`) are grouped under `no_extension`.

## Academic Foundation

### Boehm (1981) — *Software Engineering Economics*

**Published in:** Prentice-Hall

**Key claim:** Lines of code (LOC) is the most widely available and practically useful scope metric for software project estimation. Despite its limitations, LOC remains the only metric derivable from version history without additional tooling.

**How rw-git uses it:** The insertion + deletion count from `git diff --stat` is a LOC-change metric. The delta form of LOC that avoids the "more code = more work" conflation by measuring change volume, not total size.

---

### Nagappan & Ball (2005) — *Use of Relative Code Churn Measures to Predict System Defect Density*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Relative code churn (lines changed ÷ total lines) is a defect predictor. The raw change count (absolute churn) is the numerator of this ratio and is itself useful when the denominator (total LOC) is unavailable.

**How rw-git uses it:** `get_stats` provides the absolute insertion+deletion count that feeds into release-level churn analysis in `analyze_release_delta`.

---

### Mockus & Votta (2000) — *Identifying Reasons for Software Changes Using Historic Databases*

**Published in:** ICSM, IEEE

**Key claim:** Language-stratified change analysis is important because test code, documentation, and production code changes have different risk profiles. A release with 10,000 lines of test additions and 50 lines of production changes is very different from one with the reverse ratio.

**How rw-git uses it:** The per-extension breakdown enables callers to separate `.test.dart` / `_test.dart` / `spec.ts` changes from production code changes, documentation changes (`.md`), and configuration changes (`.yaml`, `.json`).
