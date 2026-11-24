#!/usr/bin/env Rscript
# Copies the stage-map engine into inst/kit/ and records what it copied: the package creator runs it.
#
#   Rscript tools/copy-kit.R <path to the engine's checkout> [<date, YYYY-MM-DD>]
#
# The checkout is the only argument that names the source; no path or name of it is written anywhere. The script:
#   1. fetches the checkout's remote and takes a snapshot of origin/main with `git archive` (never its working tree, so
#      uncommitted work cannot get in, and nothing in the checkout changes). The snapshot holds the kit, the build
#      tools, the library and registry.json: the build reads the map's contract from the library, so `kit` and `tools`
#      alone are not enough.
#   2. runs the engine's own freshness check on the snapshot (tools/build_stagemap.py --check);
#   3. builds the engine under this package's names (stage_map_names below);
#   4. checks the three built files against the build's own stage-map.sha256, and refuses a build that still holds a
#      trace of the names the engine is built from (read from the snapshot's default contract) or a home-folder path;
#   5. copies the four built files, the d3 library and the licences of the third-party files into inst/kit/ (the built
#      script holds icons from the Lucide set), and writes inst/kit/kit.json: the engine version, the source commit,
#      the date, every file with its sha256, and the names the build uses.
# The date is the argument, or else the commit's own date, never the clock, so running the script again on the same
# commit gives the same files. Files under inst/kit/ are never edited by hand: run this again instead. The tests in
# tests/testthat/test-kit.R check that the copy still has every name this package relies on.

# The names the engine is built under: the prefix of its attributes, tokens and events, its CSS class prefix, its
# JavaScript global and its product name.
stage_map_names <- list(prefix = "stagemap", css = "sm", who = "stagemap", product = "stagemap")
# The files the build writes, and the third-party files copied beside them from the snapshot.
built_files <- c("stage-map.js", "stage-map.css", "stage-map.json", "stage-map.sha256")
# Third-party files: the name in inst/kit/ = the path in the snapshot. LICENSE-lucide covers the icons the built script
# holds; the snapshot's icon licence also carries the notice of the set the icons grew from.
vendor_files <- c(
  "d3.min.js" = "kit/vendor/d3.min.js",
  "LICENSE-d3" = "kit/vendor/LICENSE-d3",
  "LICENSE-lucide" = "kit/icons/LICENSE"
)

fail <- function(msg) {
  checkmate::assert_string(msg)
  cli::cli_abort("{msg}", call = NULL)
}

sha256 <- function(path) {
  checkmate::assert_file_exists(path)
  tool <- Sys.which(c("shasum", "sha256sum"))
  tool <- tool[nzchar(tool)][1L]
  if (is.na(tool)) {
    fail("Neither shasum nor sha256sum is on the PATH.")
  }
  flags <- if (basename(tool) == "shasum") c("-a", "256") else character()
  out <- system2(tool, c(flags, shQuote(path)), stdout = TRUE)
  strsplit(out, " ", fixed = TRUE)[[1]][[1]]
}

# Runs a command and stops with its output when it exits non-zero; returns the output otherwise.
run <- function(command, args, what) {
  checkmate::assert_string(command)
  checkmate::assert_character(args)
  checkmate::assert_string(what)
  out <- suppressWarnings(system2(command, args, stdout = TRUE, stderr = TRUE))
  if (!is.null(attr(out, "status"))) {
    fail(paste0(what, " failed: ", paste(out, collapse = " ")))
  }
  out
}

# The lines of a checksum file, as a named vector: file name -> sha256.
read_sums <- function(path) {
  checkmate::assert_file_exists(path)
  lines <- strsplit(readLines(path, warn = FALSE), "  ", fixed = TRUE)
  stats::setNames(vapply(lines, `[[`, "", 1L), vapply(lines, `[[`, "", 2L))
}

# Stops when `text` (the lines of one built file) holds a trace of the names the engine is built from.
check_old_names <- function(text, file, old) {
  checkmate::assert_character(text)
  checkmate::assert_string(file)
  checkmate::assert_list(old)
  low <- tolower(text)
  for (word in tolower(c(old$prefix, old$product, old$global))) {
    if (nzchar(word) && any(grepl(word, low, fixed = TRUE))) {
      fail(paste0("The built ", file, " still holds the engine's own name \"", word, "\"."))
    }
  }
  # The class prefix is short, so it counts only where it starts a word ("-webkit-" holds "kit-" but is not a trace).
  if (any(grepl(paste0("(^|[^a-z0-9])", tolower(old$css), "-"), low))) {
    fail(paste0("The built ", file, " still holds the engine's class prefix \"", old$css, "-\"."))
  }
  if (any(grepl("/(Users|home)/", text))) {
    fail(paste0("The built ", file, " holds a home-folder path."))
  }
  invisible(TRUE)
}

copy_kit <- function(args) {
  checkmate::assert_character(args, max.len = 2L)
  if (length(args) < 1L || !nzchar(args[[1]])) {
    fail("Give the path to the engine's checkout as the first argument.")
  }
  source_dir <- normalizePath(args[[1]], mustWork = FALSE)
  if (!dir.exists(source_dir)) {
    fail(paste0("No such folder: ", source_dir))
  }
  root <- normalizePath(".")
  if (!file.exists(file.path(root, "DESCRIPTION")) || !dir.exists(file.path(root, "inst"))) {
    fail("Run this from the root of the package.")
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    fail("The jsonlite package is needed to write kit.json.")
  }
  if (!nzchar(Sys.which("python3")) || !nzchar(Sys.which("git"))) {
    fail("python3 and git are needed to build the engine.")
  }
  git <- function(...) run("git", c("-C", shQuote(source_dir), ...), "git")

  # 1. A snapshot of origin/main, from a fresh fetch.
  fetched <- suppressWarnings(system2("git", c("-C", shQuote(source_dir), "fetch", "-q"), stdout = TRUE, stderr = TRUE))
  if (!is.null(attr(fetched, "status"))) {
    cli::cli_warn("Could not fetch the checkout's remote; using the origin/main it already has.")
  }
  commit <- git("rev-parse", "--verify", "origin/main")
  commit_date <- if (length(args) >= 2L) args[[2]] else git("log", "-1", "--format=%cs", commit)
  if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", commit_date)) {
    fail(paste0("The date must look like 2026-12-31, not \"", commit_date, "\"."))
  }
  work <- tempfile("kit-copy-")
  dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  snap <- file.path(work, "snapshot")
  dir.create(snap)
  tarball <- file.path(work, "snapshot.tar")
  git("archive", paste0("--output=", shQuote(tarball)), commit, "kit", "tools", "library", "registry.json")
  utils::untar(tarball, exdir = snap)

  # 2. The engine's own check that its committed build is up to date.
  script <- shQuote(file.path(snap, "tools", "build_stagemap.py"))
  run("python3", c(script, "--check"), "The engine's own check")

  # 3. The build under this package's names.
  build <- file.path(work, "build")
  names_json <- as.character(jsonlite::toJSON(stage_map_names, auto_unbox = TRUE))
  run("python3", c(script, "--names", shQuote(names_json), "--out", shQuote(build)), "The engine's build")

  # 4. The build against its own checksums, and against the names it was built from.
  sums <- read_sums(file.path(build, "stage-map.sha256"))
  for (name in setdiff(built_files, "stage-map.sha256")) {
    if (!name %in% names(sums)) {
      fail(paste0("The built stage-map.sha256 has no line for ", name, "."))
    }
    if (!identical(sha256(file.path(build, name)), sums[[name]])) {
      fail(paste0("The built ", name, " does not match stage-map.sha256."))
    }
  }
  old <- jsonlite::read_json(file.path(snap, "kit", "stage-map", "stage-map.json"))
  old <- list(prefix = old$prefix, css = old$css, product = old$product, global = old$global)
  for (name in built_files) {
    check_old_names(readLines(file.path(build, name), warn = FALSE), name, old)
  }
  contract <- jsonlite::read_json(file.path(build, "stage-map.json"))
  if (!identical(contract$prefix, stage_map_names$prefix) || !identical(contract$css, stage_map_names$css)) {
    fail("The built contract does not carry the names asked for.")
  }
  d3_head <- readLines(file.path(snap, "kit", "vendor", "d3.min.js"), n = 1L, warn = FALSE)
  d3_version <- sub("^// https://d3js.org v([0-9.]+) .*$", "\\1", d3_head)
  if (identical(d3_version, d3_head)) {
    fail("The first line of d3.min.js does not give its version.")
  }

  # 5. The copy, and the record of it.
  dest <- file.path(root, "inst", "kit")
  unlink(dest, recursive = TRUE)
  dir.create(dest)
  from <- c(file.path(build, built_files), file.path(snap, vendor_files))
  to <- c(built_files, names(vendor_files))
  for (i in seq_along(from)) {
    if (!file.copy(from[[i]], file.path(dest, to[[i]]))) {
      fail(paste0("Could not copy ", to[[i]], "."))
    }
  }
  copied <- sort(to, method = "radix")
  missing <- setdiff(unlist(contract$files), list.files(dest))
  if (length(missing) > 0L) {
    fail(paste0("The contract lists files that were not copied: ", toString(missing), "."))
  }
  record <- list(
    engine = contract$version,
    commit = commit,
    date = commit_date,
    d3 = d3_version,
    files = as.list(copied),
    sha256 = stats::setNames(lapply(copied, function(name) sha256(file.path(dest, name))), copied),
    names = list(
      global = contract$global,
      prefix = contract$prefix,
      css = contract$css,
      product = contract$product,
      root_class = contract$root$class,
      root_attribute = contract$root$attribute
    )
  )
  jsonlite::write_json(record, file.path(dest, "kit.json"), auto_unbox = TRUE, pretty = TRUE, digits = NA)
  cli::cli_inform(
    "Copied the stage-map engine {contract$version} from {substr(commit, 1, 8)} ({commit_date}) into {.path inst/kit/}."
  )
  invisible(record)
}

copy_kit(commandArgs(trailingOnly = TRUE))
