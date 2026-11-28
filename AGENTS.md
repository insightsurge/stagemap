# stagemap

Rules for everyone working in this repository, person or AI. Edit each rule in its topic file below.

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
- [Documentation](.claude/rules/roxygen.md): roxygen2, examples, wording and website checks.
- [Tests](.claude/rules/tests.md): BDD, Shiny tests, CRAN skips and coverage.
- [JS and CSS](.claude/rules/js-css.md): drawing, theming and accessibility.
- [Bundled files](.claude/rules/bundled-files.md): licences and the acceptance checklist.
- [DESCRIPTION and NEWS](.claude/rules/description-news.md): metadata, change notes, breaking changes and releases.
- [CI](.claude/rules/ci.md): workflows and gate maintenance.

## Rules that always apply
- **CRAN:** 0 errors, warnings and notes; no network; write only to `tempdir()` or a user path; restore changed state;
  no load side effects; all assets in `inst/` (no CDN).
- **house:** check arguments with checkmate, use cli for messages and `pkg::fn()` for dependencies.
- **CRAN:** every export has `@returns` and offline `@examples`, written in roxygen2.
- **house:** BDD and Shiny tests, argument checks tested, coverage at least 70%.
- **house:** the engine is plain, unminified, deterministic JS/CSS in `inst/`; meaning never carried by colour alone;
  `prefers-reduced-motion` honoured.
- **house:** docs and UI use plain British English without hype, unmeasured numbers or version comparisons.
- **house:** add NEWS for user-facing changes; leave versions and releases to the package creator.

## Public text
Tracked files, commits, branch names, issues, pull requests and comments are public.
- **No AI attribution in commits, PR descriptions or comments:** commits use a person's own name and email, with no
  `Co-authored-by` naming an AI tool, session links or "Generated with" lines. If `git config user.name` or
  `user.email` names an AI tool, stop and say so before the first commit.
- Include no machine paths, pointers to untracked notes, names of private people or repositories, private links or
  credentials. Check output and screenshots too. Never name an employer, client or internal system.
- Use public examples and synthetic data; never real personal, patient or client data.
- Describe the work and checks, not who or what did them. Leave status lines such as "pushed as …" and
  "authorised to …" out of issues. Report check summaries without local library or temporary paths.
- Unknown spelling words fail the gate. List them in the report or PR; the package creator adds agreed words (gate
  `--update-wordlist`). Never edit `inst/WORDLIST` yourself or add a misspelling.

## Quality gate
Run the gate instead of calling `devtools::check()`, lintr or Air yourself;
[tools/README.md](tools/README.md) gives commands, modes, timing and exit codes.
- Evidence fits the change: a complete `tests` run that exits 0, or for a small follow-up the fast gate and the
  touched test files ([tests](.claude/rules/tests.md)); say plainly which checks failed or did not run.
- Format R with Air and JS/CSS with Biome; see [R formatting](.claude/rules/r-code.md#formatting)
  and [JS/CSS](.claude/rules/js-css.md).
- Never edit the gate or weaken a check to get CI green ([CI rules](.claude/rules/ci.md)).
- Never force-push, push to `main`, use `--no-verify`, or edit `NAMESPACE`, `man/`, `renv/` or `LICENSE` by hand.

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
  articles, README, NEWS, examples, `docs/`, the other READMEs, rules files) in the same pull request. Check an edited
  article or example against the help page too. Search for the old wording and list the search terms in the PR.

## Working as an agent
- Work only in the worktree or branch you were given. Don't commit, push, merge or open PRs unless the task says so.
- A self-reported pass never counts: the gate and CI are the evidence (and screenshots for visual work).
- Don't patch installed packages or mock dependencies to make a check pass.
