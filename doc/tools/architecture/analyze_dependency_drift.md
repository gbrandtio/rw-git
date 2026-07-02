# analyze_dependency_drift

## Business Logic

Answers: "Is our dependency management healthy?" Unpinned (floating) dependencies are a supply-chain and reproducibility risk i.e., `npm install` today may install a different transitive dependency than it did last month. Detects floating vs pinned versions across six ecosystems and flags missing lock files.

## Algorithm

**DependencyManifestParser** applies ecosystem-specific rules:

| Ecosystem | Manifest file | Pinned | Floating |
|---|---|---|---|
| Dart | `pubspec.yaml` | `1.2.3` | `^1.2.3`, `>=1.2.3` |
| npm / Node | `package.json` | `1.2.3` | `^`, `~`, `*`, `latest`, `>=` |
| Python | `requirements.txt` | `==1.2.3` | `>=`, `~=`, bare name |
| Go | `go.mod` | all entries | (Go modules are always hash-pinned) |
| Rust | `Cargo.toml` | `1.2.3` | `^`, `>=`, `*` |
| Ruby | `Gemfile` | `= 1.2.3` | `~>` (pessimistic), `>=` |

For each found manifest:
1. Parse all dependency entries with their version specifiers
2. Classify each as `pinned` or `floating`
3. Check for presence of the corresponding lock file (`pubspec.lock`, `package-lock.json` / `yarn.lock`, `Pipfile.lock` / `poetry.lock`, `go.sum`, `Cargo.lock`, `Gemfile.lock`)
4. Compute `pinned_ratio = pinned_count / total_count`
5. Risk classification: `none` (all pinned + lock file present), `low` (> 90% pinned), `medium` (70–90% pinned or missing lock file), `high` (< 70% pinned or no lock file with floating deps)

## Version Freshness Checking (opt-in)

Pinning and freshness are complementary risks: a dependency can be perfectly pinned and still be years out of date. By default `analyze_dependency_drift` performs no network access operating as a pure git-history tool. Passing `check_freshness: true` opts into an additional pass that compares each declared dependency version against the latest version published in its ecosystem's package registry:

| Ecosystem | Registry endpoint |
|---|---|
| Dart | `pub.dev/api/packages/<name>` |
| npm | `registry.npmjs.org/<name>/latest` |
| Python | `pypi.org/pypi/<name>/json` |
| Rust | `crates.io/api/v1/crates/<name>` |
| Go | `proxy.golang.org/<module>/@latest` |
| Ruby | `rubygems.org/api/v1/gems/<name>.json` |

Each declared version is classified relative to the latest available release as `current`, `patch_behind`, `minor_behind`, `major_behind`, or `unknown` (when either version can't be parsed as `MAJOR.MINOR.PATCH`, e.g. pre-release tags, `git:`/`path:` dependencies, or `any`). A failed lookup for one dependency (network error, 404, malformed response) never aborts the run but rather it is reported as `unknown` with an explanatory error, and every other dependency is still checked.

This network access is built on a generic, reusable HTTP layer (`RwHttpClient` under `lib/src/core/network/`) with a pluggable interceptor chain. A `RetryInterceptor` retries with exponential backoff, but only for a defined subset of transient conditions (HTTP 429/502/503/504) and transport-level failures (timeouts, connection errors) but never for non-retryable 4xx responses like 401/403/404, and it honors the `Retry-After` header when present.

## Academic Foundation

### Decan, Mens & Grosjean (2018) — *An Empirical Comparison of Dependency Network Evolution in Seven Software Packaging Ecosystems*

**Published in:** MSR, ACM

**Key claim:** Floating version constraints cause transitive dependency networks to evolve uncontrollably. A package that specifies `^1.0.0` may pull in `1.9.9` months later, changing behaviour without any change to the project's own code. The study found that floating constraints are the primary driver of unexplained build failures in npm, PyPI, and RubyGems projects.

**How rw-git uses it:** The floating vs pinned classification is the direct operationalisation of this finding. The `pinned_ratio` metric quantifies how exposed a project is to ecosystem churn.

---

### Ohm, Plate, Sykosch & Meier (2020) — *Backstabber's Knife Collection: A Review of Open Source Software Supply Chain Attacks*

**Published in:** DIMVA, Springer

**Key claim:** Floating dependencies are the primary attack vector in software supply chain compromises. An attacker who controls or compromises an upstream package can inject malicious code into projects that use floating constraints, without those projects making any change. All major supply chain attacks studied (event-stream, ua-parser-js, colors.js) exploited floating dependency constraints.

**How rw-git uses it:** The security dimension of the tool directly addresses this finding. A high `floating_count` is not just a reproducibility problem but also an active security exposure. The risk classification reflects both dimensions.

---

### *Reproducible Builds Project* (reproducible-builds.org, ongoing since 2013)

**Key claim:** A build is reproducible if it produces bit-for-bit identical output regardless of when or where it is built. Pinned dependencies with verified lock files (cryptographic hash verification) are a necessary condition for reproducible builds. Without them, the same source code may produce different binaries across builds, making security audits and forensic analysis unreliable.

**How rw-git uses it:** The lock file presence check is a direct reproducible-builds requirement. A project with pinned `pubspec.yaml` entries but no `pubspec.lock` is not reproducible because the lock file is what carries the cryptographic hashes used for verification.

---

### Raemaekers, van Deursen & Visser (2012) — *Measuring Dependency Freshness in Software Systems*

**Published in:** MSR, IEEE

**Key claim:** Dependency freshness (i.e., how close a project's declared versions are to the latest available release) is a significant predictor of security vulnerability exposure. Projects using old versions of dependencies have proportionally more known CVEs.

**How rw-git uses it:** Dependency freshness is the complementary concern to pinning: pinned but severely outdated dependencies are also a risk. The opt-in `check_freshness` pass described above directly operationalizes this finding since it compares each declared version against the latest available release per ecosystem and surfaces how far behind (patch/minor/major) each dependency is.
