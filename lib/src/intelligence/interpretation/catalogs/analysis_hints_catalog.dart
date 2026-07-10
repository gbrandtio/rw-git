/// ----------------------------------------------------------------------------
/// tool_hints_catalog.dart
/// ----------------------------------------------------------------------------
/// One [ToolHints] entry per research-grounded MCP tool, keyed by the tool's
/// registered name. Distilled from `doc/tools/`; kept in sync with those docs
/// by `test/intelligence/interpretation/tool_hints_catalog_test.dart`.
///
/// Every string here is deliberately outcome-facing: it explains what a
/// result means, why the literature says it matters, and what to do next —
/// never how the tool arrives at the number. A calling model, especially a
/// small or local one with no spare tokens to look up the underlying paper,
/// should be able to read one of these strings and act on the result without
/// ever needing to know the formula, weighting, or heuristic behind it.
///
/// Coverage is deliberate: core git tools (clone/checkout/init/...) and pure
/// retrieval tools (`get_rw_git_documentation`, `read_report_slice`) have no
/// entry, since they carry no academic basis to cite — see the "Core git
/// tools and system tools get no hints" decision this catalog implements.
/// Report meta-tools are also absent here; their hints are aggregated at the
/// [ReportPayload] level from the catalog entries of the analyses they run.
library;

import '../models/tool_hints.dart';
import '../models/analysis_type.dart';

const Map<AnalysisType, ToolHints> analysisHintsCatalog = {
  // ---------------------------------------------------------------- Architecture
  AnalysisType.busFactor: ToolHints(
    interpretation: [
      'You must explain the bus factor algorithm (Avelino et al. 2016) used '
          'to calculate this risk. The algorithm sorts authors by their total '
          'commit volume and adds them up until their combined contributions '
          'cross a coverage threshold (typically 50%). If it takes only one '
          'or two authors to reach this threshold, the project has a '
          'critically low bus factor, meaning its continuity depends on a '
          'single point of failure. In practice, this often traces back to '
          'an organizational boundary (Conway 1968). When interpreting these '
          'results, explicitly guide the user through this calculation: show '
          'how the top contributor\'s share dominates the codebase and '
          'explain that a lower coverage threshold flags modest concentration '
          'while a higher one flags unambiguous risk. Your report must '
          'narrate *why* this numeric imbalance creates a knowledge silo.',
    ],
    caveats: [
      'Counting commits is a workable but blunt way to estimate who '
          'understands a project — it treats a one-line typo fix and a '
          'sweeping rewrite as equally informative. Line-level ownership '
          'gives a sharper picture of who actually holds the knowledge '
          'behind specific code (Ferreira et al. 2017); reach for '
          'analyze_file_ownership when a specific file or module needs that '
          'level of confidence rather than a repository-wide estimate.',
    ],
    pairWith: [
      'Pair with the concentration signal analyze_commit_velocity reports '
          'through its Gini coefficient (Gini 1912) for a second, '
          'independent read on the same continuity risk, and with '
          'analyze_file_ownership to see exactly which files would be left '
          'without a knowledgeable maintainer if the concentrated '
          'contributor left.',
    ],
  ),

  AnalysisType.logicalCoupling: ToolHints(
    interpretation: [
      'Explain the algorithmic basis of logical coupling: this tool measures '
          'how often two files co-change in the same commit relative to how '
          'often they change at all. When two files co-change more than 60% '
          'of the time, that is strong statistical evidence they are '
          'entangled in practice even if no explicit dependency exists in '
          'the code (Gall et al. 1998; Zimmermann et al. 2004). You must '
          'interpret these co-change ratios for the user: a 30–60% rate is '
          'a moderate warning, while >60% means a change to one file quietly '
          'forces a change to the other. Explain that files this tightly '
          'coupled are prime targets for architectural refactoring — such as '
          'merging them or extracting a shared interface — to make the hidden '
          'dependency explicit.',
    ],
    caveats: [
      'Among the many signals used to predict where bugs will appear next, '
          'logical coupling measured this way is one of the strongest — in '
          'some studies a better predictor than the code\'s structural '
          'complexity or its raw size (D\'Ambros et al. 2009). A cluster of '
          'several files that all co-change with high confidence is the '
          'commit-history fingerprint of the Shotgun Surgery smell: a '
          'single conceptual change that has to be manually threaded '
          'through many places every time (Fowler 1999).',
    ],
    pairWith: [
      'Pair with analyze_bug_hotspots — a tightly coupled cluster with no '
          'bug history yet is a leading indicator of future defects, not '
          'confirmation that anything has already gone wrong.',
    ],
  ),

  AnalysisType.architectureDrift: ToolHints(
    interpretation: [
      'You must explicitly break down the algorithmic definitions of the '
          'three architectural drift patterns (Garcia et al. 2009). First, '
          'a God Component algorithm identifies a layer dominating the majority '
          'of drift commits, signaling it is becoming the central bottleneck. '
          'Second, a Hub-Like Dependency flags a layer entangled with an '
          'anomalous number of other layers (calculated via co-change edges) '
          'rather than being isolated. Third, Scattered Functionality '
          'identifies single commits that span three or more distinct layers '
          'simultaneously, violating layer encapsulation. Guide the user '
          'through the two repo-level ratios: coupling_ratio (commits crossing '
          'layer boundaries / total commits) and coupling_density (fraction '
          'of all possible layer-pairs that co-change). Explain that a ratio '
          '>15% means boundaries are failing to contain change, and a density '
          '>0.5 means the system acts as an entangled monolith rather than '
          'independent layers.',
    ],
    caveats: [
      'The density figure this tool reports is a practical estimate of how '
          'entangled the layers are with each other, not a rigorously '
          'certified network-science measurement — treat it as directionally '
          'informative rather than exact. Even as an estimate, though, how '
          'entangled a system\'s modules are with one another is one of the '
          'strongest known predictors of how expensive that system will be '
          'to maintain going forward, especially as it grows (Lippert & '
          'Roock 2006).',
    ],
    pairWith: [
      'Pair with analyze_logical_coupling to see the file-level detail '
          'behind any layer-level smell this tool reports — the layer-wide '
          'signal is usually made up of a smaller number of specific file '
          'pairs worth looking at directly.',
    ],
  ),

  AnalysisType.dependencyDrift: ToolHints(
    interpretation: [
      'A dependency risk of "none" describes a project where every '
          'dependency is pinned to an exact version and a lock file is '
          'present — the build a developer runs today is the same build '
          'anyone else will get. Risk climbs as that discipline erodes: '
          '"low" still has the large majority of dependencies pinned, '
          '"medium" means either a meaningful minority float freely or no '
          'lock file exists to guarantee reproducibility, and "high" means '
          'most dependencies are unpinned or there is no lock file at all '
          'alongside floating versions. Separately, how far behind a '
          'dependency\'s available updates a project has fallen predicts '
          'its exposure to known vulnerabilities: a major version behind is '
          'treated as critical exposure, a minor version behind as '
          'moderate, and a patch version behind as low (Raemaekers et al. '
          '2012) — pinning and freshness are two different risks, and a '
          'perfectly pinned dependency can still be years out of date.',
    ],
    caveats: [
      'Floating version constraints are the documented mechanism behind '
          'some of the most damaging real-world software supply-chain '
          'attacks, including the event-stream and ua-parser-js incidents, '
          'because they let a compromised update reach every downstream '
          'consumer automatically instead of only those who explicitly '
          'upgrade (Decan et al. 2018; Ohm et al. 2020).',
    ],
    pairWith: [
      'Pair with detect_secrets_in_commits and audit_compliance for a '
          'complete picture of supply-chain risk — pinning discipline, '
          'credential hygiene, and process compliance are usually reviewed '
          'together, not in isolation.',
    ],
  ),

  AnalysisType.fileOwnership: ToolHints(
    interpretation: [
      'The share of a file\'s history contributed by people who each '
          'touched it only rarely is one of the strongest known predictors '
          'of defects appearing in that file after release (Bird et al. '
          '2011) — a file with many such minor contributors and no strong '
          'primary owner is inherently riskier than one a small stable '
          'group maintains closely. Separately, a developer\'s working '
          'familiarity with code they are not actively touching fades '
          'quickly: roughly half of it is gone within about a year of their '
          'last commit to that file (Fritz et al. 2010), so an owner who '
          'has been inactive on a file for ninety days or more should be '
          'treated as unreliable even while their name is still attached to '
          'it.',
    ],
    caveats: [
      'When the person a file\'s history says is currently doing the work '
          'is not the same person officially listed as its owner, that '
          'mismatch usually means a team or organizational boundary shifted '
          'without anyone updating the ownership record to match (Conway '
          '1968) — it is a signal to fix the record, not necessarily a '
          'quality problem with the code itself. Recency-weighted commit '
          'history is a genuinely useful proxy for who understands a file '
          'best, but it remains a proxy, not a certainty (Mockus & '
          'Herbsleb 2002).',
    ],
    pairWith: [
      'Pair with analyze_bus_factor — a file with no reliable current owner '
          'that also sits in a project with a low overall bus factor '
          'represents the single highest-priority knowledge risk in the '
          'codebase.',
      'Pair with analyze_bug_hotspots: a file with three or more minor '
          'contributors (each under 5% of its changes) that is also a bug '
          'hotspot combines Bird et al.\'s strongest ownership-structure '
          'defect signal with SZZ\'s strongest history signal — the report '
          'meta-tools escalate exactly this join, and it deserves the same '
          'priority when reading the raw outputs side by side.',
    ],
  ),

  AnalysisType.refactoring: ToolHints(
    interpretation: [
      'The overwhelming majority of refactoring activity in real projects '
          'happens mixed into the same commit as feature work or a bug fix, '
          'rather than as its own isolated change (Murphy-Hill et al. '
          '2009) — and that mixed pattern is exactly the hardest kind of '
          'commit to review carefully or safely revert, since undoing it '
          'means untangling structural change from behavioral change after '
          'the fact. It is also worth treating refactoring as something to '
          'verify rather than assume helps: refactoring on its own does not '
          'reliably make code more maintainable unless it is paired with '
          'genuinely removing smells or improving test coverage (Palomba et '
          'al. 2018) — running analyze_code_quality before and after a '
          'refactor is how to confirm it actually helped in this specific '
          'codebase rather than taking the intent on faith.',
    ],
    caveats: [
      'This tool\'s refactor detection is a lighter-weight approximation of '
          'dedicated AST-diffing tools that reach very high precision and '
          'recall on this exact task (Tsantalis et al. 2018; 2020) — it '
          'trades some of that recall for speed and language-agnostic '
          'simplicity, so the absence of a detected refactor in a commit '
          'does not prove one didn\'t happen.',
    ],
    pairWith: [
      'When analyze_code_volatility or analyze_bug_hotspots flags a file '
          'that this tool shows was recently renamed or refactored, treat '
          'that flag as one severity band less alarming than it would '
          'otherwise be — churn caused by intentional restructuring is a '
          'different, lower-risk signal than churn caused by recurring '
          'defects (the RA-SZZ insight, Neto et al. 2018).',
    ],
  ),

  // -------------------------------------------------------------------- History
  AnalysisType.bugHotspots: ToolHints(
    interpretation: [
      'Defects in a codebase are not spread evenly: a consistent, '
          'stable pattern across many studied projects and releases is that '
          'roughly a fifth of files account for roughly four-fifths of all '
          'defects (Ostrand et al. 2004). You must interpret these hotspots '
          'deeply by explaining the SZZ algorithm (Sliwerski, Zimmermann, '
          'and Zeller 2005) that produced them. SZZ traces backwards from '
          'a bug-fix commit (identified via issue IDs or keywords like '
          '"fix" in the message) to the lines that were changed, and uses '
          'git blame to find the original commit that introduced those lines. '
          'By mapping these fault-introducing commits to files, we identify '
          'hotspots. Explain to the user that a file\'s history of past '
          'defects is the strongest available predictor of future defects, '
          'outperforming any single structural complexity metric '
          '(Zimmermann et al. 2007). When interpreting this data, guide '
          'the user to combine high historical bug count with high recent '
          'churn, as this is the most predictive pairing (Nagappan & Ball '
          '2005). If analyzing by author, you must explain that author '
          'identity correlates with defects due to module complexity, not '
          'individual skill — developers assigned to coupled, complex modules '
          'naturally accumulate higher bug counts (Zimmermann et al. 2007).',
    ],
    caveats: [
      'Automatically inferring which commit introduced a given bug — known '
          'in the literature as SZZ attribution — is an inherently noisy '
          'process — done naively it produces a false positive rate in the '
          'range of a quarter to two-fifths of attributions, mostly from '
          'whitespace changes and refactors being mistaken for the true '
          'fault-introducing change; this tool applies established '
          'filtering specifically designed to remove most of that SZZ '
          'noise before reporting a result (da Costa et al. 2017; Neto et '
          'al. 2018). Separately, seeing a bug that lived for '
          'weeks or months before being fixed is a normal part of software '
          'development, not an anomaly worth flagging on its own (Kim & '
          'Whitehead 2006). The "days bug lived" figure in the '
          'developer_bug_analysis section measures how long the inferred '
          'defect existed in the codebase before being fixed, not how '
          'quickly the developer who introduced or fixed it responded — it '
          'should never be read as a measurement of someone\'s speed or '
          'responsiveness. Before drawing any conclusion about a specific '
          'person from that section, cross-reference against the '
          'aggregate file hotspots — someone who happens to work in a '
          'high-churn, high-defect file will show an inflated count for '
          'reasons that have nothing to do with them personally.',
    ],
    pairWith: [
      'Pair with analyze_code_volatility to build a two-dimensional risk '
          'picture: a file that is high on both historical bug count and '
          'churn is the single highest-priority combination to address '
          'first.',
    ],
  ),

  AnalysisType.codeVolatility: ToolHints(
    interpretation: [
      'You must explain the underlying algorithm behind this volatility '
          'ranking. The algorithm multiplies total churn (number of changes) '
          'by the total number of unique authors who have touched the file. '
          'This explicitly captures two independent, separately validated '
          'signals. First, how often a file changes is a better defect '
          'predictor than its size, scaling non-linearly (a file changing '
          'twice as often carries more than twice the expected defect risk, '
          'Nagappan & Ball 2005). Second, the multiplier for unique authors '
          'captures the "too many cooks" effect (Weyuker, Ostrand & Bell '
          '2008): a file many authors coordinate around carries '
          'exponentially more risk than the same churn from one person, '
          'reflecting Conway\'s Law coordination overhead (Conway 1968). '
          'A file ranking high on this metric is one that is both changing '
          'frequently and being modified by many people simultaneously. '
          'In your report, explicitly break down these two factors and '
          'explain why their multiplication creates such a strong risk '
          'signal, guiding the user on whether to focus on reducing churn '
          'or assigning clearer ownership.',
    ],
    pairWith: [
      'Pair with analyze_bug_hotspots to tell latent risk from confirmed '
          'risk apart: a file high on volatility with no bug history yet is '
          'a warning sign worth watching, while a file elevated on both is '
          'a confirmed problem worth acting on now.',
    ],
  ),

  AnalysisType.commitVelocity: ToolHints(
    interpretation: [
      'When a project has no release tags to measure against directly, '
          'commit velocity is a reasonable stand-in for the Deployment '
          'Frequency metric that DORA research treats as a core indicator '
          'of engineering health (Forsgren, Humble & Kim 2018). A Gini '
          'coefficient above roughly 0.6 over the distribution of commits '
          'across contributors describes a team where a small number of '
          'people are producing almost all of the output — a knowledge '
          'silo risk independent of any single person\'s bus-factor exposure '
          '(Gini 1912). A period of activity that spikes well beyond what '
          'the project\'s normal variation would predict is the kind of '
          'statistical anomaly that industrial process-control practice '
          'treats as an early warning worth investigating, not noise to '
          'ignore (Shewhart 1924).',
    ],
    caveats: [
      'A meaningful share of commits — more than roughly 15% — landing '
          'outside normal working hours correlates with deadline pressure '
          'and with measurably higher defect density in the release that '
          'follows (Claes et al. 2018). A team\'s sustainable, even pace is '
          'a healthier signal than its peak velocity: a pattern of sharp '
          'spikes followed by troughs is the historical signature of crunch '
          'and burnout, not of genuine productivity (DeMarco & Lister '
          '1987).',
    ],
    pairWith: [
      'Pair with get_contributions_by_author to see whether elevated '
          'velocity concentration traces back to one specific person under '
          'pressure (crunch) or is spread structurally across the team '
          '(a silo).',
      'Pair with analyze_bug_hotspots when the burnout share is high: '
          'commits written outside regular working hours are measurably '
          'buggier (Eyolfson, Tan & Lam 2011), so sustained off-hours work '
          'co-occurring with active bug hotspots means the delivery-health '
          'problem and the defect problem are reinforcing each other.',
    ],
  ),

  AnalysisType.releaseDelta: ToolHints(
    interpretation: [
      'A release with a large amount of changed code but few bugs '
          'attributed to it by history is a genuinely healthy signal — the '
          'team shipped a lot without breaking much. A release with only a '
          'small amount of change but a disproportionate number of '
          'associated bugs is the more alarming pattern, since it suggests '
          'the changes that did happen were unusually defect-prone rather '
          'than merely voluminous; total code changed is itself a known '
          'predictor of post-release defect density (Nagappan & Ball 2005). '
          'Looking at change and defects within the scope of a single '
          'release is one of the most tractable ways to reason about how a '
          'change propagates through a system, because it bounds the '
          'analysis to a period with a clear beginning and end (Hassan & '
          'Holt 2004).',
    ],
    caveats: [
      'The bug counts this tool reports are produced by the same '
          'commit-attribution pipeline used across the history tools, and '
          'inherit its accuracy characteristics — see analyze_bug_hotspots '
          'for the specific false-positive-rate caveats that apply here '
          'too.',
    ],
    pairWith: [
      'Pair with get_stats for a language-stratified breakdown of the same '
          'tag range, to see whether the churn driving this release\'s '
          'numbers came from production code or from tests, docs, and '
          'configuration.',
    ],
  ),

  AnalysisType.changelog: ToolHints(
    interpretation: [
      'Entries are classified using the Conventional Commits convention — '
          'a feature-prefixed commit maps to a minor version bump, a fix '
          'to a patch bump, and an explicit breaking-change marker to a '
          'major bump under semantic versioning. This works reliably with '
          'simple pattern matching rather than requiring any kind of '
          'learned classifier, because real commit messages turn out to be '
          '"natural" enough — repetitive and predictable in their phrasing '
          '— for straightforward rules to classify them well (Hindle et '
          'al. 2012). Each fix entry is additionally enriched with the '
          'commit that is believed to have introduced the bug and how long '
          'it lived before being fixed, inheriting the same accuracy '
          'characteristics as the bug-attribution pipeline used elsewhere '
          'in this tool set.',
    ],
    pairWith: [
      'Pair with analyze_release_delta for the churn and defect context '
          'behind the same tag range this changelog covers.',
    ],
  ),

  AnalysisType.contributionsByAuthor: ToolHints(
    interpretation: [
      'Contributor activity in most real projects follows a recognizable '
          '"onion model" shape: a small core of people producing the '
          'majority of the work, surrounded by a much longer tail of '
          'occasional contributors (Crowston & Howison 2005) — seeing that '
          'shape here is normal, not itself a red flag. Excluding merge '
          'commits from the count matters, since merge commits otherwise '
          'inflate the apparent activity of whoever happens to perform '
          'integrations, crediting them with work they did not author.',
    ],
    pairWith: [
      'Designed to be read together with analyze_commit_velocity, whose '
          'Gini coefficient measures the same concentration from a '
          'different angle (Gini 1912), and with analyze_file_ownership, '
          'which surfaces the minor-contributor risk this tool\'s '
          'contribution counts hint at down at the level of individual '
          'files (Bird et al. 2011).',
    ],
  ),

  AnalysisType.stats: ToolHints(
    interpretation: [
      'Lines of code is the most readily available way to measure the '
          'scope of a codebase from its history alone, even though it is a '
          'blunt instrument as a quality measure on its own (Boehm 1981). '
          'Breaking that total down by file extension is what makes the '
          'number useful for risk reasoning: it lets you separate churn in '
          'production code from churn in tests, documentation, or '
          'configuration, and those carry meaningfully different risk '
          'profiles — a large diff that is mostly test or config changes is '
          'a very different signal than the same size diff in production '
          'logic (Mockus & Votta 2000).',
    ],
    pairWith: [
      'Feeds directly into analyze_release_delta, which uses this tool\'s '
          'churn figures as one of the inputs to its own risk assessment.',
    ],
  ),

  // ------------------------------------------------------------- Static analysis
  AnalysisType.cleanCode: ToolHints(
    interpretation: [
      'In your report, you must explain the specific syntactic algorithms '
          'triggering each clean code flag. Explain that file length flags '
          'trigger when non-empty LOC exceeds 300, pointing to Single '
          'Responsibility Principle violations (Martin 2008). Explain that '
          'nesting algorithms calculate the AST depth of conditional blocks, '
          'and depths >= 5 overwhelm typical human working memory (Wulf & '
          'Shaw 1973). Explain that long line algorithms calculate the '
          'percentage of lines exceeding 100 characters to assess scannability, '
          'while magic number detectors flag undocumented numeric literals. '
          'Finally, explain that code duplication algorithms use rolling AST '
          'hashes to find identical blocks of logic, which force developers '
          'to fix identical bugs multiple times (Koschke 2007). Guide the '
          'user on how to address the specific algorithm that failed.',
    ],
    pairWith: [
      'Pair with calculate_universal_lexical_metrics for the numeric '
          'complexity scores that sit behind these surface-level flags. '
          'When deep nesting is the issue, the well-established remedy is '
          'restructuring with guard clauses, early returns, or extracting '
          'smaller functions (Atwood 2006) — not a wholesale rewrite.',
    ],
  ),

  AnalysisType.codeQuality: ToolHints(
    interpretation: [
      'When interpreting code quality, explicitly detail the thresholds and '
          'algorithms used. Explain that a "mega commit" algorithm flags '
          'commits exceeding standard standard deviations for lines or files '
          'changed, warning that these carry disproportionately higher defect '
          'density (Mockus & Votta 2000). Describe how the single-responsibility '
          'checker identifies files that repeatedly co-change across unrelated '
          'commits, smearing responsibilities (Martin 2000). Detail the '
          'open-closed principle violation detector, which flags files '
          'accumulating extremely high churn (Tornhill 2015). Finally, when '
          'analyzing author ownership algorithms, explain that a contributor '
          'under a 5% commit threshold is flagged as a minor risk, while '
          '>75% triggers a concentrated ownership silo warning (Bird et al. '
          '2011; Weyuker, Ostrand & Bell 2008).',
    ],
    pairWith: [
      'Pair with analyze_logical_coupling — the single-responsibility '
          'violations flagged here and the coupling clusters that tool '
          'reports are usually pointing at the same underlying files from '
          'two different angles.',
    ],
  ),

  AnalysisType.dartAstQuality: ToolHints(
    interpretation: [
      'Most real-world breakage from a changed public API does not come '
          'from something being deleted outright — it comes from a rename '
          'or a changed parameter, which is why this tool compares actual '
          'signatures rather than merely checking whether a symbol still '
          'exists somewhere (Dig & Johnson 2006). An import-cycle finding '
          'means a genuine circular dependency exists among the reported '
          'files — a group of modules that all indirectly depend on one '
          'another, which makes each one harder to understand, test, or '
          'change in isolation (Tarjan 1972). A method flagged as '
          'unreferenced anywhere in the analyzed scope is a dead-code '
          'candidate worth a second look before removal, since this is a '
          'static heuristic that can miss dynamic or reflective call sites '
          '(Bacon & Sweeney 1996).',
    ],
    caveats: [
      'This analysis is intentionally capped at ten files per call — '
          'catching a breaking API change is most valuable at the moment a '
          'pull request introduces it, not as a repository-wide sweep, and '
          'the scope limit keeps the analysis fast enough to run at that '
          'point (Raemaekers et al. 2012).',
    ],
    pairWith: [
      'Pair with generate_code_review_report before merging any pull '
          'request that changes a public Dart signature — the report\'s '
          'classified findings have no visibility into AST-level signature '
          'breakage on their own.',
    ],
  ),

  AnalysisType.universalLexicalMetrics: ToolHints(
    interpretation: [
      'Several independent, well-studied complexity measures are reported '
          'together here. You must interpret these deeply for the user, '
          'explaining the algorithms and how they interact. A function '
          'with a cyclomatic complexity (McCabe 1976) of ten or below is '
          'manageable; eleven to twenty needs review; above twenty '
          'makes testing practically impossible due to the explosion of '
          'independent paths. A maintainability index (Coleman et al. 1994) '
          'of 85+ is highly maintainable; below 65 demands refactoring. '
          'An ABC score (Fitzpatrick 1997) above 15 is elevated and 30+ '
          'warrants refactoring — this explicitly catches Assignments, '
          'Branches, and Conditions to identify size and state-mutation '
          'complexity that cyclomatic complexity misses entirely. '
          'An NPath figure (Nejmeh 1988) above 200 means the number of '
          'distinct acyclic execution paths makes exhaustive testing '
          'impossible.',
      'For Halstead metrics (Halstead 1977), you must explain the '
          'underlying algorithms: Volume measures the program\'s size '
          'based on its total operators and operands (N) and vocabulary '
          '(n) as V = N * log2(n). Difficulty (D) measures error-proneness '
          'and how hard it is to write or understand, calculated from '
          'unique operators and total operands. Effort (E = V * D) '
          'translates to the mental effort required to understand or '
          'modify the code. Finally, Delivered Bugs (B = E^(2/3) / 3000) '
          'is validated against industrial defect data. When interpreting '
          'these metrics, explain *why* a high Difficulty and Volume '
          'lead to a high Effort and subsequent bug estimation, guiding '
          'the user on exactly what aspects of the code (e.g., too many '
          'unique operands, excessive operators) to target for refactoring.',
    ],
    caveats: [
      'Cognitive complexity, which measures how hard code is for a human '
          'to read, and cyclomatic complexity, which measures how hard '
          'code is to test exhaustively, are answering different '
          'questions and can disagree on the very same function (Campbell '
          '2018) — a high score on one and a low score on the other are '
          'both meaningful and should not be averaged or collapsed into a '
          'single verdict.',
    ],
    pairWith: [
      'Most useful when run specifically on files that analyze_code_'
          'volatility or analyze_bug_hotspots has already flagged — '
          'complexity matters most where a file\'s change or defect history '
          'shows it is already a source of risk, rather than across the '
          'whole codebase indiscriminately.',
    ],
  ),

  AnalysisType.evaluateComments: ToolHints(
    interpretation: [
      'Studies of real codebases have found that a large majority of '
          'comments — well over half — are redundant, out of date, or '
          'simply commented-out code left behind, with only a small '
          'fraction genuinely adding information a reader could not get '
          'from the code itself (Steidl et al. 2013). The comments worth '
          'keeping are the ones that explain why a piece of code exists or '
          'why it was written a particular way — something the code cannot '
          'say about itself — rather than restating what the code '
          'already visibly does (Knuth 1984; Martin 2008).',
    ],
    caveats: [
      'Comments produced by AI assistance carry a distinct failure mode '
          'worth watching for specifically: they tend to be verbose, to '
          'state specific technical details with unearned confidence that '
          'turn out to be wrong, and to get accepted into a codebase '
          'unread under time pressure — sometimes called the "autocomplete '
          'effect" (Liu et al. 2023; Vaithilingam et al. 2022; Brown et '
          'al. 2020). Meta-language artifacts like a stray "<thinking>" '
          'block or a phrase such as "As an AI" are a reliable sign a '
          'comment was never actually reviewed before being committed.',
    ],
    pairWith: [
      'Prioritize running this on files analyze_code_quality has already '
          'flagged as high-churn — outdated documentation sitting next to '
          'code that changes often is worse than having no documentation '
          'at all, since it actively misleads the next person to touch it '
          '(Bird et al. 2011).',
    ],
  ),

  // ------------------------------------------------------------------- Security
  AnalysisType.auditCompliance: ToolHints(
    interpretation: [
      'An unsigned-commit finding here means the commit\'s cryptographic '
          'signature status was neither fully valid nor an expired-but-'
          'still-trustworthy signature — anything short of that is treated '
          'as unsigned, which maps directly onto specific controls in NIST\'s '
          'Secure Software Development Framework and ISO 27001\'s Annex A. '
          'The underlying reason this matters is not merely procedural: '
          'projects with more structured, disciplined commit practices, '
          'including signed audit trails, have been observed to carry lower '
          'defect density and to be more predictable to plan around (Bird '
          'et al. 2015).',
    ],
    caveats: [
      'This tool has no way to know how much a given violation actually '
          'matters in context — the same unsigned commit is a minor '
          'process gap in a low-stakes internal tool and a serious finding '
          'in a repository that handles secrets or falls under regulated-'
          'data scope such as PCI DSS Requirement 10, so severity should be '
          'calibrated to the repository\'s actual exposure, not read '
          'uniformly.',
    ],
    pairWith: [
      'Pair with detect_secrets_in_commits — compliance posture and '
          'credential hygiene are almost always reviewed together when '
          'preparing for a SOC 2 or PCI DSS audit.',
    ],
  ),

  AnalysisType.detectSecrets: ToolHints(
    interpretation: [
      'You must explain the Shannon entropy algorithm (Shannon 1948) used by '
          'this tool. The algorithm calculates the character randomness of '
          'strings (H = -sum(p * log2(p))). Natural-language identifiers and '
          'code sit in a comfortably low entropy range, while true random '
          'cryptographic tokens sit distinctly higher. Explain that to cut '
          'false positives, the algorithm combines this entropy math with '
          'regex checks for credential assignment patterns (Zielinski et al. '
          '2016). Guide the user to understand that a hit here is not a '
          'hypothetical risk — it is a mathematically identified, high-entropy '
          'credential exposure requiring immediate rotation.',
    ],
    caveats: [
      'Most secrets that have ever been committed to a repository are '
          'never removed, even when a later commit appears to delete them, '
          'because the history containing the original commit is still '
          'reachable — and automated scanners are known to pick up exposed '
          'credentials within minutes of a push (Meli et al. 2019; Ohm et '
          'al. 2020). A finding here requires rotating the credential and '
          'purging it from history, not just committing a follow-up '
          'removal.',
    ],
    pairWith: [
      'A secret found here alongside a stale, vulnerable dependency flagged '
          'by analyze_dependency_drift compounds into a critical '
          'supply-chain finding when the two are read together in a '
          'security report.',
    ],
  ),

  // ------------------------------------------------------------------ Boundary
  AnalysisType.commitsBetween: ToolHints(
    pairWith: [
      'Feeds analyze_release_delta and get_stats when what is actually '
          'needed is risk or churn interpretation of a commit range, rather '
          'than the raw list of commits this tool returns on its own.',
    ],
  ),
};
