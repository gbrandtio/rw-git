# analyze_bug_hotspots

## Business Logic

Answers: "Which files and which authors are most associated with bugs across the entire codebase?" Surfaces systemic quality problems (the 20% of files that cause 80% of bugs) so that engineering leadership can make targeted investments in refactoring, testing, and code review focus.

## Algorithm

Runs the same **RA-SZZ pipeline** (refactoring-aware SZZ, layered on MA-SZZ whitespace filtering) as `find_bugs_by_developer` but aggregates across all developers and all files in the repository:

1. Identify all bug-fix commits using the positive/negative keyword filter
2. For each fix commit, extract deleted lines using `git diff -M -w --ignore-blank-lines <parent> <fix>`
3. Exclude refactoring changes (RA-SZZ, see `find_bugs_by_developer.md` Phases 3 and 5): deleted lines that re-appear as added lines in the same commit (moved code), and attributions whose introducing commit is itself a refactoring
4. Blame each surviving deleted line range on the parent to find introducing commits
5. Aggregate per **file**:
   - `bug_introduction_count`: how many bugs were introduced into this file
   - `average_bug_lifetime_in_days`: mean of `(fix_date − introducing_date)` in fractional days across all bugs in this file. This is the SZZ *bug lifetime* (how long the bug existed in the codebase before being fixed), not the effort spent producing the fix; lifetimes of weeks or months are normal (Kim & Whitehead, MSR 2006)
6. Aggregate per **author**:
   - `bugs_introduced`: total bugs attributed to this author
7. Sort files descending by `bug_introduction_count`; sort authors descending by `bugs_introduced`
8. Return top-N files and top-N authors

## Academic Foundation

### Śliwerski, Zimmermann & Zeller (2005) — *When Do Changes Induce Fixes?*

**Published in:** MSR Workshop, ACM

**Key claim:** Systematic bug-inducing-commit identification from version history enables file-level and author-level defect attribution that cannot be derived from bug-tracker data alone, because trackers require manual issue linkage.

**How rw-git uses it:** The SZZ pipeline is the sole attribution mechanism. Hotspot ranking is a direct aggregation of SZZ output.

---

### da Costa, McIntosh, Shang, Kulesza, Coelho & Hassan (2017) — *Evaluating the accuracy of SZZ: An empirical study on open source projects*

**Published in:** ICSME, IEEE

**Key claim:** MA-SZZ (whitespace-filtered) produces significantly more reliable file-level rankings than vanilla SZZ. Without whitespace filtering, style-reformatting commits pollute the hotspot list with false attributions.

**How rw-git uses it:** The `-w --ignore-blank-lines` diff flags ensure that file hotspot rankings reflect genuine bug-introducing changes, not cosmetic reformatting.

---

### Neto, Brito, David, Cogo, Leite, Murta & Coelho (2018) — *The Impact of Refactoring Changes on the SZZ Algorithm*

**Published in:** SANER, IEEE

**Key claim:** SZZ's false positive rate is reducible by a further 10–20% when refactoring changes are excluded from attribution: lines touched only because code moved are not bug introductions, and commits that merely restructure code are not bug origins.

**How rw-git uses it:** The shared RA-SZZ pipeline excludes deleted lines that re-appear as added lines in the same fix commit (moved code) and discards attributions whose introducing commit is itself a refactoring, so hotspot counts reflect genuine defect injections rather than code motion (see `find_bugs_by_developer.md` for the full phase description).

---

### Zimmermann, Nagappan, Gall, Giger & Murphy (2007) — *Predicting Defects for Eclipse*

**Published in:** PROMISE Workshop, IEEE

**Key claim:** Historical bug-count per file is one of the strongest predictors of future defects in that file. A file's past defect density is a better predictor than any single structural metric (LOC, complexity).

**How rw-git uses it:** The `bug_introduction_count` per file is a direct implementation of this "historical defect count" feature. Files ranking highest in this list are the best candidates for defensive test investment.

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
