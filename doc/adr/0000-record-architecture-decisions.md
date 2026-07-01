# 0000 — Record architecture decisions

- **Status**: Accepted
- **Date**: 2026-07-01
- **Deciders**: rw_git maintainers

## Context

`rw_git` has accumulated several non-obvious architectural decisions whose
rationale lived only in commit messages, `CHANGELOG.md` entries, and code
comments. New contributors (and AI agents bound by `AGENTS.md`) must not "guess
the architecture, security, or performance patterns of this project." Scattered
rationale makes that guardrail hard to honour: the *what* is in the code, but
the *why* is easy to lose.

We need a durable, discoverable place for the reasoning behind significant
decisions — one that is version-controlled next to the code, survives
refactors, and is cheap to add to.

## Decision

We keep **Architecture Decision Records** under `doc/adr/`, one Markdown file
per decision, following a lightweight [MADR](https://adr.github.io/madr/)-style
template with the sections: *Context*, *Decision*, *Consequences*, and — where a
decision introduces a structure — an *Architecture* section.

Records are numbered and immutable once `Accepted`. A changed decision is
captured by a **new** ADR that supersedes the old one; the superseded record is
marked, not deleted, so the history of reasoning is preserved.

ADRs are secondary to the normative documents named in `AGENTS.md`. They explain
and cross-link those rules; they do not override them.

## Consequences

- **Positive**: the rationale behind offloading, decorator composition,
  isolate usage, and the interpretation layer is now discoverable in one place.
  Reviewers can check a change against a recorded decision rather than re-deriving
  intent.
- **Positive**: superseding-not-editing preserves an audit trail of how the
  design evolved.
- **Negative / cost**: every significant decision now carries the small overhead
  of writing a record. This is intentional friction: if a decision is not worth a
  paragraph, it is probably not architecturally significant.
- **Neutral**: ADRs are documentation only. They do not change runtime behaviour
  and are not part of the published package's API surface.
