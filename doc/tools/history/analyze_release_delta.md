# analyze_release_delta

## Business Logic

Answers: "What changed between version X and version Y, and how risky was that change?". Provides a structured release brief: commit count, aggregate line delta, active contributor count, top-touched files, bug introductions within the delta, and blast radius. Used to populate release notes, inform go/no-go decisions, and satisfy audit requirements.

## Algorithm

All sub-analyses run in parallel across Dart Isolates:

1. **Commit enumeration:** `git log <tag1>..<tag2> --format=%H||%an||%aI||%s --no-merges` → structured commit list.
2. **Aggregate delta:** `git diff --shortstat <tag1> <tag2>` → total insertions, deletions, files changed.
3. **Per-file touch frequency:** `git log --name-only <tag1>..<tag2>` → file touch count map → top 10 most-modified files.
4. **Active contributors:** unique author names in the commit range.
5. **Bug introductions (SZZ):** `BugHotspotsHeuristic` scoped to the commit range → bug-introducing commits and affected files within the delta.
6. **Blast radius:** number of unique files touched in the range as a proxy for change surface area.

## Academic Foundation

### Hassan & Holt (2004) — *Predicting Change Propagation in Software Systems*

**Published in:** WCRE, IEEE

**Key claim:** Release-scoped change analysis studying what changed between two release tags is the most tractable unit of study for change propagation and impact prediction. Inter-release change deltas are more actionable than commit-by-commit analysis because they represent a coherent unit of work.

**How rw-git uses it:** The tag-bounded scope (`<tag1>..<tag2>`) is the direct application of this principle. All sub-analyses are scoped to the release interval.

---

### Zimmermann, Zeller, Weissgerber & Diehl (2004) — *Mining Version Histories to Guide Software Changes*

**Published in:** ICSE, ACM/IEEE

**Key claim:** File touch frequency within a release interval is a reliable signal for identifying the "hottest" areas of change. Files touched most frequently within a release are also the most likely to contain integration problems.

**How rw-git uses it:** The top-10 most-modified files list is a direct implementation of this metric. It surfaces the blast radius centre of the release.

---

### Śliwerski, Zimmermann & Zeller (2005) — *When Do Changes Induce Fixes?*

**Published in:** MSR Workshop, ACM

**Key claim:** Bug introductions can be identified from the commit history. Knowing how many bugs were introduced within a specific release interval gives a quality signal for that release.

**How rw-git uses it:** The SZZ-derived `bug_introductions` count in the delta output gives engineering leaders a quantitative quality signal alongside the change volume metrics. Meaning that it doesn't simply answer "how much changed" but "how many bugs were introduced."

---

### Nagappan & Ball (2005) — *Use of Relative Code Churn Measures to Predict System Defect Density*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Total lines changed in a release interval is predictive of post-release defect density. Larger releases have proportionally more defects.

**How rw-git uses it:** The `total_insertions + total_deletions` aggregate from `git diff --shortstat` is a release-level churn metric that contextualises the bug introduction count. A large churn count with few SZZ-attributed bugs is a positive signal; a small churn with many bugs is alarming.
