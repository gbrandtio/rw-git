# fetch_tags

## Business Logic

Retrieve all release tags from the remote so that version-boundary tools can identify where one release ends and the next begins. Without tags, changelog generation, release delta analysis, and between-tag statistics have no anchors.

## Algorithm

1. `git fetch --tags` — pull all tag objects from the remote into the local object store
2. `git tag --list` — enumerate all tag names in lexicographic order

Returns an ordered list of tag name strings. No filtering or sorting by semver is applied; the caller is responsible for selecting the relevant range.

## Academic Foundation

### Zimmermann, Zeller, Weissgerber & Diehl (2004) — *Mining Version Histories to Guide Software Changes*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Release boundaries (identified by tags) are the natural unit of inter-release change analysis. Change impact prediction and co-change mining should be computed within release intervals, not across the entire history uniformly.

**How rw-git uses it:** `fetch_tags` provides the tag list that `get_commits_between`, `analyze_release_delta`, `generate_changelog`, and `get_stats` use to define release intervals for their analyses.

### Hassan & Holt (2004) — *Predicting Change Propagation in Software Systems*

**Published in:** WCRE, IEEE

**Key claim:** Studying how changes propagate across a system is most tractable when scoped to a release interval. Tags delimit the scope.

**How rw-git uses it:** Release-scoped blast radius and change propagation analysis in `analyze_release_delta` depend on tag-bounded commit ranges fetched by this tool.
