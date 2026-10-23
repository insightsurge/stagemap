---
paths:
  - "inst/**"
---

# Files the package ships (inst/)

Labels as in `r-code.md` (CRAN / house). Reasons and sources: `docs/standards.md`.

- **CRAN:** the copyright of every shipped file is clear: `inst/COPYRIGHTS` lists each non-R file (path, source,
  copyright holder, licence); third-party holders also get a `cph` entry with a `comment` in `Authors@R`;
  contributed code also gets `ctb`.
- **CRAN:** if fonts are bundled, ship each font's licence beside it, including its copyright line; record its
  project in `inst/COPYRIGHTS` and with `cph` in `Authors@R`. For OFL fonts, keep `OFL.txt` and existing file names
  unless a Reserved Font Name applies to a modified font. **house:** use Latin-range WOFF2 subsets to keep size down.
  The drawing rules in [js-css.md](js-css.md) cover the use of the host page's font.
- **CRAN:** `inst/` must not use R's reserved names (`R`, `data`, `demo`, `exec`, `libs`, `man`, `help`, `html`,
  `Meta`, `src`); file names are ASCII, portable, without spaces or names differing only by case; paths are under
  100 bytes. The case used in code must match the file on disk: Linux is case-sensitive.
- **house:** the built tarball stays under 5 MB (CRAN: under 10 MB if possible); the gate's `full` mode checks the
  size and that every `inst/` file is in the tarball.

## Acceptance checklist for every new shipped file
- [ ] The file is in the built tarball (`Rscript tools/cran-gate.R full`, step `tarball`).
- [ ] It has the copyright and contributor records required [above](#files-the-package-ships-inst).
- [ ] It loads offline from the installed package (no network, no CDN).
- [ ] Its path is portable and case-correct, and it is referenced through `htmlDependency()` or `system.file()`.
