# generate_changelog

## Business Logic

Answers: "What is a structured, human-readable summary of this release?" Automates changelog authoring by categorising commits as features, fixes, breaking changes, or other, and enriches each bug-fix commit with SZZ data showing the introducing commit it resolved — giving readers not just "what was fixed" but "how long this bug lived."

## Algorithm

**Conventional Commits parsing** + shared **RA-SZZ core** pipeline:

1. **Commit retrieval:** `git log <tag1>..<tag2> --format=%H||%an||%s`
2. **Conventional Commits parsing** — match each subject line against the pattern:
   ```
   ^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?(!)?: .+
   ```
   - `feat` → `features` bucket
   - `fix` → `fixes` bucket
   - `!:` or `BREAKING CHANGE:` in body → `breaking_changes` bucket
   - Everything else → `other` bucket
3. **RA-SZZ enrichment** — each commit in the `fixes` bucket is traced to its introducing commits through the package's single SZZ implementation (`SzzAlgorithm.traceFixCommit`), the same MA-SZZ + RA-SZZ pipeline behind `analyze_bug_hotspots` and `find_bugs_by_developer` (see `find_bugs_by_developer.md` for the phase description). Each fix entry receives a `bug_introducing_commits` array whose entries carry `introducing_commit`, `introduced_date`, and `days_bug_lived` (fractional days from introduction to fix — the SZZ bug lifetime)
4. **Changed files per commit:** `git show --name-only --format= <hash>` for file-level context
5. Return structured object with four buckets and enriched metadata

## Academic Foundation

### *Conventional Commits 1.0.0 Specification* (2019)

**Published at:** conventionalcommits.org — community-driven specification

**Key claim:** Structured commit messages that follow a typed prefix convention (`feat:`, `fix:`, `BREAKING CHANGE:`) make changelogs, release notes, and semantic version bumps automatable. The specification is aligned with SemVer: `feat` → MINOR, `fix` → PATCH, `BREAKING CHANGE` → MAJOR.

**How rw-git uses it:** The changelog categories and the regex pattern are a direct implementation of the Conventional Commits specification. The parser extracts type, scope, and breaking-change flag from each subject line.

---

### Śliwerski, Zimmermann & Zeller (2005) — *When Do Changes Induce Fixes?*

**Published in:** MSR Workshop, ACM

**Key claim:** Bug-fix commits can be linked back to the commit that introduced the defect. This introducing commit provides temporal context: when the bug was born, how long it survived, and who introduced it.

**How rw-git uses it:** The SZZ enrichment step adds `introducing_commit`, `introduced_date`, and `days_bug_lived` to every fix-type changelog entry. This transforms a bare "fixed X" entry into "fixed X, which was introduced 47 days ago in commit abc123f" — a materially more informative changelog.

---

### Hindle, Barr, Su, Gabel & Devanbu (2012) — *On the Naturalness of Software*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Commit messages follow predictable linguistic patterns and can be reliably classified by type using regex or n-gram models. Conventional Commits is a formalisation of the natural typing patterns that developers already use informally.

**How rw-git uses it:** The Conventional Commits regex works reliably in practice because commit messages are "natural" (high n-gram repetition), making simple regex classification sufficient — a full ML classifier is not necessary for this task.

---

### da Costa, McIntosh, Shang, Kulesza, Coelho & Hassan (2017) — *Evaluating the accuracy of SZZ*

**Published in:** ICSME, IEEE

**Key claim:** MA-SZZ (whitespace-filtered) produces more reliable fix-to-introducing-commit linkages. Using the improved variant ensures that the `introducing_commit` field in changelog entries is accurate.

**How rw-git uses it:** The enrichment delegates to the shared `SzzAlgorithm` core, so the changelog inherits MA-SZZ whitespace filtering (`-w --ignore-blank-lines`) and the "days bug lived" metric is not inflated by whitespace-only false positives.

---

### Neto, Brito, David, Cogo, Leite, Murta & Coelho (2018) — *The Impact of Refactoring Changes on the SZZ Algorithm*

**Published in:** SANER, IEEE

**Key claim:** Excluding refactoring changes from SZZ attribution removes a further 10–20% of false positives: code that merely moved is not a bug introduction.

**How rw-git uses it:** Because the enrichment runs through the shared RA-SZZ core, a changelog entry never blames a refactoring commit as a bug origin — the moved-line and refactoring-commit filters (see `find_bugs_by_developer.md`) apply identically here.
