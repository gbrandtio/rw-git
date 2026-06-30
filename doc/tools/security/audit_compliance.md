# audit_compliance

## Business Logic

Answers: "Does our commit history meet our governance policies?" Scans for unsigned commits, empty messages, commits from unrecognised authors, and non-Conventional Commits format — the core compliance requirements in regulated industries (SOC 2, ISO 27001, financial services, government contracting). Enables automated policy enforcement without a pre-receive hook.

## Algorithm

**ComplianceScanner** runs a single `git log` pass:

```
git log --format=%H||%G?||%ae||%an||%aI||%s [--since=<date>] [--until=<date>]
```

Field meanings:
- `%G?` — GPG signature status: `G` (good), `B` (bad), `U` (unknown key), `N` (no signature), `E` (expired key), `X` (expired signature), `Y` (expired key good sig), `R` (revoked key)
- `%ae` — author email
- `%s` — commit subject (first line of message)

Four violation checks per commit:

**1. Unsigned commits:**
`%G?` is not `G` (good) and not `E` (expired — still cryptographically signed). Reports: commit hash, author name, email, date, GPG status code.

**2. Empty messages:**
Subject (`%s`) is empty or contains only whitespace. Reports: commit hash, author, date.

**3. Unrecognised authors:**
Author email (`%ae`) is not in the `allowedEmails` list (if provided). Used for contractor access audits and enforcing that only known team members commit to a repository.

**4. Non-Conventional Commits format:**
Subject does not match:
```
^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?(!)?: .+
```
Reports: commit hash, author, date, actual subject.

Additionally exposes `parseConventionalCommits()` for use by `generate_changelog` — same parser, reused for structured changelog generation.

## Academic Foundation

### *Conventional Commits 1.0.0 Specification* (2019)

**Published at:** conventionalcommits.org

**Key claim:** A lightweight convention on top of commit messages enables automated changelog generation, semantic version bumping, and change categorisation. The specification is aligned with SemVer: `feat` → MINOR version bump; `fix` → PATCH bump; `BREAKING CHANGE:` in footer → MAJOR bump.

**How rw-git uses it:** The regex pattern is a direct implementation of the Conventional Commits spec. The violation report identifies which commits deviate from the convention, enabling retrospective remediation or pre-receive hook enforcement.

---

### NIST SP 800-218 (2022) — *Secure Software Development Framework (SSDF) Version 1.1*

**Published by:** National Institute of Standards and Technology

**Key claim:** SSDF Practice PO.3.2 requires that all code changes be attributable to an authenticated identity (code signing). Practice PS.1.1 requires audit trail integrity — every code change must be traceable to an authorised developer. GPG-signed commits are the git-native mechanism for both requirements.

**How rw-git uses it:** The unsigned commit check directly targets SSDF PO.3.2 and PS.1.1. The `allowedEmails` check targets PS.1.1 by verifying that committing authors are members of the authorised developer set.

---

### ISO/IEC 27001:2022 — Annex A, Control A.8.15 (Logging)

**Key claim:** Information security logs must be protected against tampering and unauthorised modification. For source code repositories, cryptographic commit signatures provide tamper evidence — a backdated or injected commit is detectable because it cannot carry a valid GPG signature from the claimed time.

**How rw-git uses it:** GPG signature verification (`%G?` = `G`) is the git implementation of ISO 27001 A.8.15 tamper evidence. The audit report gives compliance teams the data to demonstrate signature coverage.

---

### PCI DSS v4.0, Requirement 10 (Audit Logs)

**Published by:** PCI Security Standards Council (2022)

**Key claim:** Payment card industry compliance requires that all access to and modifications of cardholder data environments be logged with: who performed the action, what was changed, and when. For code repositories that are part of a CDE, commit author identity and timestamp must be verifiable.

**How rw-git uses it:** The `allowedEmails` check and the unsigned commit report together satisfy Requirement 10 for code repositories: only known authors (allowedEmails) with signed commits (GPG verification) produce an auditable, tamper-evident commit trail.

---

### Bird, Nagappan, Murphy, Gall & Devanbu (2015) — *The Art and Science of Analyzing Software Data*

**Published in:** Morgan Kaufmann

**Key claim:** Structured commit practices (meaningful messages, conventional formats, atomic commits) correlate with lower defect density and better release predictability. Projects with clear commit hygiene practices have more reliable release timelines.

**How rw-git uses it:** The Conventional Commits compliance check is not only a governance requirement — it is a quality signal. Projects with high CC compliance tend to produce cleaner changelogs, more reliable semantic version bumps, and less confusion during incident postmortems.
