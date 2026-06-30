# clone_repository

## Business Logic

Bring a remote codebase onto the local machine so that all analysis tools can process its full commit history without a network round-trip per command. A full clone is mandatory — shallow clones omit the ancestry required by SZZ, churn, and bus factor analyses.

## Algorithm

Executes `git clone <remote> <directory>`. The `--depth` flag is intentionally not used. The clone is the sole network operation; every subsequent tool call reads from the local object store.

## Academic Foundation

### Hassan (2008) — *The Road Ahead for Mining Software Repositories*

**Published in:** Frontiers of Software Maintenance (FoSM), IEEE

**Key claim:** The research value of a repository lies in its complete history. Partial histories (shallow clones, API-paginated responses) produce biased defect-prediction models and unreliable authorship attribution.

**How rw-git uses it:** Mandates `git clone` without `--depth`. SZZ blame traversal and bus factor computation require every ancestor commit to be present in the local object store.

### Śliwerski, Zimmermann & Zeller (2005) — *When Do Changes Induce Fixes?*

**Published in:** MSR Workshop, ACM

**Key claim:** Bug-introducing commits can only be identified by tracing deleted lines back through the full commit graph via `git blame`. Commits unreachable from the clone's HEAD are invisible to blame.

**How rw-git uses it:** Confirms the full-clone requirement — truncated history breaks the SZZ blame chain and silently drops bug introductions that predate the shallow boundary.
