#' Set the direction, node order and spacing of a map
#'
#' Set the layout of a [stagemap()]. Without a setting, the defaults below apply.
#' The layout is computed in R and is the same on every run.
#' Label widths are estimated from Helvetica metrics, so a page using another
#' font can differ.
#' A line break in a label starts a new line when wrapping.
#'
#' @inheritParams sm_stages
#' @param direction One of `"LR"` (the default), with stages in columns from left
#'   to right and lanes in horizontal bands, or `"TB"`, with stages in rows from
#'   top to bottom and lanes in vertical bands.
#' @param order One of `"auto"` (the default), which reorders nodes within each
#'   stage to reduce crossing links, or `"data"`, which keeps nodes in the order
#'   of the data. Nodes stay in their lane.
#' @param spacing One finite number from 0.25 to 4, defaulting to 1. Scales the
#'   gaps between stages, nodes and lanes and the space for links passing through
#'   a stage. Node sizes do not change.
#' @returns The changed `stagemap` object, visibly, for use in a pipe.
#' @family meaning
#' @export
#' @examples
#' nodes <- data.frame(id = c("Plan", "Build"), stage = c("First", "Next"))
#' stagemap(nodes) |> sm_layout(direction = "TB", order = "data", spacing = 1.5)
sm_layout <- function(map, direction = c("LR", "TB"), order = c("auto", "data"), spacing = 1) {
  with_stagemap_asserts({
    checkmate::assert_class(map, "stagemap")
    checkmate::assert_choice(if (missing(direction)) direction[1L] else direction, c("LR", "TB"))
    checkmate::assert_choice(if (missing(order)) order[1L] else order, c("auto", "data"))
    checkmate::assert_number(spacing, lower = 0.25, upper = 4, finite = TRUE)
  })
  map$options$layout <- list(direction = direction[1L], order = order[1L], spacing = spacing)
  map
}
