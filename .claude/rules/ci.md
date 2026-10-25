---
paths:
  - ".github/**"
  - "tools/cran-gate.R"
  - "tools/test-cran-gate.R"
---

# CI and the gate

Reasons and sources: `docs/standards.md`. What each workflow runs, and the gate mode that reproduces it locally:
`tools/README.md` ("The gate and CI").

- The gate (`tools/cran-gate.R`) is the single source of the lint steps: CI's lint job runs it in `lint` mode, and
  the check-no-suggests job runs it in `nosuggests` mode.
  The script is a copy of mascot's (<https://github.com/insightsurge/mascot/tree/main/tools>) and is **never edited
  here**: a problem or a new check goes to mascot as an issue, and the new version is copied here after it merges.
  stagemap's choices live in `DESCRIPTION` (`Config/cran-gate/*`), `air.toml`, `.lintr` and `biome.json`.
- R-CMD-check fails on any note (`error-on: '"note"'`) and mimics CRAN (`NOT_CRAN: false`, so the browser tests
  skip; `setup-r` would set it to true); only the remote CRAN-incoming checks are off. The tests CRAN skips (browser and
  snapshot tests, in `test-*-browser.R` and `test-*-snap.R`) run in `browser-tests.yaml` on Linux with R release
  and R 4.1 (its summary job, `browser-tests`, is one stable check name for both). The coverage job runs the
  tests without Chrome (`NOT_CRAN: false`) and reads the coverage limit from `DESCRIPTION` (on a pull request, the higher of the base branch's and the PR's own, so a pull request cannot lower the limit by editing `DESCRIPTION`; changes to this workflow are reviewed like any other change). Keep
  `lint.yaml`'s Air and Biome versions equal to the local installs and `biome.json`'s schema.
- The site is built **from `main` only, never on pull requests** (a site build may need packages that outside
  contributors' pull requests can't install). It deploys from `main` to GitHub Pages.
- Every workflow: the least permissions it needs (`permissions: read-all`, or only the write scopes its jobs use), a
  `concurrency` group (with `cancel-in-progress`, except where a cancelled run on `main` would leave pushed commits
  unscanned or a release half done), a `timeout-minutes` on every job (a few times its longest recent run), Ubuntu pinned (`ubuntu-26.04`), actions by major tag (dependabot keeps them current), third-party actions
  outside `actions/` and `r-lib/` by commit SHA with a version comment.
- The CI report comment (`tools/README.md`): the `report` jobs in `test-coverage.yaml`, `browser-tests.yaml` and
  `lint.yaml` are the only jobs with `pull-requests: write`. They run no R and no code from the parts, only the
  composite actions in `.github/actions/`, which stay generic (copied from mascot; they are to move to a shared
  repository later). A new part: write it with `pr-report-part`, add its workflow to `.github/pr-report.json` and give
  that workflow a `report` job like the others. No `workflow_run` workflow: it runs only from `main`, so the pull
  request that changes it can't try it.
- Keep new jobs on Ubuntu unless the platform is the point (macOS minutes count 10x, Windows 2x).
- The tests run in two processes at once (`Config/testthat/parallel: true` in `DESCRIPTION`; two is testthat's
  default and CRAN's limit). R CMD check and the coverage job get two because their tests run without the site
  profile where `setup-r` sets `Ncpus`; `browser-tests.yaml` sets setup-r's `Ncpus: 2`, because setup-r's default of 1
  means one process. Never more than two. On CRAN, testthat takes the number of workers from `getOption("Ncpus")`,
  then `TESTTHAT_CPUS`, then two. R CMD check notes CPU time over 2.5 times elapsed time, as CRAN does
  (`_R_CHECK_TEST_TIMING_CPU_TO_ELAPSED_THRESHOLD_`): read the tests' CPU and elapsed times in its output and keep the
  ratio well below that.
- Never `continue-on-error`, never weaken a check to get green: fix the cause, or ask the package creator.
- A new check goes into the gate in mascot first (with its self-test probe there), then reaches stagemap with the
  next copy.
- The gate's `new_lines` step (every added `R/` line run by a test) has no CI job: it needs the branch's base, which a
  shallow CI checkout lacks, so it SKIPs there and runs locally.
