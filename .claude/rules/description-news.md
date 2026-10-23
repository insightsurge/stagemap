---
paths:
  - "DESCRIPTION"
  - "NEWS.md"
  - "cran-comments.md"
---

# DESCRIPTION, NEWS.md and cran-comments.md

Labels as in `r-code.md` (CRAN / house). Reasons and sources: `docs/standards.md`.

## DESCRIPTION
- **CRAN:** Title in Title Case, no final full stop, not "A package for" or "in R"; Description of two or more
  sentences that doesn't start with the package name or "This package"; software, package and API names in single
  quotes ('Shiny', 'Quarto', 'JavaScript'); functions as `fn()`; URLs in `<...>`.
- **CRAN:** `Authors@R` gives every author a role and names every copyright holder: Harsh Verma (`aut`, `cre`, `cph`),
  plus contributors (`ctb`). For third-party records, follow [the bundled-file copyright rule](bundled-files.md).
- **house:** `Language: en-GB` (British spelling in the docs); keep `Imports` minimal; only the package creator
  changes the version. **CRAN:** use a licence in CRAN's licence database; for MIT, use `MIT + file LICENSE` with
  the YEAR and COPYRIGHT HOLDER stub. Never edit the stub by hand.

## NEWS.md
- **house:** NEWS uses tidyverse style and supplies GitHub release notes. Every user-facing change adds a bullet in
  the same PR; internal changes (CI, refactors, tests) are left out unless users notice them.
- **house:** new bullets go under the top heading of `NEWS.md`. Version numbers, release headings and which change
  ships in which release are the package creator's: never change them in a feature PR. Never edit a released section.
  Each release heading uses `# stagemap x.y.z` so R can parse NEWS. Until the first release,
  keep `# stagemap 0.0.0.9000`:
  R's NEWS check finds no entries under a "development version" heading without a released version below it.
- **house:** one change per bullet, written for users, present tense, starting with the function or feature,
  ending with the issue or PR number: `` `stagemap()` gains a `direction` argument for top-to-bottom maps (#30).``
  Where one function has several changes, one bullet per function with indented sub-bullets for its arguments and
  details is allowed; mark experimental items with *Experimental*.
  Credit outside contributors (`(@user, #123)`). With more than a handful of bullets, group under
  `## Breaking changes` (first, saying what to change), `## New features`, `## Minor improvements and fixes`,
  alphabetical by function within a group.

## cran-comments.md (build-ignored)
- **CRAN:** test environments, "0 errors | 0 warnings | 1 note" (the "New submission" note, explained), any
  acronym (for example, API) explained, reverse dependencies (none for a first release).

## Breaking changes
- **house:** a public API change gets `breaking-change`, a NEWS entry and a deprecation first
  (`lifecycle::deprecate_warn()` for at least one release), unless the API is still before 0.1.0.

## Releases
- **house:** releases, CRAN submissions and their checklist belong to the package creator.
- **house:** patch releases contain compatible fixes, including fixes to experimental features. Minor releases add
  features and deprecations; before 1.0.0, announced breaking changes also use a minor release.
- **house:** keep deprecations for at least one release before removal. Tag a CRAN release after CRAN accepts it.
