# The round trip of stage_map_code(): the code of a map, run, gives the map again. Callers: test-stage_map-code.R and
# test-stage_map-code-extended.R.

# `x` with the names of every named list sorted, at any depth: the engine reads an object's keys in any order, but the
# JSON keeps the order the R data had them in, which depends on the order the layers were added.
sorted_names <- function(x) {
  if (!is.list(x)) {
    return(x)
  }
  x <- lapply(x, sorted_names)
  if (is.null(names(x))) x else x[order(names(x))]
}

# The map that the code `code` builds: the code parses (as UTF-8, as `source(encoding = "UTF-8")` reads a saved
# file), starts with library(stagemap), and the rest runs in a clean environment whose parent is the package namespace
# (so the package need not be installed).
run_code <- function(code) {
  parsed <- parse(text = code, keep.source = FALSE, encoding = "UTF-8")
  testthat::expect_identical(parsed[[1]], quote(library(stagemap)))
  env <- new.env(parent = asNamespace("stagemap"))
  out <- NULL
  for (expr in parsed[-1]) {
    out <- eval(expr, env)
  }
  out
}

# Expects the code of `map` to build a map with the same data for the engine, the same size and id, and the same
# answers from sm_orphans() and sm_trace() (from the first card, both ways). `exact = TRUE` compares the JSON text with
# identical(); `exact = FALSE` compares it without nulls and with sorted names, for a map with a column of only NA (sent
# as null, and left out of the code) or one built with its layers in another order than the code writes them.
expect_code_rebuilds <- function(map, exact = TRUE) {
  code <- stage_map_code(map)
  testthat::expect_s3_class(code, "stagemap_code")
  rebuilt <- run_code(code)
  testthat::expect_s3_class(rebuilt, "stagemap_widget")
  if (exact) {
    testthat::expect_identical(rebuilt$x$data, map$x$data)
  } else {
    testthat::expect_identical(sorted_names(canonical(data_of(rebuilt))), sorted_names(canonical(data_of(map))))
  }
  testthat::expect_identical(rebuilt$width, map$width)
  testthat::expect_identical(rebuilt$height, map$height)
  testthat::expect_identical(rebuilt$elementId, map$elementId)
  testthat::expect_identical(sm_orphans(rebuilt), sm_orphans(map))
  first <- as_text(sm_widget_data(map)$cards$id[[1]])
  testthat::expect_identical(sm_trace(rebuilt, first, direction = "both"), sm_trace(map, first, direction = "both"))
  invisible(code)
}
