# How CI works here

Each file in this folder is one check. The check itself lives in the launchR repository and this file only says when
and where it runs, so it stays short. Nothing needs installing: GitHub runs these by itself.

| File | What it does | When it runs |
| --- | --- | --- |
| `r-cmd-check.yaml` | R CMD check, the core check | pull requests, pushes, Mondays at 05:17 UTC, by hand |
| `lint.yaml` | Check style, docs in sync and spelling | pull requests, pushes, by hand |
| `no-suggests.yaml` | Check the package works without its optional packages | pull requests, pushes, by hand |
| `secret-scan.yaml` | Catch passwords and tokens committed by mistake | pull requests, pushes |
| `coverage.yaml` | Measure how much code your tests run | pull requests, pushes, by hand |
| `full-tests.yaml` | Run every test, including the browser, snapshot and extended tests CRAN skips, with Chrome for browser tests | pull requests, pushes, Mondays at 05:17 UTC, by hand |
| `r-cmd-check-extended.yaml` | Run R CMD check on more systems, with the extended tests | Mondays at 05:17 UTC, by hand |
| `github-setup.yaml` | Create the labels and the stage checklists named in `DESCRIPTION` (`Config/launchR/checklists`) | a dry run when the file changes on `main`, by hand |
| `pkgdown.yaml` | `pkgdown::check_pkgdown()` and the website build, deployed to GitHub Pages; stagemap's own, not launchR's (locally: `Rscript tools/build-site.R`) | pushes to `main`, by hand |

These are the checks chosen when the package was set up. To add another later, come back to the site and choose only
that check.

## Test file kinds

Most tests run in every check. Files whose name ends in a kind run only where they can:

| File name ends in | What it holds | Runs in |
| --- | --- | --- |
| `-browser.R` | Tests that drive a browser (chromote); start them with `options(chromote.timeout = 60)`, as Chrome can start slowly on CI | `full-tests` |
| `-snap.R` | Snapshot tests (`expect_snapshot()`) | `full-tests` |
| `-extended.R` | Slow or detailed tests | `coverage`, `full-tests`, `r-cmd-check-extended` |

Start each browser file with `skip_on_cran()` and each extended file with
`skip_if_not(identical(Sys.getenv("EXTENDED_TESTS"), "true"))`, so CRAN and R CMD check skip them.

## Codecov

The coverage check decides on its own. To also show coverage on Codecov:

1. Sign in at <https://about.codecov.io> with GitHub and add this repository.
2. Copy its upload token. On GitHub, add it as a repository secret named `CODECOV_TOKEN` (Settings, then Secrets and
   variables, then Actions).
3. In `coverage.yaml`, remove the `#` before the `secrets:` and `CODECOV_TOKEN:` lines.

`codecov.yml` at the top of the package keeps Codecov to reporting: no blocking status and no second comment.

## Changing a check

- **Which branches or times:** edit the `on:` block at the top of the file. Times are UTC.
- **Which systems and R versions:** edit `platforms` under `with:`.
- **How long a job may run:** `timeout-minutes` under `with:`, in minutes. 0 keeps launchR's default: 60 on Mac (its
  minutes cost ten times), 120 elsewhere, 60 for coverage and 90 for no-suggests.
- **Older pull request runs:** a new push to a pull request stops the older run of each check, to save minutes. To let
  them finish, set `cancel-in-progress: false` in the file's `concurrency:` block.
- **Turn a check off:** delete its file.
- **Keep a check but run it only by hand:** keep only `workflow_dispatch:` under `on:`.
- **A secret-scan false alarm:** the scan uses launchR's rules, not a `.gitleaks.toml` in the package. Silence a false alarm
  with a `gitleaks:allow` comment on that line; a real secret must be removed and its key rotated. To clear a false alarm already in history, add its fingerprint
  line (in the scan's log, as `file:rule:line` or `commit:file:rule:line`) to `.gitleaksignore` in a pull request; it applies once
  merged. Keep `^\.gitleaksignore$` in `.Rbuildignore`, or R CMD check notes it as a hidden file.
- **The CI report comment:** each check that reports has `ci-report: true` under `with:`. Set it to `false` in every
  one of those files to leave the comment out; each run still shows its results on its own page under Actions.
- **Keep the `permissions:` block as it is:** a check that reports on pull requests needs what it lists, or it stops before it starts.

Scheduled runs use the default branch only, and GitHub pauses them on public repositories after 60 days with no activity.

## The time limit

`r-cmd-check` fails when the tests take longer than `test-time-limit` seconds on Linux with R release (180 by default;
0 turns it off). CRAN asks for quick checks. Move slow tests to a `-extended.R` file, or make them faster.

## Run the checks on your computer

The quality gate runs most of these checks locally: style, docs in sync, spelling, tests, coverage and R CMD check as
CRAN runs it. It needs these packages once:

```r
install.packages(c(
  "checkmate", "cli", "devtools", "jsonlite", "spelling", "roxygen2", "lintr",
  "callr", "covr", "withr", "testthat", "pkgbuild", "processx", "rcmdcheck", "pkgdown"
))
```

The style step also needs [Air](https://posit-dev.github.io/air/), and [Biome](https://biomejs.dev) when the package
has JS or CSS. A missing one is named in the first FAIL line; without pkgdown, the website step is skipped.

The new-lines check counts the lines a branch adds in `R/` only, not JS or CSS. The default `fast` mode does not run the
no-Suggests check, so an example that uses a Suggests package without guarding it passes there and fails in CI: when a
mode leaves it out, the run ends with a note saying so. When the spelling step fails, it prints the command that adds
the unknown words.

The snippet below downloads a script from the internet and runs it: check your organisation's policy first. It is the
quality gate released as launchR 0.0.19 ([its source](https://github.com/insightsurge/launchR/blob/v0.0.19/quality-gate/quality-gate.R)),
and CI on GitHub runs the same checks, so nothing is lost when local runs aren't allowed.

Then, from the package's folder, in R:

```r
gate <- tempfile(fileext = ".R")
download.file("https://raw.githubusercontent.com/insightsurge/launchR/v0.0.19/quality-gate/quality-gate.R", gate)
system2(file.path(R.home("bin"), "Rscript"), c(gate, "full"))
```

Use `fast` instead of `full` for a quicker run. It prints one PASS or FAIL line per step. It runs the extended tests
when `EXTENDED_TESTS` is `true`, which the package's `.Renviron` sets
(`tests/testthat/README.md`). On Windows, `full` skips the step that checks the package without its optional
packages, because symlinks may need extra privileges there; the
`no-suggests` check on GitHub runs it on Linux. The step also skips when an optional package is installed in R's
own library, where R on a Mac often installs every package; base and recommended packages such as `tools`
or `MASS` ship with R and don't count.

## Updates

Dependabot opens a pull request when launchR has a new minor or major version (`0.6.0`, `1.0.0`), and changes only
the `@v...` part of these files. Patch versions (`0.6.1`) arrive with the next minor version; to take one sooner,
change the `@v...` part yourself. Updates to other actions you add come in their own pull requests. Dependabot
opens the pull request as soon as it sees the release; to make it wait some days first, add a `cooldown` block to
`.github/dependabot.yml`.

- To decline one version, close the pull request.
- To stop for good, comment `@dependabot ignore this dependency` on it, or delete `.github/dependabot.yml`.

Your CI keeps working on the old version either way.

## Leaving launchR

To keep your own copy of the checks, for example if your organisation blocks outside workflows, run launchR's `eject`
command. The checks then live in this repository and nothing depends on launchR. "Run the checks on your computer"
above then uses the copy of the gate in `.launchr/`. From the package's folder, in R, this downloads launchR
0.0.19 and runs it:

```r
archive <- tempfile(fileext = ".tar.gz")
download.file("https://github.com/insightsurge/launchR/archive/refs/tags/v0.0.19.tar.gz", archive, mode = "wb")
folder <- tempfile()
untar(archive, exdir = folder)
launchr <- list.dirs(folder, recursive = FALSE)[1]
system2(file.path(R.home("bin"), "Rscript"), c(shQuote(file.path(launchr, "cli", "launchr.R")), "eject"))
```

Run it again with a newer launchR release to refresh the copies. In a clone of launchR, `Rscript cli/launchr.R eject`
does the same.
