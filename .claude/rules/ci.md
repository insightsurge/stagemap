---
paths:
  - ".github/**"
  - "tools/**"
  - "codecov.yml"
---

# CI and the gate

Reasons and sources: `docs/standards.md`. What each workflow runs and when, which test files run where and how to run
the checks locally: `.github/workflows/README.md`. The gate: `tools/README.md`.

- The checks and the gate are launchR's (<https://github.com/insightsurge/launchR>). Each workflow in
  `.github/workflows/` (except `pkgdown.yaml`) only calls launchR's reusable workflow at a fixed launchR version and
  says when and where it runs; the lint and no-Suggests checks run launchR's gate. Neither the checks nor the gate are
  **ever edited here**: a problem or a new check goes to launchR as an issue, and reaches stagemap when the workflows
  move to the next launchR version (Dependabot proposes each new minor version). stagemap's choices live in the
  workflow files' inputs (platforms, time limits), `DESCRIPTION` (`Config/quality-gate/*`, `Config/launchR/*`),
  `air.toml`, `.lintr`, `biome.json` and `codecov.yml`.
- R CMD check runs on Windows and macOS (R release) and on Ubuntu (R devel, release, the previous release and 4.1, the
  oldest R in `DESCRIPTION`); the full and extended tests run on all three systems with R release. Change the lists
  in each workflow's `platforms` input.
- The checks run for pull requests into `main` and pushes to `main`, not for pull requests into other branches. Work
  merged into an integration branch is checked with the local gate; CI checks it when that branch's pull request into
  `main` opens.
- `pkgdown.yaml` is stagemap's own. The site is built **from `main` only, never on pull requests** (a site build may
  need packages that outside contributors' pull requests can't install). It deploys from `main` to GitHub Pages, which
  a private repository on the free plan cannot publish. Its job keeps the least permissions it needs, a
  `concurrency` group and a `timeout-minutes`; actions are pinned by major tag (Dependabot keeps them current).
- The tests run in two processes at once (`Config/testthat/parallel: true` in `DESCRIPTION`; two is testthat's default
  and CRAN's limit), and `tests/testthat.R` lowers a higher `Ncpus` to two. Never more than two. R CMD check notes
  CPU time over 2.5 times elapsed time, as CRAN does: keep the tests' ratio well below that.
- Never `continue-on-error`, never weaken a check to get green: fix the cause, or ask the package creator.
- The gate's `new_lines` step (every added `R/` line run by a test) needs the branch's base, which a shallow CI
  checkout lacks, so it runs locally.
