# stagemap

Rules for everyone working in this repository, person or AI. Codex and Antigravity (agy) read this file
directly; Claude imports it from `CLAUDE.md`. Edit each rule in its topic file below.

An R package for **relation maps**: things placed by stage (columns) and, where it helps, by lane (rows), joined by
links whose kind means something, with R functions that trace and check the map. Maps show in Shiny apps, Quarto
documents and pkgdown sites, and as a static image. Scope: `docs/scope.md`. Status: early development (`stagemap` is
the working name); not on CRAN. The author, maintainer and copyright holder (the **package creator**) is Harsh Verma;
`Authors@R` in `DESCRIPTION` is the source for names and roles.

## Rules: where they live
Working rules live in `.claude/rules/`; [standards](docs/standards.md) gives reasons and sources. Claude loads
matching rule files automatically. Other agents must read them before starting. Before creating a file in `R/`,
`tests/`, `inst/` or `.github/`, read its rule file too: a new file does not trigger automatic loading.
Labels and exceptions are explained in [R code](.claude/rules/r-code.md).
- [R code](.claude/rules/r-code.md): arguments, messages, dependencies, behaviour and names.
- [Documentation](.claude/rules/roxygen.md): roxygen2, examples and wording.
- [Tests](.claude/rules/tests.md): BDD, Shiny tests, CRAN skips and coverage.
- [JS and CSS](.claude/rules/js-css.md): drawing, theming and accessibility.
- [Bundled files](.claude/rules/bundled-files.md): licences and the acceptance checklist.
- [DESCRIPTION and NEWS](.claude/rules/description-news.md): metadata, change notes and releases.
- [CI](.claude/rules/ci.md): workflows and gate maintenance.

## Rules that always apply
- **CRAN:** 0 errors, warnings and notes; no network; write only to `tempdir()` or a user path; restore changed state;
  no load side effects; all assets ship in `inst/` (no CDN). See [R rules](.claude/rules/r-code.md#behaviour).
- **house:** check arguments with checkmate, use cli for messages and `pkg::fn()` for dependencies;
  [R rules](.claude/rules/r-code.md) include the checked-input exception.
- **CRAN:** every export has `@returns` and offline `@examples`, written in roxygen2; `man/` and `NAMESPACE` come from
  `devtools::document()`, never from hand edits.
  See [documentation](.claude/rules/roxygen.md).
- **house:** use BDD and Shiny tests, test argument checks and keep coverage at least 70%.
  See [tests](.claude/rules/tests.md) for structure, skips and added-line coverage.
- **house:** the engine is plain, unminified JS/CSS in `inst/`, deterministic (no randomness, no clock), meaning never
  carried by colour alone, and `prefers-reduced-motion` honoured.
- **house:** docs and UI use plain British English without hype, unmeasured numbers or version comparisons;
  see [wording](.claude/rules/roxygen.md#wording).
- **house:** add NEWS for user-facing changes; leave versions and releases to the package creator.
  See [NEWS](.claude/rules/description-news.md#newsmd).

## Public text
Tracked files, commits, branch names, issues, pull requests and comments are public.
- **No AI attribution in commits, PR descriptions or comments:** commits use a person's own name and email; no
  `Co-authored-by` naming an AI tool, session or conversation links, or "Generated with" lines.
- Include no machine paths, pointers to untracked notes, names of private people or repositories, private links or
  credentials. Check output and screenshots too. Never name an employer, client or internal system.
- Use public examples and synthetic data; never real personal, patient or client data.
- Describe the work and checks, not who or what did them. Leave status lines such as "pushed as …" and
  "authorised to …" out of issues. Report check summaries without local library or temporary paths.
- Unknown spelling words fail the gate. List unknown words in the report or PR; never edit `inst/WORDLIST` yourself.
  The package creator adds agreed words (gate `--update-wordlist`); never add a misspelling.

## Quality gate
Run the gate instead of calling `devtools::check()`, lintr or Air yourself;
[tools/README.md](tools/README.md) gives commands, modes, timing and exit codes.
- Evidence fits the change: a complete `tests` run that exits 0, or for a small follow-up the fast gate and the
  touched test files ([tests](.claude/rules/tests.md)); say plainly which checks failed or did not run.
- Format R with Air and JS/CSS with Biome; see [R formatting](.claude/rules/r-code.md#formatting)
  and [JS/CSS](.claude/rules/js-css.md).
- The gate is maintained upstream and never edited here; see [maintenance](.claude/rules/ci.md).
- CI must be green; never weaken checks. See [CI rules](.claude/rules/ci.md).
- Never force-push, push to `main`, use `--no-verify`, or edit `NAMESPACE`, `man/`, `renv/` or `LICENSE` by hand.

## Breaking changes
Public API changes need a label, NEWS and deprecation, with the pre-0.1.0 exception in
[breaking changes](.claude/rules/description-news.md#breaking-changes).

## Website
Build and check pkgdown for docs, exports or examples, view light and dark, and use full GitHub URLs for `docs/`;
see [website checks](.claude/rules/roxygen.md#website).

## Workflow
Start with an issue and its branch. Use Conventional Commits, the PR template and the required labels.
CI green, then **the package creator merges**. Changes reach `main` only through pull requests; a ruleset blocks
force-pushes to `main` and its deletion. See the [workflow](.github/CONTRIBUTING.md#workflow).

## Issues and pull requests
- When a decision changes an issue's plan, edit its description; add dated comments for progress. A PR ticks the
  boxes it delivers and says which stay open ([workflow](.github/CONTRIBUTING.md#workflow)).
- Report checks in the PR template's [Checks](.github/pull_request_template.md#checks) table, as summary lines
  without local paths.
- **Docs follow behaviour:** a change to how something works updates every text that describes it (help pages,
  articles, README, NEWS, examples, `docs/`, `tools/README.md`, workflow comments, rules files, and any other page,
  function or file that describes the behaviour, including ones added later) in the same pull request. It works both
  ways: an edited article or example is checked against the help page. Search for the old wording and list the search
  terms in the pull request.

## Working as an agent
- Work only in the worktree or branch you were given. Don't commit, push, merge or open PRs unless the task says
  so; never force-push.
- Before the first commit, check `git config user.name` and `user.email`: if they name an AI tool, stop and say so.
- Before reporting done, follow the [gate requirements](tools/README.md) and
  [test evidence rules](.claude/rules/tests.md); report skipped checks and reasons.
  A self-reported pass never counts: the gate and CI are the evidence (and screenshots for visual work).
- List unknown words in your report or PR; never edit `inst/WORDLIST` yourself. The package creator adds agreed words.
- Don't patch installed packages or mock dependencies to make a check pass.
