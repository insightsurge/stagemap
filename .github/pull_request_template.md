<!-- Delete the sections that don't apply and keep the rest short. Follow Public text and the contributor workflow:
https://github.com/insightsurge/stagemap/blob/main/AGENTS.md#public-text
https://github.com/insightsurge/stagemap/blob/main/.github/CONTRIBUTING.md#workflow
AGENTS.md indexes the matching rule files. -->

## In brief
<!-- One plain sentence on what changes and why, then a few bullets for a reader with no context. -->

Closes #

<!-- If this is stacked on another PR, name that PR and its base branch here. -->

## What's new
<!-- One bullet per capability: what a user can do, then the function, argument or file names. Delete if none. -->

## What's fixed
<!-- The symptom, its cause and the fix, in plain words, then the relevant function or file names. Delete if none. -->

## Before and after
<!-- A small example, table or screenshot showing the change. For instructions, a short wording example is enough.
Delete if nothing a user can see or run changes. -->

## Try it
<!-- Numbered scenarios: the R snippet or command to run, then what should happen.
For a visual change, give the browser and version and steps with reduced motion on and off.
Delete if nothing can be tried. -->

## Details
<!-- Only details needed to review the change. Include any changed defaults, compatibility or deprecation plan.
Delete if the sections above cover it. -->

## Not in this PR
<!-- Known limits and follow-ups, with public issue numbers where available. Delete if none. -->

## Checks
<!-- For each command you ran, report its result, exit code and any FAIL or SKIP summary lines.
Name checks you did not run and why. Do not mark an unrun check as passed.
Only repeatable checks belong in the table; one-off observations go in Notes below.
Choose checks and evidence using:
https://github.com/insightsurge/stagemap/blob/main/tools/README.md
https://github.com/insightsurge/stagemap/blob/main/.claude/rules/tests.md
Release checks belong to the package creator; a contribution does not require a release. -->

| Command | Result and exit code, or not run and why |
| --- | --- |
| `Rscript tools/cran-gate.R` | |
| `Rscript tools/cran-gate.R tests` (if `R/` or `tests/` changed) | |

<!-- Keep applicable items. Check only completed items; leave pending work unchecked.
For labels you cannot apply, list the suggested labels in Notes so the package creator can apply them. -->

- [ ] The linked issue's done-when checklist is met.
- [ ] Labels are set or suggested under [the workflow][workflow];
      [CI requirements][ci] are met.
- [ ] I have reviewed the whole diff, understand the changes and can explain the checks reported above.
- [ ] User-facing changes meet the [NEWS rules][newsmd].
- [ ] Behaviour and argument checks meet the [test rules][tests] and
      [R code rules][r-code].
- [ ] Public API changes meet the [breaking-change rule][api-changes].
- [ ] JS/CSS changes keep meaning off colour alone and honour reduced motion; the changed visual behaviour has been tried with reduced motion on and off.
- [ ] New shipped files meet the [acceptance checklist][bundled-files].
- [ ] Docs, exports and examples meet the [website checks][website].
- [ ] Every text that describes the changed behaviour is updated: help pages, articles, README, NEWS, examples; workflow comments, `tools/README.md`, `AGENTS.md`, `CLAUDE.md`, `.claude/`, `.github/CONTRIBUTING.md`, `docs/`; and any other page, function or file that describes it, including ones added later. Public instructions hold only contributor-facing guidance. Search terms used for the old wording: 

Notes: <!-- One-off observations, browser/OS versions, screenshots, labels, or spelling words for review.
Follow https://github.com/insightsurge/stagemap/blob/main/AGENTS.md#public-text. -->

[bundled-files]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/bundled-files.md
[ci]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/ci.md
[api-changes]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/description-news.md#breaking-changes
[newsmd]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/description-news.md#newsmd
[r-code]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/r-code.md
[website]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/roxygen.md#website
[tests]: https://github.com/insightsurge/stagemap/blob/main/.claude/rules/tests.md
[workflow]: https://github.com/insightsurge/stagemap/blob/main/.github/CONTRIBUTING.md#workflow
