# stagemap engineering standards

This page explains the reasons and sources behind stagemap's working rules in
[`.claude/rules/`](https://github.com/insightsurge/stagemap/tree/main/.claude/rules).

The [R code rules](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/r-code.md) define the CRAN and
house labels and how exceptions work.

Source codes used in the tables (full names are in section 10): POL = CRAN Repository Policy, CHK = CRAN submission
checklist, WRE = Writing R Extensions, INTS = R Internals, COOK = CRAN Cookbook, RPKGS = R Packages (2nd edition),
WCAG = Web Content Accessibility Guidelines.

## 1. CRAN acceptance criteria

### 1.1 DESCRIPTION

| Rule | Label | Source |
|---|---|---|
| One named maintainer with a working email address (a person, not a list) | CRAN | POL |
| Author and copyright roles | CRAN | POL |
| CRAN-listed licence and MIT stub | CRAN | COOK |
| Title Case and title conventions | CRAN | COOK |
| Description of at least two sentences | CRAN | COOK, CHK |
| Quoting software, functions and URLs | CRAN | COOK, CHK |
| Explain acronyms | CRAN | COOK |
| `URL` and `BugReports` resolve (the repository is public before submission) | CRAN | CHK |
| `Language: en-GB`, and the text is spelt in British English | house | - |
| Declared dependencies and guarded Suggests | CRAN | POL |
| No `LazyData` unless there is a `data/` directory | CRAN | WRE |

### 1.2 Code behaviour

| Rule | Label | Source |
|---|---|---|
| Write only to `tempdir()` or a user path | CRAN | POL |
| Do not modify the global environment | CRAN | POL |
| Restore changed session state | CRAN | COOK |
| No side effects on load or attach | CRAN | POL |
| Messages go through `message()` or cli, never `print()` or `cat()` | CRAN | COOK |
| No fixed `set.seed()` inside functions; expose a `seed` argument if R-side randomness is needed | CRAN | COOK |
| Logical constants, warnings and installed-package queries | CRAN | COOK |
| Do not start browsers or viewers in examples or tests unless they are closed again | CRAN | POL |
| Use at most two cores | CRAN | POL |
| No network access or run-time downloads | CRAN | POL |
| No access to package internals | CRAN | POL |
| No session telemetry | CRAN | POL |
| Check arguments first; checked-input helper exception | house | - |
| Use cli for messages, warnings and errors | house | - |
| Snake case, distinct export names | house | - |

Package-specific condition classes let callers catch stagemap conditions without matching message text; see the
[R message rules](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/r-code.md#arguments-and-messages).

### 1.3 Files and size

| Rule | Label | Source |
|---|---|---|
| Source is included for every component | CRAN | POL |
| No binary executables | CRAN | POL |
| Tarball under 10 MB if at all possible; installed size under 5 MB (larger is a NOTE) | CRAN | POL, INTS |
| Tarball target under 5 MB | house | - |
| Portable file names and paths | CRAN | WRE |
| No stray top-level or hidden files; every config file is listed in `.Rbuildignore` | CRAN | INTS |
| Leave no files in the check directory, temporary directory or home directory | CRAN | INTS |
| No reserved names in `inst/` | CRAN | WRE |
| `docs/`, `tools/`, `dev/` and tool config files are build-ignored | house | - |

### 1.4 Documentation and examples

| Rule | Label | Source |
|---|---|---|
| Return value on every Rd page with a usage | CRAN | COOK |
| Offline examples for every export | CRAN | COOK |
| Short examples; unwrap those under five seconds | CRAN | POL, COOK |
| Guard interactive and slow examples honestly | CRAN | COOK |
| Regenerate help and NAMESPACE from source | CRAN | COOK |
| Use https and canonical URLs; no relative links to README or LICENSE inside Rd files | CRAN | CHK |
| Parseable NEWS release headings | CRAN | INTS |

### 1.5 Tests

| Rule | Label | Source |
|---|---|---|
| Tests use little CPU time | CRAN | POL |
| Skip Chrome on CRAN and when unavailable | CRAN | shinytest2 docs |
| Guard Suggests; check without them | CRAN | INTS |
| Temporary test files and cleanup | CRAN | INTS |
| R coverage of at least 70% (not measured by CRAN) | house | - |
| Snapshot files hold only `expect_snapshot()` calls | house | testthat docs |
| Code, examples and tests run on the oldest R in `Depends` (4.1) | house | - |

### 1.6 JavaScript, CSS, fonts and third-party files

| Rule | Label | Source |
|---|---|---|
| Nothing in the policy singles out minified JavaScript; the general rule applies: source, or something that can easily be converted back to source | CRAN | POL, WRE |
| We ship plain, unminified JS and CSS in `inst/`, with no build step | house | - |
| If a build ever arrives (TypeScript, npm libraries): keep sources in git, build-ignore them, and ship both the unminified file and the `.min.js` and source map | house | - |
| Clear copyright for every bundled component | CRAN | POL |
| Record third-party copyright holders | CRAN | POL, WRE |
| No CDN and no run-time downloads: JS, CSS and fonts are bundled | CRAN | POL |
| OFL licence text and Reserved Font Names | house | OFL 1.1 text |

### 1.7 Submission

| Rule | Label | Source |
|---|---|---|
| Submit through the web form, with `R CMD check --as-cran` run on the built tarball with current R-devel | CRAN | POL, CHK |
| No warnings; every note is explained in `cran-comments.md` (the "New submission" note is expected) | CRAN | CHK |
| Do not resubmit while a submission is pending; raise the version on each resubmission | CRAN | CHK |
| Reply to a reviewer by resubmitting with an explanation | CRAN | CHK |
| 0 errors, 0 warnings, 0 notes before every PR, not only before submission | house | - |

## 2. Common reviewer checks

Check these topics before submitting; the linked files hold the working rules.

- Output paths: [R behaviour][r-code].
- Global environment and restored session state: [R behaviour][r-code].
- Browsers, apps and Chrome guards: [examples][roxygen] and [tests][tests].
- Network and CDN restrictions: [R behaviour][r-code] and section 3.
- Two-core limit: [R behaviour][r-code].
- Sources, binaries and copyright: [bundled files][bundled-files].
- Forbidden calls and namespace changes: [R behaviour][r-code].
- Messages, dependencies, logical constants and session state: [R code][r-code].
- Example guards: [documentation][roxygen].
- Session telemetry: [R behaviour][r-code].
- Validation claims: [wording][roxygen]. Colour alternatives: section 3.

Section 1 leans on the CRAN Cookbook's common reviewer requests: descriptions and acronym
explanations make a package understandable; title, quoting, links and return values make its help usable; short
examples, restored options and cleaned-up temporary files make checks reliable. Copyright roles and spelling also
need review. See [metadata][description-news], [examples][roxygen], [R behaviour][r-code] and
[bundled files][bundled-files].

## 3. The UI engine (JavaScript and CSS)

The engine is most of what a user sees, so it has its own rules. All of these are **house** rules unless marked.

**Files and build**

- Plain, unminified, readable JavaScript (ES2015 or later) and CSS in `inst/`, with no build step, no bundler and no
  modules. Readable JS is its own source, which satisfies CRAN's source rule (**CRAN**) and lets a reviewer read
  exactly what runs. It also needs no Node in CI. shinyjs and htmlwidgets ship hand-written JS the same way.
- No CDN and no external request of any kind (**CRAN**, see 1.2).
- Deterministic drawing: a seeded random number generator, no `Math.random`, no clock-driven drawing. The same input
  gives the same frames, which makes tests possible.
- Target current versions of Chrome, Edge, Firefox and Safari, and say so in the docs.

**Architecture**

- Maps reach Shiny, Quarto and pkgdown as an **htmlwidget wrapped around stagemap's own engine** (#7, to be
  revisited once the engine is written). htmlwidgets brings printing in documents, `saveWidget()`, the RStudio viewer
  and maps inside reactable cells; the engine keeps stagemap's drawing in one place.
- The engine is plain JS with its own API: `mount`, `update`, `resize` and `destroy`. The htmlwidget binding calls
  `mount`, `update` and `resize` (htmlwidgets has no destroy hook; `destroy` serves re-renders and a later own
  binding). The engine never depends on htmlwidgets, so the wrapper can later be replaced by stagemap's own Shiny
  output binding (dropping a hard dependency) without changing the engine or the R functions.
- The widget's markup comes from a `stagemap_html()` hook that ignores htmlwidgets' `style` argument, so sizes travel
  as `data-*` attributes rather than an inline `style=` in the markup. (htmlwidgets' runtime still sets sizes through
  `el.style` in standalone pages, such as `saveWidget()` output and the RStudio viewer.)
- shiny stays in `Suggests`: maps work in Quarto, R Markdown and pkgdown without it.
- One accepted exception to "no `eval`" below: htmlwidgets' own runtime uses `eval()` for `JS()` and `onRender()`.
  stagemap's own R and JS code never uses `JS()` or `onRender()`; a user who adds them opts into that `eval()`.
- One namespace, `window.stagemap`. Guard against double loading, keep state per element, support several maps on
  one page, and leave no global listeners behind.
- The engine is versioned with the package (`window.stagemap.version` is the package version, passed from R).
- Configuration comes through `data-*` attributes (or a `<script type="application/json">` data block).
- No `eval` (except htmlwidgets' runtime, above), no `new Function`, no inline `<script>` of our own, no inline
  `style=` for layout.

**Theming**

- Maps follow the page's Bootstrap `--bs-*` colours by default. Public colour hooks use the `--stagemap-*` prefix
  and take priority over Bootstrap and copied page colours; every other custom property uses the private
  `--_stagemap-*` prefix.
- Follow dark mode by watching `data-bs-theme` and Quarto's body classes; with no signal, light (a plain page in
  an OS dark mode stays light, so the map matches the page).
- bslib is in `Suggests`, never `Imports`. The package ships no fonts: maps use the host page's font (the app's
  bslib theme, the Quarto or pkgdown site), never a font service.

**Accessibility**

- Colour never carries meaning alone: a link kind also has its line style or end mark, a status also has text or an
  icon (WCAG 1.4.1).
- Nodes people can act on are keyboard-focusable and named, so screen readers say what they are (WCAG 2.1.1, 4.1.2).
- `prefers-reduced-motion` is honoured in CSS and JS. An R argument also switches animation off (WCAG 2.3.3).
- No automatic animation lasts longer than five seconds without a way to pause it (WCAG 2.2.2).
- Theme colours are checked for contrast, at least 3:1 for graphics, in light and dark (WCAG 1.4.11).

**Content Security Policy (CSP), stated honestly**

The docs say "stagemap adds no inline script of its own". They do not say it works under any strict CSP, because Shiny
itself still uses inline scripts.

**Keep JS small**: decisions live in R, where they can be unit-tested. JS is tested through shinytest2 and the
widget's rendered output (section 6). Engine change notes follow the [JS/CSS rule][js-css].

## 4. Bundled files and licences

The [copyright rule](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/bundled-files.md) makes the
origin, holder and licence of each shipped file reviewable. `inst/COPYRIGHTS` is the file named by Writing R
Extensions (**CRAN**).
Contributor roles distinguish contributions from copyright ownership; see the
[bundled-file rule](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/bundled-files.md).

**Font licences**

- Font licence and Reserved Font Name terms govern redistribution and renaming; see the
  [conditional font rule](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/bundled-files.md).
- Copyright roles identify font holders. bslib provides an example of recording each project; a reviewer may ask
  for `Copyright: See inst/COPYRIGHTS` (**CRAN**). See the
  [copyright rule](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/bundled-files.md).
- Subsetting reduces bundled size; the
  [font rule](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/bundled-files.md) owns the format choice.

**Why check the built package?**

The [acceptance checklist][bundled-files] checks the installed package, since a source checkout alone does not
show what users receive.
Copyright records make the origin and redistribution terms reviewable.
Offline loading avoids a dependency on external services.
Portable, case-correct paths matter because Linux treats case differently from typical macOS and Windows setups.
Size checks limit download and installation costs; the working limits are in the bundled-file rules.

## 5. Documentation and dependencies

**Documentation** (roxygen2 with markdown):

- Return-value documentation tells callers what they can use; see the
  [roxygen rule](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/roxygen.md) and section 1.4.
- Short offline examples are easy to try; interactive guards prevent help examples from opening apps. See the
  [example rules](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/roxygen.md).
- Regeneration keeps help and namespaces aligned with source; see the
  [roxygen workflow](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/roxygen.md).
- Canonical https links and quoted software names meet submission expectations; see section 1.4 and the
  [metadata rules](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/description-news.md).
- Plain wording avoids unsupported claims; see the
  [wording rules](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/roxygen.md#wording).
- **NEWS:** add user-facing changes in the same PR; see [NEWS rules][description-news].

**Dependencies:**

- **Imports:** keep dependencies minimal; see [dependency rules][r-code]. Planned once the engine lands: checkmate,
  cli, htmltools, htmlwidgets and jsonlite (shiny stays in `Suggests`; section 3 says why).
- Qualified calls show where functions come from; see the
  [dependency rules](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/r-code.md#dependencies).
- Guarded optional dependencies let core features work without Suggests; see the
  [dependency rules](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/r-code.md#dependencies) and
  [test skips](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/tests.md).
- Calls to another package's internals are fragile; see the
  [behaviour rules](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/r-code.md#behaviour).

### Lifecycle and status words

**House.** The lifecycle badge is used only for experimental and deprecated. Other promises weaker than "stable"
use plain words in help pages:
- **informal:** the shape is not promised (example: the text of a printed summary).
- **add-only:** ids and columns may be added, never removed or renamed.
- **reserved:** a name held back so nothing else can take it.
- **dev-mode only:** appears only in Shiny development mode.

## 6. Testing

- **A pyramid.** Most tests are fast unit tests. Above them sit `shiny::testServer()` tests for server logic, and
  above those a small number of shinytest2 tests for what a user sees.
- BDD names read as requirements; the [test rules][tests] define the structure and file mapping.
- Argument and bug-fix tests make failures reproducible; see the
  [test cases rule](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/tests.md).
- Small text snapshots make output changes reviewable; see the
  [snapshot rule](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/tests.md).
- **shinytest2 assertions are on values, DOM state and status text, not on screenshots.** Use `app$get_value()`,
  `app$expect_values()`, and `app$get_js()` reading the engine's exposed state (selected node, highlighted links, a hash
  of the drawn elements), `data-*` attributes and the `role="status"` text. Because frames are deterministic, a hash of
  the draw calls is a stable target across operating systems. A pixel hash is only for one pinned Chrome. Apps live
  in `tests/testthat/apps/<name>/app.R`.
- **Browser tests wait for the server's answer, not for the page to change.** The page marks a widget busy until the
  server's stamp matches the request, and tests wait for "not busy and stamped"; waiting for text passes on an older
  page that already shows it. The [test rules][tests] and the [engine rules][js-css] list the details.
- Chrome skips respect CRAN's request; app cleanup avoids leftover processes. See the
  [Shiny test rules](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/tests.md).
- **Files:** use temporary test directories; see [test rules][tests].
- Coverage exposes R lines the tests do not exercise; CRAN does not measure it and covr does not see JS. The
  [test rules](https://github.com/insightsurge/stagemap/blob/main/.claude/rules/tests.md) own the limit,
  added-line requirement and exclusions.
- **No jest or vitest for now.** If pure JS functions grow (colour maths, easing), `node --test` needs no dependency.
- **Guardrails are tested too.** Each gate step has a probe in the gate's self-test that plants a defect and
  expects the step to fail, and a clean copy must pass (section 7.2).

## 7. The quality pipeline

### 7.1 One rule, three places

Each rule is written once, in git (`air.toml`, `.lintr`, `biome.json`, the gate script, the workflows). Three layers
run it:

| Layer | When it runs | Status |
|---|---|---|
| Editor settings (`.claude/settings.json`) | While an assistant works in the repo: permission rules deny force-push, pushes to `main`, `--no-verify` and hand edits to `NAMESPACE`, `man/`, `renv/`, `LICENSE`; merging a PR (`gh pr merge`) asks for confirmation each time; attribution lines are off. Formatting is a one-line instruction (`air format .`) | In place |
| The gate (`Rscript tools/cran-gate.R`, section 7.2) | On demand, before a commit or PR | In place |
| CI | On every PR and push to `main`, weekly and on demand, with the full platform matrix each time; it cannot be skipped | In place |

Editor permission guards do not replace checks. See the
[contributor workflow](https://github.com/insightsurge/stagemap/blob/main/.github/CONTRIBUTING.md#workflow) for
merging and section 8 for the decision about a pre-commit framework.

### 7.2 The gate

How to run it, which mode when, every option, the exit codes and the run folder: `tools/README.md` (and
`Rscript tools/cran-gate.R --help`; `--list` shows each mode's steps). This section keeps the reasons.

**The gate is a generic, self-contained script, maintained in mascot.** `tools/cran-gate.R` is a copy of
[mascot's gate](https://github.com/insightsurge/mascot/tree/main/tools) and is never edited here; its self-test lives
in mascot. A problem or a new check goes to mascot, and the new version is copied here. What is specific to a package
is kept out of the script:

- CRAN checks always run. Style checks run when the package has the tool's settings file (`air.toml`, `.lintr`,
  `biome.json`) and are skipped with a reason otherwise. stagemap has all three.
- Settings are `Config/cran-gate/*` fields in `DESCRIPTION`: `coverage` (default 70, which stagemap uses), `tarball-mb`
  (default 5, at most 9 because CRAN's limit is 10; stagemap keeps 5) and `extra-dirs` (more folders to format-check
  and lint; stagemap lists `tools`, which holds the gate itself).

A missing tool stops the gate, never a silent skip. The gate writes to the repository in two deliberate cases only:
`document()` may rewrite `man/`, `NAMESPACE` and `DESCRIPTION` (the step then fails and names the files), and
`--update-wordlist` rewrites `inst/WORDLIST`, which is never run without showing the words first (see 7.4).

**The gate's self-test** lives in mascot with the gate: it plants one defect per step in a copy of a package and
checks that the gate fails that step.

### 7.3 CI workflows

What each workflow runs, and the gate mode that reproduces it locally: `tools/README.md` ("The gate and CI").

A ruleset on `main` blocks force-pushes and deleting the branch; it does not require passing checks, so the rule is:
CI green, then ask before merging.

Every pull request runs the full matrix (macOS, Windows and four Ubuntu R versions); keep new jobs on Ubuntu unless
the platform is the point.

The site is built from `main` only, never on pull requests: a site build may need packages that outside
contributors' pull requests can't install. Ubuntu runners are pinned (`ubuntu-26.04`; macOS and Windows use
`-latest`) so an image change is a deliberate edit. Workflows take the least permissions they need and cancel
superseded runs (except a release, and secret scans on `main`). Every job has a `timeout-minutes`, a few times its
longest recent run, so a hung step can't hold a runner for hours. Actions from `actions/` and `r-lib/` are pinned by
major tag; other third-party actions by full commit SHA with a `# vX.Y.Z` comment, because a tag can be moved and a
SHA cannot. Dependabot updates both kinds and rewrites the version comment. Keep the Air and Biome versions in
`lint.yaml` in step with the local installs and with `biome.json`.

### 7.4 Tools

- **Air** (R formatter, https://posit-dev.github.io/air/). `air.toml` sets `line-width = 120`, the width our docs and
  lintr already use.
- **Biome** (formatter and linter for JS and CSS, https://biomejs.dev). `biome.json` covers `inst/**/*.js` and
  `inst/**/*.css`: two-space indent, width 120, single quotes, the `recommended` lint rules. It is build-ignored. The
  gate skips it only while `inst/` has no JS or CSS; once there is any, it is required and a missing binary fails.
- **lintr** (`.lintr`). Line length 120. Object names are `snake_case` or symbols. The `:::`, `<<-` and `->>` operators are flagged. The banned
  function list is short and each entry has a reason:

  | Banned | Reason | Label |
  |---|---|---|
  | `library`, `require` | Declare the package and call `pkg::fn()`; use `requireNamespace()` for optional packages | CRAN |
  | `attach` | Do not change the user's search path | CRAN |
  | `setwd` | Use `withr::local_dir()` or a path argument | CRAN |
  | `Sys.setenv` | Use `withr::local_envvar()` | CRAN |
  | `print`, `cat` | Use cli for messages (a `print()` method may use `# nolint`) | CRAN |
  | `set.seed` | Take a `seed` argument instead | CRAN |
  | `source` | Put code in `R/` | house |
  | `browser`, `debug`, `debugonce` | Remove debugging code | house |

  Files under `tests/` are exempt from the banned function list and from `object_usage_linter`. `dev/` and `renv/` are
  not linted. A `# nolint` comment must say why.
- **Spelling.** A package-wide spelling check uses the declared language. Keeping it in the gate avoids a second
  spelling test. Word-list changes follow [Public text][public-text].

## 8. What we left out on purpose

| Left out | Why |
|---|---|
| Pre-commit framework | One maintainer and no shared clone yet; it needs a Python tool. The gate and CI cover the same checks. Revisit when others commit |
| Screenshot tests in the test suite and CI | They differ between operating systems and Chrome versions. Values, DOM state and draw-call hashes are stable. |
| jest or vitest | JS logic is kept small and tested through shinytest2. `node --test` is the fallback if pure functions grow |
| TypeScript and a build step | Only needed for TypeScript or npm libraries. Plain JS is its own source and needs no Node in CI |
| Minimum and maximum dependency matrices | Overkill for a package with few imports and no users yet |
| revdepcheck | No package depends on `stagemap` yet |
| Licence-audit, CLA and codemeta bots | One maintainer and the licence record is `inst/COPYRIGHTS`; a bot adds upkeep without a reader |
| Posit's shiny-workflows | bslib's own workflow calls that setup overkill for most R packages; we copy r-lib's standard workflows |

## 9. Releases

Releases and CRAN submissions belong to the package creator; see [release rules][description-news].

### Package versions

For patch and minor versions, deprecation periods and CRAN tags, see the release rules above.

## 10. Sources

- **POL:** CRAN Repository Policy, <https://cran.r-project.org/web/packages/policies.html>
- **CHK:** CRAN submission checklist, <https://cran.r-project.org/web/packages/submission_checklist.html>
- **WRE:** Writing R Extensions, <https://cran.r-project.org/doc/manuals/r-release/R-exts.html>
- **INTS:** R Internals (the `_R_CHECK_*_` settings, including `_R_CHECK_SUGGESTS_ONLY_`),
  <https://cran.r-project.org/doc/manuals/r-release/R-ints.html>
- **COOK:** CRAN Cookbook, <https://contributor.r-project.org/cran-cookbook/>
- **RPKGS:** R Packages (2e), <https://r-pkgs.org>
- shinytest2, using it in a package (CRAN's request about chromote),
  <https://rstudio.github.io/shinytest2/articles/use-package.html>
- r-lib/actions (`check-r-package`, the `check-no-suggests` example), <https://github.com/r-lib/actions>
- Air, <https://posit-dev.github.io/air/>; Biome, <https://biomejs.dev>; lintr, <https://lintr.r-lib.org>
- **WCAG** 2.2 (1.4.1, 1.4.11, 2.2.2, 2.3.3, 4.1.3), <https://www.w3.org/TR/WCAG22/>
- SIL Open Font License 1.1, <https://openfontlicense.org>
- Examples of practice: bslib (<https://github.com/rstudio/bslib>: bundled fonts, `LICENSE.note`, `cph` entries) and
  teal (<https://github.com/insightsengineering/teal>: `.lintr`, CI)
- R Validation Hub: riskmetric, <https://pharmar.github.io/riskmetric/>

[r-code]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/r-code.md
[roxygen]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/roxygen.md
[tests]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/tests.md
[description-news]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/description-news.md
[bundled-files]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/bundled-files.md
[js-css]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/js-css.md
[public-text]: https://github.com/insightsurge/stagemap/blob/main/AGENTS.md#public-text
