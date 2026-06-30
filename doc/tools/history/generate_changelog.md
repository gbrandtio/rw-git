# generate_changelog

## Business Logic

Answers: "What is a structured, human-readable summary of this release?" Automates changelog authoring by categorising commits as features, fixes, breaking changes, or other, and enriches each bug-fix commit with SZZ data showing the introducing commit it resolved — giving readers not just "what was fixed" but "how long this bug lived."

## Algorithm

**ComplianceScanner** + **BugHotspotsHeuristic** pipeline:

1. **Commit retrieval:** `git log <tag1>..<tag2> --format=%H||%ae||%an||%aI||%s --no-merges`
2. **Conventional Commits parsing** — match each subject line against the pattern:
   ```
   ^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?(!)?: .+
   ```
   - `feat` → `features` bucket
   - `fix` → `fixes` bucket
   - `!:` or `BREAKING CHANGE:` in body → `breaking_changes` bucket
   - Everything else → `other` bucket
3. **SZZ enrichment** — for each commit in the `fixes` bucket, run SZZ to identify the introducing commit it resolved:
   - Attach `introduced_in_commit`, `introduced_date`, and `days_bug_lived` to the fix entry
4. **Changed files per commit:** `git diff-tree --no-commit-id -r --name-only <hash>` for file-level context
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

**How rw-git uses it:** The SZZ enrichment step adds `introduced_in_commit` and `days_bug_lived` to every fix-type changelog entry. This transforms a bare "fixed X" entry into "fixed X, which was introduced 47 days ago in commit abc123f" — a materially more informative changelog.

---

### Hindle, Barr, Su, Gabel & Devanbu (2012) — *On the Naturalness of Software*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Commit messages follow predictable linguistic patterns and can be reliably classified by type using regex or n-gram models. Conventional Commits is a formalisation of the natural typing patterns that developers already use informally.

**How rw-git uses it:** The Conventional Commits regex works reliably in practice because commit messages are "natural" (high n-gram repetition), making simple regex classification sufficient — a full ML classifier is not necessary for this task.

---

### da Costa, McIntosh, Shang, Kulesza, Coelho & Hassan (2017) — *Evaluating the accuracy of SZZ*

**Published in:** ICSME, IEEE

**Key claim:** MA-SZZ (whitespace-filtered) produces more reliable fix-to-introducing-commit linkages. Using the improved variant ensures that the `introduced_in_commit` field in changelog entries is accurate.

**How rw-git uses it:** The SZZ enrichment step uses MA-SZZ (`-w --ignore-blank-lines`) so that the "days bug lived" metric in the changelog is not inflated by whitespace-only false positives.
