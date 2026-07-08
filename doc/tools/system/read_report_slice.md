# read_report_slice

## Business Logic

Answers: "How do I get one piece of an offloaded report back without re-inflating my context?". When a tool's output exceeds the offload threshold, the full JSON is written to `.rw_git/reports/` and only a summary plus `preview` is returned inline ([ADR-0001](../../adr/0001-file-offloading-of-large-tool-outputs.md)). A naive "read the file" step would defeat the purpose of offloading by pulling the entire payload back into context. This tool lets a tool-only model page through a big report cheaply at one key path, one page of an array at a time ([ADR-0006](../../adr/0006-targeted-retrieval-of-offloaded-reports.md)).

## Algorithm

1. Normalise the `file` argument to an absolute path and verify it sits below an adjacent `.rw_git/reports` component pair. Checking the two components independently would accept unrelated paths such as `/home/user/reports/.rw_git/x.json`, so the pair is required to be adjacent. Reads are confined to the offload directory (path-traversal defence, see `doc/SECURITY.md`).
2. Parse the file as JSON.
3. Resolve the optional dot-separated `path` argument (e.g. `"findings"` or `"summary.totals"`) key by key. A wrong path returns the available keys as a `preview`, so the model can self-correct without another guess-read cycle.
4. If the resolved value is an array, return a bounded page with `offset` (default 0) and `limit` (default 50, max 500), together with `total_length`, so the model knows how much remains. Otherwise return the resolved value directly.

The `preview` field of the original offload summary (a `structure` map of top-level keys to type tags with array lengths) is what makes targeting possible: the model knows what to ask for before asking.

## Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| `file` | yes | Absolute path to a previously offloaded report file. Must reside within a `.rw_git/reports` directory. |
| `path` | no | Dot-separated key path into the JSON. Omit to operate on the root value. |
| `offset` | no | If the resolved value is an array, the start index (default 0). |
| `limit` | no | If the resolved value is an array, the maximum number of items to return (default 50, max 500). |

## Design Rationale

- **Deliberately simple path language.** Dot-separated keys and a single array page; filters and projections were rejected as scope creep because the report meta-tools ([ADR-0005](../../adr/0005-server-side-interpretation-and-report-meta-tools.md)) already answer most "what matters" questions inline.
- **Complementary to MCP Resources.** Standards-aware clients can fetch the same offloaded file whole via `resources/read` using the `resource_uri` in the offload summary; `read_report_slice` serves tool-only models that want a slice. Both paths are sandboxed to session-registered / `.rw_git/reports` files ([ADR-0006](../../adr/0006-targeted-retrieval-of-offloaded-reports.md)).
