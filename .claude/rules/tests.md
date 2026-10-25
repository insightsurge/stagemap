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
- **house:** testthat 3rd edition, BDD style: one test file per R file (`R/layout.R` → `tests/testthat/test-layout.R`),
  plus `test-layout-browser.R` for its browser tests and `test-layout-snap.R` for its snapshot tests when it has them
  (the next bullets); `describe("stagemap()", { it("places each node in its stage", { ... }) })`, with `describe()` naming the
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
- **house:** in a shinytest2 test, wait for the server's answer, not for the page to change: the browser changes at
  once and the server answers a moment later, and an older page may already hold the text you wait for. Wait until
  the output is no longer busy (`aria-busy`) and carries the stamp the server wrote for this request (a `data-*`
  attribute; see `js-css.md`), with `app$wait_for_js()`. Don't wait for a Shiny silent validation error (a
  `shiny:error` with an empty message): it is not the answer. Never `app$set_inputs()` an input to the value it
  already has: shinytest2 then waits 30 s for an output change that never comes, silently; check the value instead.
  Wait until nothing else is drawing before a check, so another output's redraw can't make it pass by chance.
- **CRAN:** every shinytest2 or chromote test starts with `testthat::skip_on_cran()`,
  `testthat::skip_if_not_installed("shinytest2")` and a skip when `chromote::find_chrome()` is `NULL`. CRAN has
  asked that no package uses Chrome when tested on CRAN. CI runs them in the `browser-tests` job (`NOT_CRAN: true`).
- **house:** the tests CRAN skips live in files of their own, and nothing else does: browser tests (shinytest2,
  chromote, or any helper that starts Chrome or calls `skip_on_cran()`) in `test-<name>-browser.R`, snapshot tests
  (`expect_snapshot()` skips itself on CRAN) in `test-<name>-snap.R`. A `-snap.R` file holds only `expect_snapshot()`
  calls: CRAN skips the whole file, so a plain expectation there would never run on CRAN; put it in `test-<name>.R`
  The `browser-tests` job runs exactly those
  files and fails on any skip; R CMD check runs the rest. `test-helper-layout.R` fails when a test is in the wrong
  file (an argument check inside `expect_error()` may stay in the plain file: it fails before Chrome starts). A
  helper used only by one file's tests stays at the top of that file; one that a plain file and its `-browser.R` or
  `-snap.R` file both need goes in `helper-<name>.R`, which loads for every test file.
- **CRAN:** tests use only declared packages and guard Suggests (`skip_if_not_installed()`); no network; files go
  to `withr::local_tempdir()`; nothing is left behind; at most 2 cores.
- **house:** keep JS logic small and push decisions into R, where they can be unit-tested.
- **house:** each test file runs on its own: testthat runs the files in two processes at once
  (`Config/testthat/parallel`), in any order, so a file never relies on what another file set up or left behind.
