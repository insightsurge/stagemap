# Run by hand, from the package root, before going public and before every release:   Rscript tools/check-release.R
#
# It fails (exit 1, one line for each problem) when
#   - a file in inst/kit/ is missing or does not match the sha256 that inst/kit/kit.json recorded for it, or
#   - the package's public text names the project the stage-map engine is built from: README.md, DESCRIPTION, NEWS.md,
#     _pkgdown.yml, R/, man/, vignettes/, everything in inst/kit/, inst/COPYRIGHTS, tools/ and .github/, or
#   - the maintainer address in DESCRIPTION is a noreply address, or
#   - DESCRIPTION has no URL or BugReports, _pkgdown.yml has no url, or one of those links does not load, or
#   - a file still has an open founder placeholder (the public text above, cran-comments.md and the licence files).
# The links are fetched only once the repository is public: while GitHub does not serve the repository's page, the check
# prints a SKIP line, and a release needs the run in which no link was skipped.
# It is not part of the test suite, so the normal tests never skip and a work-in-progress copy passes them; it is the
# release gate's check.

stop_if_missing <- function(path) {
  if (!file.exists(path)) {
    stop("Run this from the package root: ", path, " is missing.", call. = FALSE)
  }
}
stop_if_missing("DESCRIPTION")
stop_if_missing("inst/kit/kit.json")
kit <- jsonlite::read_json("inst/kit/kit.json")
problems <- character()

sha256 <- function(path) {
  tool <- Sys.which(c("shasum", "sha256sum"))
  tool <- tool[nzchar(tool)][1L]
  if (is.na(tool)) {
    stop("Neither shasum nor sha256sum is on the PATH.", call. = FALSE)
  }
  args <- c(if (basename(tool) == "shasum") c("-a", "256"), shQuote(path))
  strsplit(system2(tool, args, stdout = TRUE), " ", fixed = TRUE)[[1]][[1]]
}
for (file in unlist(kit$files)) {
  path <- file.path("inst/kit", file)
  if (!file.exists(path)) {
    problems <- c(problems, sprintf("%s is missing.", path))
  } else if (!identical(sha256(path), kit$sha256[[file]])) {
    problems <- c(problems, sprintf("%s does not match the sha256 in kit.json.", path))
  }
}
# A file in inst/kit/ that kit.json does not list was not made by the copy script.
unlisted <- setdiff(
  list.files("inst/kit", recursive = TRUE, all.files = TRUE),
  c(unlist(kit$files), "kit.json")
)
for (file in unlisted) {
  problems <- c(problems, sprintf("inst/kit/%s is not listed in kit.json.", file))
}

public <- c(
  "README.md",
  "DESCRIPTION",
  "NEWS.md",
  "_pkgdown.yml",
  list.files(
    c("R", "man", "vignettes", "inst/kit", "tools", ".github"),
    recursive = TRUE,
    full.names = TRUE,
    all.files = TRUE
  ),
  "inst/COPYRIGHTS"
)
project <- paste0("atl", "as") # written in two pieces so this file does not name it in one
for (path in public[file.exists(public)]) {
  hits <- grep(project, readLines(path, warn = FALSE, encoding = "UTF-8"), ignore.case = TRUE)
  if (length(hits)) {
    problems <- c(problems, sprintf("%s names the engine's source project on %d line(s).", path, length(hits)))
  }
}

# CRAN mails the maintainer address, and GitHub's noreply addresses cannot receive mail.
if (any(grepl("noreply", readLines("DESCRIPTION", warn = FALSE), fixed = TRUE))) {
  problems <- c(problems, "DESCRIPTION has a noreply maintainer address; CRAN needs one that can receive mail.")
}

# CRAN wants public links, and --as-cran fetches them. Each link in URL and BugReports, and the site's url in
# _pkgdown.yml, is fetched here and must load.
description <- read.dcf("DESCRIPTION", fields = c("URL", "BugReports"))
links <- character()
for (field in colnames(description)) {
  if (is.na(description[1, field]) || !nzchar(trimws(description[1, field]))) {
    problems <- c(problems, sprintf("DESCRIPTION has no %s.", field))
  } else {
    links <- c(links, trimws(strsplit(description[1, field], "[,[:space:]]+")[[1]]))
  }
}
site <- sub("^url:[[:space:]]*", "", grep("^url:", readLines("_pkgdown.yml", warn = FALSE), value = TRUE))
site <- trimws(sub("[[:space:]]+#.*$", "", site)) # drop a trailing comment
if (!length(site)) {
  problems <- c(problems, "_pkgdown.yml has no url.")
}
status_of <- function(link) {
  tryCatch(
    as.integer(attr(curlGetHeaders(link, redirect = TRUE, timeout = 20L), "status")),
    error = function(e) NA_integer_
  )
}
links <- unique(c(links[nzchar(links)], site))
repository <- grep("^https://github[.]com/[^/]+/[^/]+/?$", links, value = TRUE)[1L]
links_skipped <- FALSE
if (is.na(repository)) {
  problems <- c(problems, "DESCRIPTION's URL has no GitHub repository link.")
} else if (!identical(status_of(repository), 200L)) {
  links_skipped <- TRUE
  writeLines(sprintf(
    "SKIP: %s does not load, so the repository is not public yet and no link was fetched.",
    repository
  ))
} else {
  for (link in links) {
    status <- status_of(link)
    if (!identical(status, 200L)) {
      problems <- c(
        problems,
        sprintf(
          "%s does not load (%s); make the repository and the site public.",
          link,
          if (is.na(status)) "no answer" else status
        )
      )
    }
  }
}

# A placeholder for a decision the founder has yet to make must be gone before a release.
open_items <- c(
  public,
  "cran-comments.md",
  "LICENSE",
  "LICENSE.md"
)
placeholder <- paste0("TODO", "(founder)") # in two pieces, so this file does not carry the placeholder
for (path in open_items[file.exists(open_items)]) {
  if (any(grepl(placeholder, readLines(path, warn = FALSE, encoding = "UTF-8"), fixed = TRUE))) {
    problems <- c(problems, sprintf("%s still has a %s.", path, placeholder))
  }
}

if (length(problems)) {
  writeLines(paste0("NOT READY: ", problems))
  quit(status = 1L)
}
writeLines(paste0(
  "Release check passed: the files in inst/kit/ match kit.json and no public text names the engine's source project",
  if (links_skipped) " (links not fetched: see the SKIP line above)." else ", and every link loads."
))
