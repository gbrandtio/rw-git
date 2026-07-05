# 0010 — Interpretation thresholds: code is the source of truth, guide follows

- **Status**: Accepted
- **Date**: 2026-07-02
- **Deciders**: rw_git maintainers
- **Related**: [ADR-0005](0005-server-side-interpretation-and-report-meta-tools.md)

## Context

The severity bands and compound-risk rules introduced by ADR-0005 exist in two
places:

1. **Executable form** — the classifiers under
   `lib/src/intelligence/interpretation/` (and
   `compound_finding_correlator.dart`), which the report meta-tools apply.
2. **Prose form** — [`doc/INTERPRETATION_GUIDE.md`](../INTERPRETATION_GUIDE.md),
   the reference for humans and for models that call the raw tools directly.

Nothing so far defined which copy wins when they disagree, or what a
contributor must do when changing a threshold (e.g. moving the bus-factor
Critical band from > 50% to > 60%). Silent drift between the two copies is the
worst outcome: the report tools would classify one way while raw-tool users
classify another, producing contradictory findings from the same repository.

The *Quality* business rule in `AGENTS.md` additionally requires that
algorithms and thresholds be backed by research. Thus, a threshold change is a
domain-knowledge change, and must be attributed to research.

## Decision

- **The classifier code is the single source of truth.** If
  `doc/INTERPRETATION_GUIDE.md` and `lib/src/intelligence/interpretation/`
  disagree, the code is authoritative and the guide is the bug.
- **Threshold changes follow a fixed process.** A change to any band or
  compound-risk rule must, in the same commit:
  1. change the classifier (or correlator) and its unit tests;
  2. update the matching band in `doc/INTERPRETATION_GUIDE.md`;
  3. state the justification, deriving from an academic source or an explicit empirical rationale, in the guide entry and the `CHANGELOG.md` entry.
- **New or changed thresholds are expressed as named constants**, not inline
  literals, per the *Constants and Defaults* guardrail, so a change is a
  one-site edit the guide can reference by name. Existing inline literals in
  the classifiers are migrated to named constants whenever the surrounding
  band is next touched.
- The guide keeps its existing header note directing readers to the
  implementation directory, so the authority relationship is discoverable from
  the prose side as well.

## Consequences

- **Positive**: report meta-tools and raw-tool users can no longer diverge
  silently. A threshold change that skips the guide is a review-visible
  process violation with a defined resolution (code wins).
- **Positive**: every band carries a justification trail, preserving the
  research-backed quality rule as thresholds evolve.
- **Negative / trade-off**: prose and code still require manual
  synchronisation; the process makes drift detectable and attributable rather
  than impossible. Generating the guide from the classifier constants was
  considered and rejected for now. The prose carries context (rationale,
  caveats, examples) that constants cannot express.
