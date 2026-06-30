# analyze_bug_hotspots

## Business Logic

Answers: "Which files and which authors are most associated with bugs across the entire codebase?" Surfaces systemic quality problems — the 20% of files that cause 80% of bugs — so that engineering leadership can make targeted investments in refactoring, testing, and code review focus.

## Algorithm

Runs the same **MA-SZZ pipeline** as `find_bugs_by_developer` but aggregates across all developers and all files in the repository:

1. Identify all bug-fix commits using the positive/negative keyword filter
2. For each fix commit, extract deleted lines using `git diff -M -w --ignore-blank-lines <parent> <fix>`
3. Blame each deleted line range on the parent to find introducing commits
4. Aggregate per **file**:
   - `bug_introduction_count` — how many bugs were introduced into this file
   - `average_time_to_fix_hours` — mean of `(fix_date − introducing_date).inHours` across all bugs in this file
5. Aggregate per **author**:
   - `bugs_introduced` — total bugs attributed to this author
6. Sort files descending by `bug_introduction_count`; sort authors descending by `bugs_introduced`
7. Return top-N files and top-N authors

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

### Zimmermann, Nagappan, Gall, Giger & Murphy (2007) — *Predicting Defects for Eclipse*

**Published in:** PROMISE Workshop, IEEE

**Key claim:** Historical bug-count per file is one of the strongest predictors of future defects in that file. A file's past defect density is a better predictor than any single structural metric (LOC, complexity).

**How rw-git uses it:** The `bug_introduction_count` per file is a direct implementation of this "historical defect count" feature. Files ranking highest in this list are the best candidates for defensive test investment.

---

### Ostrand, Weyuker & Bell (2004) — *Predicting the Location and Number of Faults in Large Software Systems*

**Published in:** ISSTA, ACM

**Key claim:** In large industrial systems, 20% of files account for approximately 80% of all defects (a Pareto distribution). This concentration is stable across releases and enables meaningful prioritisation.

**How rw-git uses it:** The top-N ranking of files by bug count is a direct operationalisation of Ostrand et al.'s finding. Engineering leaders can apply the 80/20 heuristic — the top quintile of the returned list covers most of the bug surface.

---

### Nagappan & Ball (2005) — *Use of Relative Code Churn Measures to Predict System Defect Density*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Code churn (lines changed per file over a release) combined with historical bug count is the most predictive feature pair in file-level defect models.

**How rw-git uses it:** `analyze_bug_hotspots` is commonly used alongside `analyze_code_volatility` (which measures churn) to produce a two-dimensional risk map: high-bug + high-churn files are the highest-priority targets.
