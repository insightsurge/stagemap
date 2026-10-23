---
paths:
  - "R/**/*.R"
  - "man/**"
  - "NAMESPACE"
---

# Documentation (roxygen2)

Labels as in `r-code.md` (CRAN / house). Reasons and sources: `docs/standards.md`.

- **house:** roxygen2 with markdown (`Roxygen: list(markdown = TRUE)`); never edit `man/` or `NAMESPACE` by hand.
  Run `devtools::document()` after any roxygen change and commit `man/` and `NAMESPACE` with it (the gate's
  `docs` step fails when they are stale).
- **CRAN (reviewers):** every exported function (every Rd page with a usage) has `@returns`, including functions
  called for side effects ("Called for its side effect; returns `x` invisibly.").
  The gate's `value` step checks exports for it.
- **CRAN:** every export has `@examples` that run offline in a few seconds. Apps and anything that opens a browser
  go under `@examplesIf interactive()`; no `\dontrun{}` for code that can run; `\donttest{}` only for slow but
  correct examples, with a comment. Unwrap examples that take under five seconds. Examples that write files use
  `tempdir()` and clean up.
- **CRAN:** `@param` for every argument (R CMD check warns otherwise); say the type, the default's meaning and what
  `NULL` means.
- **house:** internal functions use `@noRd` (documented in the source, no help page). Reuse parameter docs with
  `@inheritParams`; group related exports with `@family`; link with `[fn()]`.
- **house:** the package-level page lives in `R/stagemap-package.R`, with the only `@importFrom` lines.
- **CRAN:** titles in sentence case without a final full stop; software names in single quotes in DESCRIPTION
  ('Shiny', 'Quarto'), and in backticks or links in Rd.

## Wording
- **house:** use plain British English in docs; no hype, unmeasured numbers, or claims that the package is
  "validated" or "GxP compliant". Describe the package as it is now; avoid comparisons with earlier versions
  ("redesign", "the new layout", "v2") in names, comments and docs.
  For privacy and spelling, follow [Public text](../../AGENTS.md#public-text).

## Website
- **house:** build with `Rscript tools/build-site.R` into `site/`; the build excludes `CLAUDE.md` and `AGENTS.md`.
  Before a PR changing docs, exports or examples, run the build and `pkgdown::check_pkgdown()`, then view the site in
  light and dark. Link to `docs/` files with full GitHub URLs: they are not part of the site.
