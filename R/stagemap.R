#' Build a map from nodes and links
#'
#' Build and check the data for a relation map. Extra columns are kept unchanged.
#'
#' @param nodes A data frame with at least one row. Required character or factor
#'   columns are `id` (unique, non-missing, non-empty node ids) and `stage` (the
#'   non-missing stage for each node). Optional character or factor columns are
#'   `label` (missing labels default to `id`), `lane` (the non-missing lane for
#'   each node), `group` (node groups) and `status` (node badges). Missing groups and
#'   statuses mean no group or badge. Factor stages and lanes retain their levels.
#' @param links A data frame with character or factor columns `from` and `to`
#'   naming existing node ids. Self-links are not allowed. Optional columns are
#'   `kind` (defaults to `"link"` when absent; missing values are not allowed) and
#'   `label` (missing labels are allowed). Duplicate links with the same `from`,
#'   `to` and `kind` are dropped with a warning. `NULL`, the default, means no links.
#' @param ... For `stagemap()`, must be empty: set meaning with the `sm_*()`
#'   functions. Not used by `format()` and `print()`.
#' @param x A `stagemap` object to format or print.
#' @returns `stagemap()` returns a `stagemap` object holding the checked nodes and
#'   links; print it for a summary. `format()` returns the summary as a character
#'   vector. `print()` writes it and returns `x` invisibly.
#' @export
#' @examples
#' nodes <- data.frame(
#'   id = c("REQ-1", "REQ-2", "TST-1", "RES-1"),
#'   stage = c("Requirement", "Requirement", "Test", "Result"),
#'   lane = c("Safety", "Usability", "Safety", "Safety"),
#'   group = c("Safety", "Usability", "Safety", "Safety"),
#'   status = c("pass", "missing", "pass", "fail")
#' )
#' links <- data.frame(
#'   from = c("REQ-1", "TST-1"),
#'   to = c("TST-1", "RES-1"),
#'   kind = c("verifies", "produces")
#' )
#' map <- stagemap(nodes, links)
#' format(map)
#' print(map)
stagemap <- function(nodes, links = NULL, ...) {
  with_stagemap_asserts({
    if (missing(nodes)) {
      cli::cli_abort("{.arg nodes} is missing; supply a nodes data frame.", class = "stagemap_error")
    }
    checkmate::assert_data_frame(nodes, min.rows = 1)
    checkmate::assert_data_frame(links, null.ok = TRUE)
  })
  if (...length() > 0L) {
    abort_dots(
      names(substitute(list(...)))[-1L],
      ...length(),
      character(0),
      environment(),
      "stagemap",
      c("nodes", "links")
    )
  }
  if (is.null(links)) {
    links <- data.frame(from = character(), to = character(), kind = character(), label = character())
  }
  check_required_columns(nodes, "nodes", c("id", "stage"), environment())
  check_required_columns(links, "links", c("from", "to"), environment())
  nodes <- check_map_columns(nodes, "nodes", c("id", "stage", "label", "lane", "group", "status"), environment())
  links <- check_map_columns(links, "links", c("from", "to", "kind", "label"), environment())
  bad <- which(is.na(nodes$id))
  if (length(bad)) {
    abort_rows(bad, "nodes", "id", "a missing")
  }
  bad <- which(!nzchar(trimws(nodes$id)))
  if (length(bad)) {
    abort_rows(bad, "nodes", "id", "an empty")
  }
  bad <- which(duplicated(nodes$id) | duplicated(nodes$id, fromLast = TRUE))
  if (length(bad)) {
    abort_rows(bad, "nodes", "id", "a duplicated", unique(nodes$id[bad]), value_label = "Duplicated ids")
  }
  for (column in c("stage", intersect("lane", names(nodes)))) {
    bad <- which(is.na(nodes[[column]]))
    if (length(bad)) {
      abort_rows(bad, "nodes", column, "a missing")
    }
    bad <- which(!nzchar(trimws(as.character(nodes[[column]]))))
    if (length(bad)) abort_rows(bad, "nodes", column, "an empty")
  }
  if (!"label" %in% names(nodes)) {
    nodes$label <- nodes$id
  }
  nodes$label[is.na(nodes$label)] <- nodes$id[is.na(nodes$label)]
  for (column in c("from", "to")) {
    bad <- which(is.na(links[[column]]))
    if (length(bad)) {
      abort_rows(bad, "links", column, "a missing")
    }
  }
  for (column in c("from", "to")) {
    bad <- which(!links[[column]] %in% nodes$id)
    if (length(bad)) {
      abort_rows(
        bad,
        "links",
        column,
        "an unknown node id in column",
        links[[column]][bad],
        value_label = "Unknown ids"
      )
    }
  }
  bad <- which(links$from == links$to)
  if (length(bad)) {
    abort_rows(
      bad,
      "links",
      NULL,
      "a node to itself",
      links$from[bad],
      value_label = "Node ids",
      verb = c("joins", "join")
    )
  }
  if (!"kind" %in% names(links)) {
    links$kind <- rep("link", nrow(links))
  }
  bad <- which(is.na(links$kind))
  if (length(bad)) {
    abort_rows(bad, "links", "kind", "a missing")
  }
  bad <- which(!nzchar(trimws(links$kind)))
  if (length(bad)) {
    abort_rows(bad, "links", "kind", "an empty")
  }
  if (!"label" %in% names(links)) {
    links$label <- rep(NA_character_, nrow(links))
  }
  bad <- which(duplicated(links[c("from", "to", "kind")]))
  if (length(bad)) {
    cli::cli_warn(
      paste(
        "{row_text(bad)} of {.arg links} {if (length(bad) == 1L) 'duplicates an earlier link' else",
        "'duplicate earlier links'} (same {.field from}, {.field to} and {.field kind}); dropped."
      ),
      class = c("stagemap_warning_duplicate", "stagemap_warning")
    )
    links <- links[-bad, , drop = FALSE]
  }
  node_columns <- c("id", "stage", "label", intersect(c("lane", "group", "status"), names(nodes)))
  nodes <- nodes[c(node_columns, setdiff(names(nodes), node_columns))]
  links <- links[c("from", "to", "kind", "label", setdiff(names(links), c("from", "to", "kind", "label")))]
  rownames(nodes) <- NULL
  rownames(links) <- NULL
  new_stagemap(nodes, links)
}

#' Internal map contract for layout, drawing and trace functions
#'
#' Later functions use resolve_stages(), resolve_lanes(), resolve_kinds(),
#' resolve_groups() and resolve_status() rather than reading settings directly.
#' Keep field names and order stable.
#' Inputs have already been checked and normalised by the public constructor.
#'
#' @param nodes A plain data frame with row names 1..n. Columns `id`, `label`,
#'   and optional `group` and `status` are character; `stage` and optional `lane`
#'   are character or factor. Ids are unique, non-missing and non-empty; stages
#'   and lanes are non-missing. Labels default to ids. Other columns are kept.
#' @param links A plain data frame with row names 1..n. Columns `from`, `to` and
#'   `kind` are character; `label` is character and may contain `NA`. Every `from`
#'   and `to` is a node id; `kind` is never missing. No self-links or duplicate
#'   combinations of `from`, `to` and `kind` remain. Other columns are kept.
#' @param stages A character vector of stage names in order, or `NULL` for defaults.
#' @param lanes A character vector of lane names in order, or `NULL` for defaults.
#' @param kinds A named list of `stagemap_kind` objects, or `NULL` for defaults.
#' @param groups A list of named character vectors `colours` and `labels`, or
#'   `NULL` for defaults.
#' @param status A named character vector of badge text, or `NULL` for defaults.
#' @param options A list of map options, initially empty.
#' @returns A `stagemap` list with the fields above in argument order.
#' @noRd
new_stagemap <- function(
  nodes,
  links,
  stages = NULL,
  lanes = NULL,
  kinds = NULL,
  groups = NULL,
  status = NULL,
  options = list()
) {
  checkmate::assert_data_frame(nodes, min.rows = 1)
  checkmate::assert_data_frame(links)
  checkmate::assert_character(stages, null.ok = TRUE)
  checkmate::assert_character(lanes, null.ok = TRUE)
  checkmate::assert_list(kinds, types = "stagemap_kind", names = "unique", null.ok = TRUE)
  checkmate::assert_list(groups, len = 2, names = "unique", null.ok = TRUE)
  checkmate::assert_character(status, any.missing = FALSE, names = "unique", null.ok = TRUE)
  checkmate::assert_list(options)
  if (!is.null(groups)) {
    checkmate::assert_names(names(groups), identical.to = c("colours", "labels"))
    checkmate::assert_character(groups$colours, any.missing = FALSE, names = "unique")
    checkmate::assert_character(groups$labels, any.missing = FALSE, names = "unique")
  }
  structure(
    list(
      nodes = nodes,
      links = links,
      stages = stages,
      lanes = lanes,
      kinds = kinds,
      groups = groups,
      status = status,
      options = options
    ),
    class = "stagemap"
  )
}

#' Check required columns before checking either table's values
#' @noRd
check_required_columns <- function(data, arg, required, call = parent.frame()) {
  checkmate::assert_data_frame(data)
  checkmate::assert_string(arg, min.chars = 1)
  checkmate::assert_character(required, any.missing = FALSE)
  checkmate::assert_environment(call)
  missing_columns <- setdiff(required, names(data))
  if (length(missing_columns)) {
    cli::cli_abort(
      "{.arg {arg}} is missing required columns: {.field {missing_columns}}. Columns present: {.field {names(data)}}.",
      class = c("stagemap_error_data", "stagemap_error"),
      call = call
    )
  }
  invisible(NULL)
}

#' Check and convert the fixed table columns
#' @noRd
check_map_columns <- function(data, arg, columns, call = parent.frame()) {
  checkmate::assert_data_frame(data)
  checkmate::assert_string(arg, min.chars = 1)
  checkmate::assert_character(columns, any.missing = FALSE)
  checkmate::assert_environment(call)
  # Strip table subclasses so downstream functions always receive plain data frames.
  class(data) <- "data.frame"
  for (column in intersect(columns, names(data))) {
    value <- data[[column]]
    # A column of only NA is logical in R; where missing values are allowed it means "none given".
    if (column %in% c("label", "group", "status") && is.logical(value) && all(is.na(value))) {
      data[[column]] <- as.character(value)
      next
    }
    if ((!is.character(value) && !is.factor(value)) || !is.null(dim(value))) {
      cli::cli_abort(
        c(
          "Column {.field {column}} of {.arg {arg}} must be character or factor, not {column_type(value)}.",
          "i" = "Convert it first, for example {.code {arg}${column} <- as.character({arg}${column})}."
        ),
        class = c("stagemap_error_data", "stagemap_error"),
        call = call
      )
    }
    if (is.factor(value) && !column %in% c("stage", "lane")) data[[column]] <- as.character(value)
  }
  data
}

#' @rdname stagemap
#' @export
format.stagemap <- function(x, ...) {
  checkmate::assert_class(x, "stagemap")
  # These closures consume the enclosing method's checked map.
  count_text <- function(n, noun) paste(n, paste0(noun, if (n == 1L) "" else "s"))
  list_text <- function(value, title) {
    values <- unique(value)
    shown <- paste(values[seq_len(min(length(values), 8L))], collapse = ", ")
    more <- if (length(values) > 8L) paste0(", and ", length(values) - 8L, " more") else ""
    paste0(title, " (", length(values), "): ", shown, more)
  }
  c(
    paste0("<stagemap> ", count_text(nrow(x$nodes), "node"), ", ", count_text(nrow(x$links), "link")),
    list_text(resolve_stages(x), "Stages"),
    if ("lane" %in% names(x$nodes)) list_text(resolve_lanes(x), "Lanes"),
    if (nrow(x$links)) list_text(x$links$kind, "Kinds"),
    if ("group" %in% names(x$nodes)) list_text(resolve_groups(x)$group, "Groups")
  )
}

#' @rdname stagemap
#' @export
print.stagemap <- function(x, ...) {
  checkmate::assert_class(x, "stagemap")
  # A print method writes the summary to standard output.
  cat(format(x), sep = "\n") # nolint: undesirable_function_linter.
  invisible(x)
}

#' Describe a column's type for an error message
#' @noRd
column_type <- function(value) {
  checkmate::assert_vector(value)
  if (!is.null(dim(value))) {
    "a matrix"
  } else if (is.object(value) && !is.factor(value)) {
    paste("class", class(value)[1L])
  } else if (is.numeric(value)) {
    "a number"
  } else if (is.logical(value)) {
    "a logical"
  } else if (is.list(value)) {
    "a list"
  } else {
    paste("type", typeof(value))
  }
}
