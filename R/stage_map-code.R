# The code that builds a map again: code_map() writes it from a map's parts (as map_parts() gives them), with the
# builders of R/code.R. Caller: stage_map_code().

#' The R code that builds a stage map
#'
#' Writes the R code that builds a [stage_map()] widget again: the tables as `data.frame()` calls, then the pipeline of
#' [stage_map()] and the `add_*()` functions. Run the code and you get a map that sends the same data to the engine,
#' and that [sm_trace()], [sm_orphans()] and [sm_missing()] answer in the same way.
#'
#' The code starts with `library(stagemap)`. A table that would not let the call that takes it fit on one line is
#' written first, as a variable named after its argument; the others are written in place. Lines keep to 80
#' characters, except where a single string or number is longer, as it is never cut. Only arguments that differ from
#' their defaults are written, and `stages` and `lanes` are left out when they are what [stage_map()] takes from the
#' cards. A column that holds only `NA` is not written: the map reads it as left out, so it is the one column
#' [stage_map_tables()] of the rebuilt map lacks. Text, numbers, `TRUE` and `FALSE`, factors and dates are written as
#' you would type them; a column of another class is written as its values inside `structure()`, with its attributes.
#'
#' The text is UTF-8, with every letter as it is. To save it so that it reads back the same in any locale, write the
#' bytes as they are and parse the file as UTF-8, as the example does: `writeLines(code, path, useBytes = TRUE)`, then
#' `eval(parse(path, encoding = "UTF-8"))`. ([source()] with `encoding = "UTF-8"` cannot read letters beyond ASCII in a
#' session whose locale is not UTF-8.) Text in the map that is not marked as UTF-8, such as a string typed in such a
#' session, is written as the session holds it. A matrix column comes back as the separate columns [data.frame()]
#' makes of it, and a raw column comes back without its names.
#'
#' @inheritParams stage_map_tables
#' @returns A character vector of class `stagemap_code`, one line of code per element; it prints as the code. A `map`
#'   that is not a [stage_map()] widget, or a map whose `hosted` option no argument of [stage_map()] gives, is an error
#'   of class `stagemap_error_widget`.
#' @family stage map
#' @examples
#' map <- stage_map(
#'   data.frame(id = c("a", "b"), label = c("Draft", "Review"), stage = c("w", "c"), lane = "docs"),
#'   title = "A small piece of work"
#' ) |>
#'   add_links(data.frame(from = "a", to = "b"))
#' code <- stage_map_code(map)
#' code
#' # Save it as a script, and run it to get the map back.
#' path <- tempfile(fileext = ".R")
#' writeLines(code, path, useBytes = TRUE)
#' again <- eval(parse(path, encoding = "UTF-8"))
#' class(again)
#' unlink(path)
#' @export
stage_map_code <- function(map) {
  structure(code_map(map_parts(map, call = rlang::current_env())), class = "stagemap_code")
}

#' @export
#' @noRd
format.stagemap_code <- function(x, ...) {
  as.character(unclass(x))
}

#' @export
#' @noRd
print.stagemap_code <- function(x, ...) {
  cli::cat_line(format(x, ...))
  invisible(x)
}

# The code of a map, as lines: `library(stagemap)`, a blank line, the tables written as variables (if any) and a blank
# line, then the pipeline. `parts` is `list(tables, args)` as map_parts() gives it; nothing here checks the data, so
# parts that do not build a map still give their code. A table is written in place when the call that takes it still
# fits on one line with it; otherwise the longest table in place becomes a variable (named as its argument), until the
# call fits or has no table in place. So a table whose `data.frame()` needs more than one line is always a variable.
code_map <- function(parts) {
  checkmate::assert_list(parts, names = "unique")
  checkmate::assert_list(parts$tables, types = "data.frame", names = "unique")
  checkmate::assert_list(parts$args, names = "unique")
  tables <- parts$tables
  args <- parts$args
  # stage_map() needs cards: parts without them are written with an empty table.
  tables$cards <- tables$cards %||% data.frame()
  calls <- code_map_calls(tables, args)
  # Which tables are variables: the call's line with its suffix, at its indent, must fit.
  variables <- character()
  for (i in seq_along(calls)) {
    repeat {
      node <- code_map_node(calls[[i]], tables, variables)
      line <- paste0(strrep(" ", calls[[i]]$indent), code_flat(node), calls[[i]]$suffix)
      inline <- setdiff(code_map_table_args(calls[[i]]), variables)
      if (nchar(line) <= code_width || length(inline) == 0L) {
        break
      }
      sizes <- vapply(inline, function(name) nchar(code_flat(code_frame(tables[[name]]))), integer(1))
      variables <- c(variables, inline[[which.max(sizes)]])
    }
  }
  variables <- intersect(map_table_names, variables)
  defined <- unlist(lapply(variables, function(name) {
    code_lines(code_frame(tables[[name]]), prefix = paste0(name, " <- "))
  }))
  pipeline <- unlist(lapply(calls, function(call) {
    code_lines(code_map_node(call, tables, variables), call$indent, suffix = call$suffix)
  }))
  c("library(stagemap)", "", if (length(defined) > 0L) c(defined, ""), pipeline)
}

# The calls of the pipeline, each `list(fn, args, indent, suffix)`: `args` is a named list ("" for a positional
# argument) whose values are values to write or `list(table = <name>)` for a table. Arguments equal to their
# function's default are left out, and so are layers with no rows. Caller: code_map(), which checked the parts.
code_map_calls <- function(tables, args) {
  has <- function(name) is.data.frame(tables[[name]]) && nrow(tables[[name]]) > 0L
  table <- function(name) list(table = name)
  derived <- function(column, name) {
    is.data.frame(tables[[name]]) &&
      identical(as.list(tables[[name]]), as.list(ids_from_cards(tables$cards, column)))
  }
  write_stages <- is.data.frame(tables$stages) && !derived("stage", "stages")
  write_lanes <- is.data.frame(tables$lanes) && !derived("lane", "lanes")
  map_args <- c(
    list(table("cards")),
    if (write_stages) list(table("stages")),
    if (write_lanes) stats::setNames(list(table("lanes")), if (write_stages) "" else "lanes")
  )
  names(map_args) <- names(map_args) %||% rep("", length(map_args))
  options <- args[setdiff(names(formals(stage_map)), c("cards", "stages", "lanes", "..."))]
  names(options) <- setdiff(names(formals(stage_map)), c("cards", "stages", "lanes", "..."))
  if (has("statuses")) {
    options$statuses <- table("statuses")
  }
  map_args <- c(map_args, code_map_given(options, stage_map))
  calls <- list(list(fn = "stage_map", args = map_args))
  if (has("links")) {
    links_args <- list(table("links"), kinds = if (has("kinds")) table("kinds"))
    calls <- c(calls, list(list(fn = "add_links", args = code_map_given(links_args, add_links))))
  }
  if (has("zones")) {
    calls <- c(calls, list(list(fn = "add_zones", args = list(table("zones")))))
  }
  if (has("steps")) {
    steps_args <- list(table("steps"), changes = if (has("changes")) table("changes"), intro = args$intro)
    calls <- c(calls, list(list(fn = "add_steps", args = code_map_given(steps_args, add_steps))))
  }
  if (has("variants")) {
    calls <- c(calls, list(list(fn = "add_variants", args = list(table("variants")))))
  }
  highlight <- args$highlight
  if (!is.null(highlight) && length(highlight$ids) > 0L) {
    lit <- list(highlight$ids, links = highlight$links)
    calls <- c(calls, list(list(fn = "stage_map_highlight", args = code_map_given(lit, stage_map_highlight))))
  }
  n <- length(calls)
  for (i in seq_len(n)) {
    names(calls[[i]]$args) <- names(calls[[i]]$args) %||% rep("", length(calls[[i]]$args))
    calls[[i]]$indent <- if (i == 1L) 0L else 2L
    calls[[i]]$suffix <- if (i < n) " |>" else ""
  }
  calls
}

# `args` without the named arguments that equal their default in `formals(fn)` (a number compares by value, so `1L`
# is the default `1`). Positional arguments (no name) stay. Caller: code_map_calls().
code_map_given <- function(args, fn) {
  checkmate::assert_list(args)
  checkmate::assert_function(fn)
  defaults <- formals(fn)
  arg_names <- names(args) %||% rep("", length(args))
  keep <- vapply(
    seq_along(args),
    function(i) {
      name <- arg_names[[i]]
      value <- args[[i]]
      if (!nzchar(name)) {
        return(TRUE)
      }
      default <- eval(defaults[[name]])
      if (is.null(value) || is.null(default)) {
        return(!is.null(value))
      }
      if (is.numeric(value) && is.numeric(default) && length(value) == 1L && length(default) == 1L) {
        return(!isTRUE(value == default))
      }
      !identical(value, default)
    },
    logical(1)
  )
  out <- args[keep]
  names(out) <- arg_names[keep]
  out
}

# The names of the tables a call takes.
code_map_table_args <- function(call) {
  checkmate::assert_list(call)
  tables <- vapply(call$args, function(value) if (code_map_is_table(value)) value$table else NA_character_, "")
  tables[!is.na(tables)]
}

# TRUE for a `list(table = <name>)` argument of a call.
code_map_is_table <- function(value) {
  is.list(value) && !is.data.frame(value) && identical(names(value), "table")
}

# A call of the pipeline as a node: a table in `variables` is its name, any other table its `data.frame()` call.
code_map_node <- function(call, tables, variables) {
  checkmate::assert_list(call)
  checkmate::assert_list(tables)
  checkmate::assert_character(variables, any.missing = FALSE)
  args <- lapply(call$args, function(value) {
    if (!code_map_is_table(value)) {
      return(code_value(value))
    }
    if (value$table %in% variables) code_atom(value$table) else code_frame(tables[[value$table]])
  })
  code_call(call$fn, args)
}
