# stagemap

<!-- badges: start -->
[![R-CMD-check](https://github.com/insightsurge/stagemap/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/insightsurge/stagemap/actions/workflows/R-CMD-check.yaml)
[![Development stage: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R code coverage](https://codecov.io/gh/insightsurge/stagemap/graph/badge.svg)](https://app.codecov.io/gh/insightsurge/stagemap)
<!-- badges: end -->

Relation maps for R: things placed by stage (columns) and, where it helps, by lane (rows), joined by links whose kind
means something, such as built, reviewed, tested by or depends on. The same data answers questions in code: trace a
node, find things with no link, check coverage, and see the impact of a change. Maps are meant for Shiny apps, Quarto
documents, slides and dashboards, and package websites, and as a static image for PowerPoint, Word and PDF.

**Status:** early development; `stagemap` is the working name. The package holds a placeholder function while the
real functions are designed, and is not on CRAN. Scope and plans:
[`docs/scope.md`](https://github.com/insightsurge/stagemap/blob/main/docs/scope.md).

The coverage badge counts the R code the tests run. The JavaScript engine that will draw the maps in the browser is
tested there and is not part of that figure.

## Installation

stagemap needs R 4.1.0 or later. Install the development version from GitHub.

```r
# install.packages("pak")
pak::pak("insightsurge/stagemap")
```

## Contributing

Open an issue with one of the issue forms before starting work. The contributing guide is in
[`.github/CONTRIBUTING.md`](https://github.com/insightsurge/stagemap/blob/main/.github/CONTRIBUTING.md).

## Licence

MIT © Harsh Verma.
