# is_git_repository

## Business Logic

Answers: "Is this directory a valid, active git repository?" Surfaces four quick health signals — repository validity, current branch, uncommitted changes, last commit timestamp, and total commit count — as an instant onboarding dashboard before deeper analysis begins.

## Algorithm

Runs four git commands in sequence:

1. `git rev-parse --is-inside-work-tree` — exits 0 if inside a repository; non-zero otherwise
2. `git branch --show-current` — current branch name
3. `git status --porcelain` — non-empty output means uncommitted changes exist
4. `git log -1 --format=%aI` — ISO-8601 timestamp of the most recent commit
5. `git rev-list --count HEAD` — total number of commits reachable from HEAD

## Academic Foundation

### Nagappan, Murphy & Basili (2008) — *The Influence of Organizational Structure on Software Quality*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Repository age (approximated by total commit count) and recent activity (approximated by last commit date) are significant control variables when interpreting defect prediction results. A very new or very old repository requires different thresholds.

**How rw-git uses it:** `total_commits` and `last_commit_at` are exposed so that callers can contextualise subsequent metric outputs — a cyclomatic complexity of 15 means something different in a 50-commit prototype vs. a 50,000-commit production service.

### Bird, Nagappan, Murphy, Gall & Devanbu (2011) — *Don't Touch My Code! Examining the Effects of Ownership on Software Quality*

**Published in:** FSE, ACM

**Key claim:** Uncommitted changes represent in-progress work that is not yet captured by history-based metrics. Analyses run on a repository with many uncommitted changes may not reflect the current true state of the codebase.

**How rw-git uses it:** The `has_uncommitted_changes` flag warns callers that static analysis results may lag behind the working tree. This is surfaced as a caveat, not a blocker.
