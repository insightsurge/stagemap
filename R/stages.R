#' Set the order of stages
#'
#' Set the columns of a [stagemap()], including empty columns. Without a setting,
#' factor levels (including unused levels) or first appearance give the order.
#'
#' @param map A `stagemap` object.
#' @param stages A character vector of unique, non-missing, non-empty stage names
#'   in order. Every stage used by a node must be included.
#' @returns The changed `stagemap` object, visibly, for use in a pipe.
#' @family meaning
#' @export
#' @examples
#' nodes <- data.frame(
#'   id = c("REQ-1", "REQ-2", "TST-1", "RES-1"),
#'   stage = c("Requirement", "Requirement", "Test", "Result"),
#'   lane = c("Safety", "Usability", "Safety", "Safety")
#' )
#' map <- stagemap(nodes)
#' sm_stages(map, c("Requirement", "Test", "Result"))
sm_stages <- function(map, stages) {
  if (missing(stages)) {
    cli::cli_abort(
      c(
        "{.arg stages} is missing.",
        "i" = "Give the stages in order, such as {.code sm_stages(map, c(\"Plan\", \"Build\"))}."
      ),
      class = "stagemap_error"
    )
  }
  with_stagemap_asserts({
    checkmate::assert_class(map, "stagemap")
    checkmate::assert_character(stages, any.missing = FALSE, min.chars = 1, unique = TRUE)
  })
  check_arg(checkmate::check_true(all(nzchar(trimws(stages)))), "stages", environment())
  bad <- which(!map$nodes$stage %in% stages)
  if (length(bad)) {
    abort_rows(
      bad,
      "nodes",
      "stage",
      "an unknown",
      unique(as.character(map$nodes$stage[bad])),
      value_label = "Unknown stages"
    )
  }
  map$stages <- stages
  map
}

#' Set the order of lanes
#'
#' Set the bands of a [stagemap()], including empty bands. Without a setting,
#' factor levels (including unused levels) or first appearance give the order.
#'
#' @inheritParams sm_stages
#' @param lanes A character vector of unique, non-missing, non-empty lane names
#'   in order. Every lane used by a node must be included. Requires a lane column.
#' @returns The changed `stagemap` object, visibly, for use in a pipe.
#' @family meaning
#' @export
#' @examples
#' nodes <- data.frame(
#'   id = c("REQ-1", "REQ-2", "TST-1", "RES-1"),
#'   stage = c("Requirement", "Requirement", "Test", "Result"),
#'   lane = c("Safety", "Usability", "Safety", "Safety")
#' )
#' sm_lanes(stagemap(nodes), c("Usability", "Safety"))
sm_lanes <- function(map, lanes) {
  if (missing(lanes)) {
    cli::cli_abort(
      c(
        "{.arg lanes} is missing.",
        "i" = "Give the lanes in order, such as {.code sm_lanes(map, c(\"Safety\", \"Usability\"))}."
      ),
      class = "stagemap_error"
    )
  }
  with_stagemap_asserts({
    checkmate::assert_class(map, "stagemap")
    checkmate::assert_character(lanes, any.missing = FALSE, min.chars = 1, unique = TRUE)
  })
  check_arg(checkmate::check_true(all(nzchar(trimws(lanes)))), "lanes", environment())
  if (!"lane" %in% names(map$nodes)) {
    cli::cli_abort("{.arg map} has no {.field lane} column.", class = "stagemap_error")
  }
  bad <- which(!map$nodes$lane %in% lanes)
  if (length(bad)) {
    abort_rows(
      bad,
      "nodes",
      "lane",
      "an unknown",
      unique(as.character(map$nodes$lane[bad])),
      value_label = "Unknown lanes"
    )
  }
  map$lanes <- lanes
  map
}

#' Resolve stage order for layout and drawing
#' @noRd
resolve_stages <- function(map) {
  checkmate::assert_class(map, "stagemap")
  if (!is.null(map$stages)) {
    return(map$stages)
  }
  if (is.factor(map$nodes$stage)) levels(map$nodes$stage) else unique(map$nodes$stage)
}

#' Resolve lane order for layout and drawing
#' @noRd
resolve_lanes <- function(map) {
  checkmate::assert_class(map, "stagemap")
  if (!"lane" %in% names(map$nodes)) {
    return(character())
  }
  if (!is.null(map$lanes)) {
    return(map$lanes)
  }
  if (is.factor(map$nodes$lane)) levels(map$nodes$lane) else unique(map$nodes$lane)
}
