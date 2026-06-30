# get_commits_between

## Business Logic

Enumerate every commit that falls between two version tags (or any two git refs). Provides the raw commit list that feeds changelog generation, release delta analysis, and blast radius computation.

## Algorithm

Executes `git log <ref1>..<ref2> --format=%H||%an||%aI||%s --no-merges` and parses each line into a structured `CommitDto` (hash, author name, ISO-8601 date, subject).

The `..` revision range selects commits reachable from `ref2` but not from `ref1` — the standard git inter-release slice.

## Academic Foundation

### Zimmermann, Zeller, Weissgerber & Diehl (2004) — *Mining Version Histories to Guide Software Changes*

**Published in:** ICSE, ACM/IEEE

**Key claim:** The commit log between two release markers is the primary data source for change impact analysis. Structured extraction of (hash, author, timestamp, message) tuples from this range enables co-change mining, churn computation, and SZZ attribution.

**How rw-git uses it:** All history tools that accept a tag range use `get_commits_between` (or an equivalent internal call) to produce the commit list they then process.

### Nagappan & Ball (2005) — *Use of Relative Code Churn Measures to Predict System Defect Density*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Relative churn is computed over a defined interval. Commits within that interval must be enumerated before file-level change counts can be aggregated.

**How rw-git uses it:** `analyze_release_delta` and `analyze_code_volatility` both enumerate commits in a range as the first step before aggregating per-file statistics.

### Forsgren, Humble & Kim (2018) — *Accelerate: The Science of Lean Software and DevOps*

**Published in:** IT Revolution Press

**Key claim:** Deployment Frequency — one of the four DORA metrics — is measured by counting release-tagged deploys per time period. Tag-bounded commit enumeration is the underlying data source.

**How rw-git uses it:** `analyze_commit_velocity` uses commit counts per interval to approximate deployment frequency, which `get_commits_between` makes available as a building block.
