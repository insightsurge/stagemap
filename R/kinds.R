#' Describe a link kind
#'
#' Build a style for [sm_kinds()] on a [stagemap()]. Meaning never rests on
#' colour alone: automatic styles use lines and middle marks to distinguish kinds.
#'
#' @param line One of the line type names used by base R graphics: `"solid"` (unbroken), `"dashed"`
#'   (short dashes), `"dotted"` (dots), `"dotdash"` (dots and dashes),
#'   `"longdash"` (long dashes) or `"twodash"` (alternating dash lengths).
#'   `NULL` chooses a line automatically.
#' @param colour One R colour name or hex colour (`#RGB`, `#RRGGBB` or
#'   `#RRGGBBAA`), or `"from"` or `"to"` to use the start or end node's
#'   group colour. Colours are stored as upper-case hex. `NULL` uses theme ink.
#' @param width One positive finite number. `NULL` uses 1.5.
#' @param arrow One logical flag. `NULL` uses `TRUE`.
#' @param mark One middle mark: `"none"`, `"circle"`, `"square"`, `"diamond"`,
#'   `"bar"` or `"cross"` (an X). `NULL` chooses automatically: no mark while
#'   unused line types remain, then circle, square, diamond, bar and cross,
#'   each for a full cycle of the six line types.
#' @returns A `stagemap_kind` list containing the five style fields.
#' @family meaning
#' @export
#' @examples
#' sm_kind(line = "dashed", arrow = TRUE)
#' nodes <- data.frame(
#'   id = c("REQ-1", "REQ-2", "TST-1", "RES-1"),
#'   stage = c("Requirement", "Requirement", "Test", "Result")
#' )
#' links <- data.frame(
#'   from = c("REQ-1", "TST-1"), to = c("TST-1", "RES-1"),
#'   kind = c("verifies", "produces")
#' )
#' sm_kinds(stagemap(nodes, links), verifies = sm_kind(line = "dashed"))
sm_kind <- function(line = NULL, colour = NULL, width = NULL, arrow = NULL, mark = NULL) {
  with_stagemap_asserts({
    checkmate::assert_choice(line, c("solid", "dashed", "dotted", "dotdash", "longdash", "twodash"), null.ok = TRUE)
    checkmate::assert_string(colour, min.chars = 1, null.ok = TRUE)
    checkmate::assert_number(width, lower = 0, finite = TRUE, null.ok = TRUE)
    checkmate::assert_flag(arrow, null.ok = TRUE)
    checkmate::assert_choice(mark, c("none", "circle", "square", "diamond", "bar", "cross"), null.ok = TRUE)
  })
  if (!is.null(width) && width == 0) {
    cli::cli_abort("{.arg width} must be positive, not {.val {width}}.", class = "stagemap_error")
  }
  if (!is.null(colour) && !colour %in% c("from", "to")) {
    colour <- as_colour(colour, "colour", environment())
  }
  structure(list(line = line, colour = colour, width = width, arrow = arrow, mark = mark), class = "stagemap_kind")
}

#' Set styles for link kinds
#'
#' Set link meaning on a [stagemap()]. Later calls replace the whole style for
#' each named kind and keep other kinds. Unused names warn and are kept, so a
#' vocabulary can be shared across maps.
#'
#' @inheritParams sm_stages
#' @param ... Named `stagemap_kind` objects made by [sm_kind()], with unique,
#'   non-empty kind names. Empty dots leave the settings unchanged.
#' @returns The changed `stagemap` object, visibly, for use in a pipe.
#' @family meaning
#' @export
#' @examples
#' nodes <- data.frame(
#'   id = c("REQ-1", "REQ-2", "TST-1", "RES-1"),
#'   stage = c("Requirement", "Requirement", "Test", "Result")
#' )
#' links <- data.frame(
#'   from = c("REQ-1", "TST-1"), to = c("TST-1", "RES-1"),
#'   kind = c("verifies", "produces")
#' )
#' sm_kinds(stagemap(nodes, links), verifies = sm_kind(line = "dashed", arrow = TRUE))
sm_kinds <- function(map, ...) {
  with_stagemap_asserts({
    checkmate::assert_class(map, "stagemap")
    checkmate::assert_list(list(...), types = "stagemap_kind")
  })
  settings <- list(...)
  check_setting_names(settings, "...", environment())
  warn_unused_settings(names(settings), unique(map$links$kind), "...", environment())
  if (length(settings)) {
    map$kinds[names(settings)] <- settings
  }
  map
}

#' Resolve used kinds to a plain style table
#' @noRd
resolve_kinds <- function(map) {
  checkmate::assert_class(map, "stagemap")
  kinds <- unique(map$links$kind)
  result <- data.frame(
    kind = kinds,
    line = rep(NA_character_, length(kinds)),
    colour = rep(NA_character_, length(kinds)),
    width = rep(1.5, length(kinds)),
    arrow = rep(TRUE, length(kinds)),
    mark = rep("none", length(kinds))
  )
  lines <- c("solid", "dashed", "dotted", "dotdash", "longdash", "twodash")
  marks <- c("circle", "square", "diamond", "bar", "cross")
  explicit <- vapply(
    kinds,
    function(kind) {
      line <- map$kinds[[kind]]$line
      if (is.null(line)) NA_character_ else line
    },
    character(1)
  )
  for (i in seq_along(kinds)) {
    style <- map$kinds[[kinds[i]]]
    for (field in c("line", "colour", "width", "arrow", "mark")) {
      if (!is.null(style[[field]])) result[[field]][i] <- style[[field]]
    }
  }
  # Automatic kinds take the first line and mark pair no other kind uses: every line without a mark first, then
  # every line with each mark in turn, so kinds differ without relying on colour.
  candidates <- paste(rep(lines, times = length(marks) + 1L), rep(c("none", marks), each = length(lines)))
  taken <- paste(result$line, result$mark)[!is.na(explicit)]
  for (i in which(is.na(explicit))) {
    mark_set <- !is.null(map$kinds[[kinds[i]]]$mark)
    # A kind with its own mark prefers a line no kind uses yet.
    used_lines <- vapply(strsplit(taken, " ", fixed = TRUE), `[`, character(1), 1L)
    choices <- if (mark_set) {
      paste(c(setdiff(lines, used_lines), intersect(lines, used_lines)), result$mark[i])
    } else {
      candidates
    }
    free <- setdiff(choices, taken)
    # Past 36 kinds every pair is taken: cycle through the choices again.
    pair <- if (length(free)) free[1L] else choices[(length(taken) %% length(choices)) + 1L]
    taken <- c(taken, pair)
    parts <- strsplit(pair, " ", fixed = TRUE)[[1L]]
    result$line[i] <- parts[1L]
    result$mark[i] <- parts[2L]
  }
  result
}
