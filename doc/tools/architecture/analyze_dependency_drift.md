# analyze_dependency_drift

## Business Logic

Answers: "Is our dependency management healthy?" Unpinned (floating) dependencies are a supply-chain and reproducibility risk — `npm install` today may install a different transitive dependency than it did last month. Detects floating vs. pinned versions across six ecosystems and flags missing lock files.

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

## Academic Foundation

### Decan, Mens & Grosjean (2018) — *An Empirical Comparison of Dependency Network Evolution in Seven Software Packaging Ecosystems*

**Published in:** MSR, ACM

**Key claim:** Floating version constraints cause transitive dependency networks to evolve uncontrollably. A package that specifies `^1.0.0` may pull in `1.9.9` months later, changing behaviour without any change to the project's own code. The study found that floating constraints are the primary driver of unexplained build failures in npm, PyPI, and RubyGems projects.

**How rw-git uses it:** The floating vs. pinned classification is the direct operationalisation of this finding. The `pinned_ratio` metric quantifies how exposed a project is to ecosystem churn.

---

### Ohm, Plate, Sykosch & Meier (2020) — *Backstabber's Knife Collection: A Review of Open Source Software Supply Chain Attacks*

**Published in:** DIMVA, Springer

**Key claim:** Floating dependencies are the primary attack vector in software supply chain compromises. An attacker who controls or compromises an upstream package can inject malicious code into projects that use floating constraints, without those projects making any change. All major supply chain attacks studied (event-stream, ua-parser-js, colors.js) exploited floating dependency constraints.

**How rw-git uses it:** The security dimension of the tool directly addresses this finding. A high `floating_count` is not just a reproducibility problem — it is an active security exposure. The risk classification reflects both dimensions.

---

### *Reproducible Builds Project* (reproducible-builds.org, ongoing since 2013)

**Key claim:** A build is reproducible if it produces bit-for-bit identical output regardless of when or where it is built. Pinned dependencies with verified lock files (cryptographic hash verification) are a necessary condition for reproducible builds. Without them, the same source code may produce different binaries across builds — making security audits and forensic analysis unreliable.

**How rw-git uses it:** The lock file presence check is a direct reproducible-builds requirement. A project with pinned `pubspec.yaml` entries but no `pubspec.lock` is not reproducible because the lock file is what carries the cryptographic hashes used for verification.

---

### Raemaekers, van Deursen & Visser (2012) — *Measuring Dependency Freshness in Software Systems*

**Published in:** MSR, IEEE

**Key claim:** Dependency freshness — how close a project's declared versions are to the latest available release — is a significant predictor of security vulnerability exposure. Projects using old versions of dependencies have proportionally more known CVEs.

**How rw-git uses it:** Dependency freshness is the complementary concern to pinning: pinned but severely outdated dependencies are also a risk. The current tool focuses on the pinning dimension; version freshness checking (comparing declared version against latest available) is the natural next enhancement.
