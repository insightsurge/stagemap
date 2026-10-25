# Contributing to stagemap

Thank you for helping with stagemap. It is an R package for relation maps: things placed by stage and lane, joined by
links whose kind means something, shown in Shiny apps, Quarto documents and pkgdown sites. It is in early development.
What is in scope, and what is not, is in
[`docs/scope.md`][scope].
To report a bug or suggest an idea, open an issue with one of the issue forms.

## Setup

- **R**: the current release is recommended. The package needs R 4.1 or later.
- **Dev packages**: from the package root, run `pak::local_install_dev_deps()` (or `devtools::install_dev_deps()`).
- **Air**, the formatter for R code: <https://posit-dev.github.io/air/>. Use version 0.11.0, the one CI uses.
- **Biome**, the formatter and linter for JavaScript and CSS in `inst/`: <https://biomejs.dev>. Use version 2.5.14.
- **The gate's packages**: devtools, roxygen2, lintr, spelling and jsonlite; also covr, callr and withr for the
  `tests` mode, and rcmdcheck, pkgbuild and processx for `full`. If one is missing, the gate stops and names it.
- **Google Chrome or Chromium**, for the shinytest2 tests.
- **Git worktrees**: if you use renv, it keeps a package project's library outside the repository, so in a worktree
  set `R_LIBS` to the path that `Rscript -e 'cat(.libPaths()[1])'` prints in the main checkout.

## Workflow

1. **Start with an issue**, using an issue form. State the goal and a "done when" checklist. One issue per piece of
   work; ask first if the change is large. Keep its description current when scope or decisions change, and add
   dated progress comments. Tick the items a PR delivers; say what stays open and where it went.
2. **Make a branch** from `main` for that issue.
3. **Commit with Conventional Commits**, short: `feat:`, `fix:`, `docs:`, `chore:`, `test:`, `ci:`, `refactor:`.
   Follow the [Public text rules][public-text].
4. **Open a pull request** using the [template][pr-template]. Keep the sections that apply.
   Follow its checks table for repeatable commands and put one-off observations in Notes.
5. **Suggest labels** in the pull request: one type (`enhancement`, `bug`, `documentation`, `chore`) and one or more
   `area: *`. The package creator applies them; the release notes are built from them.
6. **The package creator merges** once CI is green. Pull requests are squash-merged, so the pull request title
   becomes the commit message on `main`: keep it a Conventional Commit.

Update every text that describes what you changed, in the same pull request: help pages (through roxygen), articles,
the README, `NEWS.md` and the examples; workflow comments, `tools/README.md` and the rules files; and any other page,
function or file that describes the behaviour, including ones added later. It works both ways: if you edit an article,
guide or example, check that the help page still agrees. Search the repository for the old wording and list the search
terms in the pull request.

Changes reach `main` through pull requests, and a ruleset stops anyone from force-pushing to `main` or deleting it.
Never force-push, push to `main`, or use `--no-verify`. Never edit `renv/` or `LICENSE` by hand. Generated
documentation follows the [roxygen rules][roxygen].
CI on a pull request from a fork waits for a maintainer to approve the run. Leave "Allow edits by maintainers" on,
so a maintainer can fix a small thing (a typo or a failing format check) on your branch.

Stacked pull requests are fine. Base the second one on the branch below it, and say so in its description.

## Before you open a pull request

Run the gate from the package root:

```sh
Rscript tools/cran-gate.R          # fast: before every commit
Rscript tools/cran-gate.R tests    # tests and coverage: before a pull request that touches R/ or tests/
Rscript tools/cran-gate.R full     # everything, including the built tarball: before a release
```

The gate is a plain R script in `tools/`; it needs the packages listed under Setup. Modes, options and exit codes
are in [tools/README.md][gate].

- `fast` checks formatting (Air and Biome), that `man/` and `NAMESPACE` match the roxygen2 comments, lint, that every
  export has `@returns`, spelling, and `R CMD check --as-cran` without the tests.
- `tests` runs the tests once under covr with `NOT_CRAN=true`, so the Chrome tests run, and that run gives the
  coverage. Coverage must be at least 70%.
- The gate prints one `PASS`, `FAIL` or `SKIP` line for each step, then a summary, and keeps a run folder with one
  log per step (its path is printed). Open a log only for a failing step.
- Unknown words fail the spelling step: list them in your PR; the package creator adds agreed ones to
  `inst/WORDLIST`.
- The docs step runs `devtools::document()` and may update `man/`, `NAMESPACE` or `DESCRIPTION`. If it fails,
  review the regenerated files and commit them with the source; see the [roxygen rules][roxygen].
- If the gate itself gets something wrong, open an issue in mascot, where it is maintained ([CI rules][ci]).

CI requirements are in [the CI rules][ci]; local gate results do not replace CI.

## Code in short

The [standards][standards] explain the reasons and sources behind these rules.

- Check arguments with checkmate and use cli for messages; see the [R code rules][r-code].
- Call other packages with `pkg::fn()` and follow the [dependency rules][r-code].
- Write help and offline examples with roxygen2; regenerate help pages and NAMESPACE using the
  [documentation rules][roxygen].
- Keep JavaScript and CSS in `inst/` plain and readable. Bundle what the package needs; do not load anything from a
  CDN.
- Accessibility: meaning never rests on colour alone (a link kind also has its line style or mark). Honour
  `prefers-reduced-motion`.

## Tests

Tests use testthat in BDD style, one test file per R file (plus `-browser` and `-snap` files for the tests CRAN
skips), with coverage at least 70%: see the [test rules][tests].

## NEWS.md

Add one bullet for each user-facing change, in the same pull request. Write it for users, in the present tense, start
with the function or feature, and end with the issue number:

```md
* `sm_svg()` gains a `width` argument (#123).
```

Where new bullets go and what is left out: the [NEWS rules][newsmd]. Release headings and versions belong to the
package creator ([release rules][releases]).

## Licence of contributions

Contributions use the package's MIT licence. Before adding third-party files, follow the
[bundled-file rules][bundled-files].

## Conduct and data

Everyone taking part follows the [code of conduct][conduct]. Be kind and patient, and give feedback on
the work, not the person. For a security problem, do not open an issue; follow the [security policy][security].
For questions, use [Discussions](https://github.com/insightsurge/stagemap/discussions) rather than an issue.

Use the [Public text rules][public-text] for examples, data and screenshots.

[public-text]: https://github.com/insightsurge/stagemap/blob/main/AGENTS.md#public-text
[bundled-files]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/bundled-files.md
[ci]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/ci.md
[newsmd]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/description-news.md#newsmd
[releases]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/description-news.md#releases
[r-code]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/r-code.md
[roxygen]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/roxygen.md
[tests]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/tests.md
[scope]: https://github.com/insightsurge/stagemap/blob/main/docs/scope.md
[standards]: https://github.com/insightsurge/stagemap/blob/main/docs/standards.md
[conduct]: https://github.com/insightsurge/stagemap/blob/main/.github/CODE_OF_CONDUCT.md
[pr-template]: https://github.com/insightsurge/stagemap/blob/main/.github/pull_request_template.md
[security]: https://github.com/insightsurge/stagemap/blob/main/.github/SECURITY.md
[gate]: https://github.com/insightsurge/stagemap/blob/main/tools/README.md
