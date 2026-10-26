---
paths:
  - "tests/**"
---

# Tests

Labels as in `r-code.md` (CRAN / house). Reasons and sources: `docs/standards.md`. How the tests are organised (the
four kinds of test file, their first lines, where each runs, how to run them): `tests/README.md`.

- **house:** coverage of at least 70% of lines (`Rscript tools/cran-gate.R tests`; the limit is
  `Config/cran-gate/coverage` in `DESCRIPTION`, which CI reads too; CRAN itself does not check coverage); a PR never
  lowers it. Every added runnable line in `R/` must run in a test (`new_lines`). `# nocov` is only for code that truly
  cannot run in a test, with the reason beside it. covr measures R code only; Shiny behaviour tests cover JS.
- **house:** merge evidence fits the change. A PR that changes `R/` or `tests/` needs a `tests` or `full` gate run
  exiting 0. A small follow-up that adds no `R/` lines (a review fix, a wording change) needs only `fast` and a
  `--filter` run of the test files it touches, named as such in the PR. `--steps` and `--no-coverage` runs are not
  evidence. Exit code 3 means all failing tests passed on re-run: it needs the package creator's acceptance. Before
  an agent reports done, run `fast` and the evidence the change needs; report summary lines, failures and anything
  not run with its reason. Local results do not replace CI.
- **house:** testthat 3rd edition, BDD style: one test file per R file (`R/layout.R` → `tests/testthat/test-layout.R`),
  plus `test-layout-browser.R` for its browser tests, `test-layout-snap.R` for its snapshot tests and
  `test-layout-extended.R` for long, detailed tests when it has them (the next bullets);
  `describe("stagemap()", { it("places each node in its stage", { ... }) })`, with `describe()` naming the function or
  behaviour and `it()` stating the expected behaviour in plain words; `# Given / # When / # Then` where it helps. Cover
  the happy path, every checkmate assertion (a test that it fails with a clear message), edge cases and every bug fix.
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
  attribute; see `js-css.md`), with `app$wait_for_js()`; for a slow button, click it and read its click number in one
  `app$get_js()`, then wait for that number. Write these waits once, as helpers in `helper-<name>.R` when several
  test files use them. Don't wait for a Shiny silent validation error (a
  `shiny:error` with an empty message): it is not the answer. Never `app$set_inputs()` an input to the value it
  already has: shinytest2 then waits 30 s for an output change that never comes, silently; check the value instead.
  Wait until nothing else is drawing before a check, so another output's redraw can't make it pass by chance.
- **house:** "do X, then Y at once": every action in a Shiny app or view the package ships (Copy, Download, Build,
  Check, a busy button) gets one browser test that changes something and fires the action without waiting for the
  server in between, then checks the action used the change (the rules it tests: `r-code.md`, "Shiny apps").
  Example: set a colour input and click Copy in one `app$run_js()` call, then expect the copied code to have the new
  colour. A test that waits for each step to settle can't catch these bugs. To widen the gap, hold back what the page
  sends or what the server answers (how: `tests/README.md`).
- **CRAN:** no shinytest2 or chromote test runs on CRAN or without Chrome: its file starts with
  `skip_without_chrome()` (`helper-chrome.R`: it skips on CRAN, without chromote or withr, and when
  `chromote::find_chrome()` is `NULL`), and a shinytest2 test also skips without shinytest2. CRAN has asked that no
  package uses Chrome when tested on CRAN. CI runs them in the `off-cran-tests` job (`NOT_CRAN: true`).
- **house:** the tests CRAN skips live in files of their own, and nothing else does: browser tests (shinytest2,
  chromote, or any helper that starts Chrome) in `test-<name>-browser.R`, snapshot tests (`expect_snapshot()` skips
  itself on CRAN) in `test-<name>-snap.R`, and long, detailed tests that CRAN needn't run (many layout cases, every
  widget scenario) in `test-<name>-extended.R`. A browser or extended file starts with its skip, as its first
  expression, so CRAN skips the whole file before any of its code runs: `skip_without_chrome()` or
  `skip_unless_extended()` (`helper-extended.R`: the extended tests run where `NOT_CRAN` is true or `EXTENDED_TESTS`
  is `"true"`). A snapshot file doesn't: skipped as a whole, it reports no snapshots and testthat deletes their saved
  files, so `expect_snapshot()` skips each test instead. A `-snap.R` file holds only `expect_snapshot()` calls: on CRAN
  `expect_snapshot()` skips the rest of its test, so a plain expectation beside it may never run there; put it in
  `test-<name>.R`. The `off-cran-tests` job runs exactly those files and fails on any skip; R CMD check runs the rest.
  `test-helper-layout.R` fails when a test is in the wrong file or a file doesn't start with its skip (an argument
  check inside `expect_error()` may stay in the plain file: it fails before Chrome starts). A helper used only by one
  file's tests stays at the top of that file; one that several files need goes in `helper-<name>.R`, which loads for
  every test file.
- **house:** R CMD check on CI fails when the tests take longer than 180 s on Ubuntu with R release
  (`R-CMD-check.yaml`), so a pull request that makes the tests CRAN runs slower moves detailed tests to an
  `-extended.R` file or speeds them up (build a fixture once per file with `delayedAssign()`).
- **CRAN:** tests use only declared packages and guard Suggests (`skip_if_not_installed()`); no network; files go
  to `withr::local_tempdir()`; nothing is left behind; at most 2 cores (`tests/testthat.R` lowers `getOption("Ncpus")`,
  which testthat reads first, to two when a session has it higher).
- **house:** keep JS logic small and push decisions into R, where they can be unit-tested.
- **house:** each test file runs on its own: testthat runs the files in two processes at once
  (`Config/testthat/parallel`), in any order, so a file never relies on what another file set up or left behind.
