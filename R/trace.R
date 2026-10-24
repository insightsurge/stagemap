#' Trace links from a node
#'
#' Visit each reachable node once, taking the fewest steps from the start node.
#' Rows are ordered by distance, then by node order in the map. If several links
#' reach a node at the same distance, the first link in map order supplies its kind.
#'
#' @param map A `stagemap` object.
#' @param node One character string naming an existing node id.
#' @param direction One of `"down"` (the default, from start to end of links),
#'   `"up"` (from end to start) or `"both"` (either direction).
#' @param kinds A character vector of known link kinds to follow. `NULL`, the
#'   default, follows all kinds. An empty vector follows no links. Kinds may be
#'   used by links or set with [sm_kinds()].
#' @param depth A whole number greater than or equal to zero giving the most
#'   steps to follow. The default, `Inf`, has no limit; zero returns only `node`.
#' @returns A plain data frame with columns `id` (character node id), `label`
#'   (character node label), `stage` (the same type and factor levels as the map's
#'   stage column), `distance` (integer number of steps) and `kind` (character
#'   kind of the link first reaching the node). The start node is always first,
#'   with distance zero and `NA` kind. Row names are consecutive integers.
#' @family ask
#' @export
#' @examples
#' nodes <- data.frame(
#'   id = c("REQ-1", "TST-1", "RES-1"),
#'   stage = c("Requirement", "Test", "Result")
#' )
#' links <- data.frame(
#'   from = c("REQ-1", "TST-1"), to = c("TST-1", "RES-1"),
#'   kind = c("verifies", "produces")
#' )
#' sm_trace(stagemap(nodes, links), "REQ-1")
sm_trace <- function(map, node, direction = c("down", "up", "both"), kinds = NULL, depth = Inf) {
  with_stagemap_asserts({
    if (missing(map)) {
      cli::cli_abort("{.arg map} is missing; supply a stagemap object.", class = "stagemap_error")
    }
    checkmate::assert_class(map, "stagemap")
    if (missing(node)) {
      cli::cli_abort("{.arg node} is missing; supply a node id.", class = "stagemap_error")
    }
    checkmate::assert_string(node, min.chars = 1)
    if (identical(direction, c("down", "up", "both"))) {
      direction <- "down"
    }
    checkmate::assert_choice(direction, c("down", "up", "both"))
    checkmate::assert_character(kinds, min.chars = 1, any.missing = FALSE, null.ok = TRUE)
    checkmate::assert_number(depth, lower = 0, finite = FALSE)
  })
  if (!node %in% map$nodes$id) {
    cli::cli_abort("Unknown {.arg node}: {.val {node}}.", class = "stagemap_error")
  }
  if (is.finite(depth) && depth != floor(depth)) {
    cli::cli_abort("{.arg depth} must be a whole number or Inf, not {.val {depth}}.", class = "stagemap_error")
  }
  check_trace_kinds(map, kinds, "kinds", call = environment())
  links <- map$links
  if (!is.null(kinds)) {
    links <- links[links$kind %in% kinds, , drop = FALSE]
  }
  from <- match(links$from, map$nodes$id)
  to <- match(links$to, map$nodes$id)
  distance <- rep(NA_integer_, nrow(map$nodes))
  kind <- rep(NA_character_, nrow(map$nodes))
  frontier <- match(node, map$nodes$id)
  distance[frontier] <- 0L
  steps <- 0L
  while (length(frontier) && steps < depth) {
    down <- direction != "up" & from %in% frontier & is.na(distance[to])
    up <- direction != "down" & to %in% frontier & is.na(distance[from])
    edges <- which(down | up)
    next_frontier <- integer()
    for (edge in edges) {
      target <- if (down[edge]) to[edge] else from[edge]
      if (is.na(distance[target])) {
        distance[target] <- steps + 1L
        kind[target] <- links$kind[edge]
        next_frontier <- c(next_frontier, target)
      }
    }
    frontier <- next_frontier
    steps <- steps + 1L
  }
  rows <- which(!is.na(distance))
  rows <- rows[order(distance[rows], rows)]
  result <- map$nodes[rows, c("id", "label", "stage"), drop = FALSE]
  result$distance <- distance[rows]
  result$kind <- kind[rows]
  rownames(result) <- NULL
  result
}

#' Find nodes with no links
#'
#' Find nodes that appear at neither end of any link.
#'
#' @param map A `stagemap` object.
#' @returns A plain data frame in node order with columns `id` (character node
#'   id), `label` (character node label) and `stage` (the same type and factor
#'   levels as the map's stage column). With no matches, the columns retain their
#'   types and have zero rows. Row names are consecutive integers.
#' @family ask
#' @export
#' @examples
#' nodes <- data.frame(
#'   id = c("REQ-1", "REQ-2", "TST-1", "RES-1"),
#'   stage = c("Requirement", "Requirement", "Test", "Result")
#' )
#' links <- data.frame(from = c("REQ-1", "TST-1"), to = c("TST-1", "RES-1"))
#' sm_orphans(stagemap(nodes, links))
sm_orphans <- function(map) {
  with_stagemap_asserts({
    checkmate::assert_class(map, "stagemap")
  })
  linked <- c(map$links$from, map$links$to)
  result <- map$nodes[!map$nodes$id %in% linked, c("id", "label", "stage"), drop = FALSE]
  rownames(result) <- NULL
  result
}

#' Find nodes missing a link to a stage
#'
#' Find nodes in one stage with no direct link to any node in another stage.
#' Links count in either direction, including when both stages are the same.
#'
#' @param map A `stagemap` object.
#' @param from One character string naming a known stage to check.
#' @param to One character string naming a known stage to link to. Empty stages
#'   set with [sm_stages()] or retained as factor levels are known stages too.
#' @param kind One character string naming a known link kind. `NULL`, the
#'   default, counts links of any kind. Kinds may be used by links or set with
#'   [sm_kinds()].
#' @returns A plain data frame in node order with columns `id` (character node
#'   id), `label` (character node label) and `stage` (the same type and factor
#'   levels as the map's stage column). With no matches, the columns retain their
#'   types and have zero rows. Row names are consecutive integers.
#' @family ask
#' @export
#' @examples
#' nodes <- data.frame(
#'   id = c("REQ-1", "REQ-2", "TST-1", "RES-1"),
#'   stage = c("Requirement", "Requirement", "Test", "Result")
#' )
#' links <- data.frame(from = c("REQ-1", "TST-1"), to = c("TST-1", "RES-1"))
#' sm_missing(stagemap(nodes, links), "Requirement", "Test")
sm_missing <- function(map, from, to, kind = NULL) {
  with_stagemap_asserts({
    if (missing(map)) {
      cli::cli_abort("{.arg map} is missing; supply a stagemap object.", class = "stagemap_error")
    }
    checkmate::assert_class(map, "stagemap")
    if (missing(from)) {
      cli::cli_abort("{.arg from} is missing; supply a stage name.", class = "stagemap_error")
    }
    checkmate::assert_string(from, min.chars = 1)
    if (missing(to)) {
      cli::cli_abort("{.arg to} is missing; supply a stage name.", class = "stagemap_error")
    }
    checkmate::assert_string(to, min.chars = 1)
    checkmate::assert_string(kind, min.chars = 1, null.ok = TRUE)
  })
  stages <- resolve_stages(map)
  for (arg in c("from", "to")) {
    value <- if (arg == "from") from else to
    if (!value %in% stages) {
      cli::cli_abort(
        c("Unknown stage in {.arg {arg}}: {.val {value}}.", "i" = "Known stages: {.val {stages}}."),
        class = "stagemap_error"
      )
    }
  }
  check_trace_kinds(map, kind, "kind", call = environment())
  links <- map$links
  if (!is.null(kind)) {
    links <- links[links$kind == kind, , drop = FALSE]
  }
  targets <- map$nodes$id[map$nodes$stage == to]
  linked <- c(links$from[links$to %in% targets], links$to[links$from %in% targets])
  rows <- map$nodes$stage == from & !map$nodes$id %in% linked
  result <- map$nodes[rows, c("id", "label", "stage"), drop = FALSE]
  rownames(result) <- NULL
  result
}

#' Check kinds against used and configured names
#' @noRd
check_trace_kinds <- function(map, kinds, arg, call) {
  checkmate::assert_class(map, "stagemap")
  checkmate::assert_character(kinds, min.chars = 1, any.missing = FALSE, null.ok = TRUE)
  checkmate::assert_string(arg, min.chars = 1)
  checkmate::assert_environment(call)
  # The resolver includes used kinds only; settings also hold unused vocabulary.
  known <- union(resolve_kinds(map)$kind, names(map$kinds))
  bad <- setdiff(kinds, known)
  if (length(bad)) {
    cli::cli_abort(
      c(
        "Unknown {.arg {arg}}: {.val {bad}}.",
        "i" = if (length(known)) "Known kinds: {.val {known}}." else "The map has no link kinds."
      ),
      class = "stagemap_error",
      call = call
    )
  }
  invisible(NULL)
}
