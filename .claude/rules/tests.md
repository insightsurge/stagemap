---
paths:
  - "tests/**"
---

# Tests

Labels as in `r-code.md` (CRAN / house). Reasons and sources: `docs/standards.md`.

- **house:** coverage of at least 70% of lines (`Rscript tools/cran-gate.R tests`; the limit is
  `Config/cran-gate/coverage` in `DESCRIPTION`, which CI reads too; CRAN itself does not check coverage); a PR never
  lowers it. Every added runnable line in `R/` must run in a test (`new_lines`). `# nocov` is only for code that truly
  cannot run in a test, with the reason beside it. covr measures R code only; Shiny behaviour tests cover JS.
- **house:** merge evidence is a `tests` or `full` gate run exiting 0. PARTIAL runs (`--steps`, `--filter`,
  `--no-coverage`) are not evidence. Exit code 3 means all failing tests passed on re-run: it needs the package
  creator's acceptance. Before an agent reports done, run both `fast` and `tests`; report summary lines, failures
  and anything not run with its reason. Local results do not replace CI.
- **house:** testthat 3rd edition, BDD style: one test file per R file (`R/layout.R` → `tests/testthat/test-layout.R`);
  `describe("stagemap()", { it("places each node in its stage", { ... }) })`, with `describe()` naming the
  function or behaviour and `it()` stating the expected behaviour in plain words; `# Given / # When / # Then`
  where it helps. Cover the happy path, every checkmate assertion (a test that it fails with a clear message),
  edge cases and every bug fix.
- **house:** `expect_snapshot()` for printed output, generated HTML and error messages; review snapshot changes
  in the PR like code. Keep snapshots small (text, not images).
- **house:** `shiny::testServer()` for server logic; **shinytest2** for every behaviour a user sees (renders,
  highlighting, selection, filtering, light/dark): apps in `tests/testthat/apps/<name>/app.R` or a
  function passed to `AppDriver$new()`; `withr::defer(app$stop())`. Assert on values, DOM state, `data-*`
  attributes, the `role="status"` text and engine state read with `app$get_js()`; screenshots only when nothing
  else can show it.
- **CRAN:** every shinytest2 or chromote test starts with `testthat::skip_on_cran()`,
  `testthat::skip_if_not_installed("shinytest2")` and a skip when `chromote::find_chrome()` is `NULL`. CRAN has
  asked that no package uses Chrome when tested on CRAN. CI runs them (`NOT_CRAN=true` in the coverage job).
- **CRAN:** tests use only declared packages and guard Suggests (`skip_if_not_installed()`); no network; files go
  to `withr::local_tempdir()`; nothing is left behind; at most 2 cores.
- **house:** keep JS logic small and push decisions into R, where they can be unit-tested.
