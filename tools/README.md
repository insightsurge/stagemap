# tools/

Scripts for working on stagemap. None of them ship with the package (`tools/` is in `.Rbuildignore`).

| File or folder | What it is |
|---|---|
| `build-site.R` | Builds the pkgdown site into `site/` |
| `copy-kit.R` | Copies the stage-map engine into `inst/kit/` (see below) |

Run every script from the package root, for example `Rscript tools/build-site.R`.

## Updating the stage-map engine

The engine that draws a map (a script, a stylesheet, its contract, and the d3 library it draws with) ships in
`inst/kit/`. That folder is a generated copy: never edit a file in it, run the script again instead.

```
Rscript tools/copy-kit.R <path to the engine's checkout> [<date, YYYY-MM-DD>]
```

The argument is the engine's own checkout on your machine; nothing about it is written into the package. The script takes
a snapshot of the checkout's `origin/main` (after a fetch; uncommitted work in the checkout never gets in), runs the
engine's own freshness check, builds the engine under stagemap's names, checks the build against its checksums and
against the engine's own names, and writes the files and `inst/kit/kit.json` (engine version, source commit, date,
the sha256 of every file, the names). It needs `python3`, `git` and the `jsonlite` package. The date is the argument,
or else the commit's date, never the clock, so a second run on the same commit changes nothing (`git status` stays
clean). After a copy, run `gate fast` and `gate tests --filter kit`: `tests/testthat/test-kit.R` checks that the engine
still has every command, event and name the package relies on (the list is in `tests/testthat/helper-kit.R`; extend it
when stagemap starts to use another). A new copy also needs a look at `inst/COPYRIGHTS` when the engine takes in third-party
files. `biome.json` leaves `inst/kit/` as built: its override turns the formatter and the lint rules off for the folder instead
of excluding it, because Biome exits 1 ("No files were processed") when every file under `inst/` is excluded.

## The quality gate

The gate is launchR's (<https://github.com/insightsurge/launchR>), the same script CI's checks come from; stagemap keeps
no copy. Run it from the package root, either from a clone of launchR:

```
Rscript <launchR clone>/cli/launchr.R gate <mode>
```

or without a clone, as `.github/workflows/README.md` ("Run the checks on your computer") shows: it downloads the gate
at the launchR version the workflows use and runs it. It needs the packages listed there, plus Air and Biome.

### The gate in plain words

The gate runs a fixed list of checks and prints one line per check, then a verdict:

```
PASS air        (  1s)
FAIL lintr      ( 23s): 2 lints: R/x.R:12 ...
SKIP biome      (  0s): no JS or CSS in inst/ yet
```

A SKIP always says why. Every run keeps a **run folder** (its path is printed): one log per check, `gate.json` (every
check's result, the commit and the tool versions) and, after the tests, `tests.json` with every failing test. `flakes.tsv`, one level up (shared by every run), lists the tests
that failed and were re-run, with the outcome. The folder survives the gate. You never need
to re-run the gate just to find out what failed.

### Which mode when

| Mode | Run it | What it checks |
|---|---|---|
| `fast` (the default) | Before every commit | Formatting, lint, help pages in sync, a `\value` on every export, spelling, the pkgdown index, R CMD check without tests |
| `tests` | Before a PR that touches `R/` or `tests/` | The whole test suite (Chrome tests too) once under covr, coverage of at least 70%, and `new_lines`: every R line the branch adds since it left `origin/HEAD` (uncommitted work counts) is run by a test |
| `full` | Before a release | All of `fast` and `tests`, R CMD check with tests as CRAN runs it, the check without Suggests, and the package size |
| `lint` | For a quick style check, or to reproduce CI's lint job | The static checks only |
| `nosuggests` | When CI's no-Suggests job fails, or before a release | R CMD check with only the required packages, as CRAN also checks |

In short: `fast` while working, `tests` before a PR, `full` before a release.

### Options

| Option | Use it to | Merge evidence? |
|---|---|---|
| `--steps tests,coverage` | Run only some of the mode's checks, for example after an interrupted run | No: PARTIAL |
| `--filter layout` | Run only the test files whose names match, while fixing one test | PARTIAL: only for a small follow-up (below) |
| `--no-coverage` | Run the tests without covr, more quickly | No: PARTIAL |
| `--no-retry` | Skip the re-run of failing test files, to see the raw failure | Yes |
| `--out <folder>` | Put the run folders somewhere else (or set `QUALITY_GATE_OUT`) | Yes |
| `--list` | Show each mode's checks and which ones this package skips | Nothing runs |
| `--help` | Show every option and the exit codes | Nothing runs |
| `--update-wordlist` | Add the unknown words to `inst/WORDLIST`, only after the package creator agrees to them | Yes |

A **PARTIAL** run is useful while working, but on its own it isn't proof. Merge evidence is a full `tests` (or
`full`) run that exits with 0; a small follow-up that adds no `R/` lines may instead show `fast` and a `--filter` run
of the test files it touches ([test rules](../.claude/rules/tests.md)).

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Every check passed, or skipped with a reason |
| 1 | A check failed: its line says what to fix |
| 2 | The gate couldn't judge the package: a tool is missing or a setting is wrong |
| 3 | Only tests failed, and every one passed when re-run: probably a flake. Never merge evidence without the package creator's word |

In `tests` and `full` the suite runs once, under covr, and that one run gives both the test results and the coverage.
The run sets `TESTTHAT_IS_CHECKING`, as testthat's `test_check()` does under R CMD check, so the tests behave as they
do there (shinytest2, for one, then loads the installed package in its app processes instead of the source).
If covr itself fails after the suite has run (while merging what it measured, say), the coverage line FAILs with
covr's message and points to `tests.log`; the gate does not run the suite a second time to get a percentage.

When tests fail, the gate re-runs the failing files once in a fresh R session. When one broken thing (a closed
browser, say) fails many tests with the same message, the line names it once as a "cascade".

### The gate and CI

The workflows in `.github/workflows/` call launchR's checks at a fixed launchR version; the lint and no-Suggests checks
run this same gate. What each workflow runs and when, and which test files run where:
[`.github/workflows/README.md`](../.github/workflows/README.md).

### Changing the gate

The gate and the checks are maintained in launchR and never edited here: a problem or a new check goes to launchR as
an issue, and reaches stagemap when the workflows move to the next launchR version (Dependabot proposes it).
stagemap's own choices are the `Config/quality-gate/*` fields in `DESCRIPTION`, `.lintr`, `air.toml` and `biome.json`.

Details: `gate --help`. Rules: the "Quality gate" section of `AGENTS.md` and `.claude/rules/ci.md`.
