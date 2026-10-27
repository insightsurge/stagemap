# tests/

How the tests are organised, and where each kind runs. The rules (what to test, BDD style, skips, coverage) are in
`.claude/rules/tests.md`; what each CI workflow runs is in [`.github/workflows/README.md`](../.github/workflows/README.md).

## In brief

- CRAN runs the package's own tests, apart from the long, detailed ones.
- The tests CRAN skips live in files of their own, by kind: browser, snapshot and extended. CI runs all of them.
- `tests/testthat/test-helper-layout.R` fails when a test is in the wrong kind of file, so the layout can't drift.

## The four kinds of test file

One test file per R file (`R/layout.R` is tested in `tests/testthat/test-layout.R`), plus, when it has them:

| Kind | File | What goes in it | Its first line | Runs when |
|---|---|---|---|---|
| plain | `test-<name>.R` | the package's functions | (no skip) | always, CRAN included |
| browser | `test-<name>-browser.R` | anything that starts Chrome (shinytest2, chromote) | `skip_without_chrome()` | `NOT_CRAN` is true and Chrome is found |
| snapshot | `test-<name>-snap.R` | `expect_snapshot()` tests, and nothing else | (no skip, on purpose) | `NOT_CRAN` is true |
| extended | `test-<name>-extended.R` | long, detailed tests CRAN needn't run: many layout cases, every widget scenario | `skip_unless_extended()` | `NOT_CRAN` is true, or `EXTENDED_TESTS` is `"true"` |

- **First lines.** A browser or extended file skips from its first line, so CRAN skips the whole file before any of its
  code runs (a skip inside each test would come after the test had built what it needs). A snapshot file has no such
  line: skipped as a whole, it reports no snapshots, and testthat then deletes their saved files in `_snaps/`. Each
  `expect_snapshot()` skips itself on CRAN instead.
- **Helpers** live in `tests/testthat/helper-<name>.R`, which testthat loads before every file: `helper-extended.R`
  (`skip_unless_extended()`), `helper-chrome.R` (`skip_without_chrome()` and the shared Chromes), `helper-layout.R`
  (what the layout test reads). A helper used by one file only stays at the top of that file.
- **Apps** for shinytest2 are in `tests/testthat/apps/<name>/app.R`.

## Where each kind runs

| Where | plain | browser | snapshot | extended |
|---|---|---|---|---|
| CRAN, and R CMD check in CI | yes | | | |
| Coverage in CI, and the weekly extended-tests run on macOS and Windows | yes | | | yes |
| CI's off-CRAN job (with Chrome) | | yes | yes | yes |
| `devtools::test()` and the gate's `tests` mode, locally | yes | yes | yes | yes |

## Running the tests locally

- Everything: `Rscript tools/cran-gate.R tests` (with coverage), or `devtools::test()`; both set `NOT_CRAN` to true.
  The browser tests need Chrome or Chromium.
- As CRAN runs them: `NOT_CRAN=false Rscript -e 'testthat::test_local()'` (`devtools::test()` always sets `NOT_CRAN`
  to true). Add `EXTENDED_TESTS=true` to include the extended tests, as the coverage job does.
- One file: `devtools::test(filter = "layout")`.

## Keeping CRAN's share small

CRAN asks for examples, vignettes and tests to take under 10 minutes together. R CMD check in CI fails when the tests
take longer than 180 s on Ubuntu with R release. When a pull request gets near that limit, move detailed tests to an
extended file, or make the slow tests cheaper (build a fixture once per file with `delayedAssign()`, draw a page once
and reuse it).

## Adding tests for a new R file

1. Its tests in `test-<name>.R`, the plain file.
2. Long, detailed tests in `test-<name>-extended.R`, starting with `skip_unless_extended()`.
3. Its browser tests in `test-<name>-browser.R`, starting with `skip_without_chrome()`; its snapshot tests in
   `test-<name>-snap.R`.
4. Run `devtools::test(filter = "helper-layout")`: it fails when something is in the wrong file.
