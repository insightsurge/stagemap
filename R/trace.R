#' Trace links from start cards
#'
#' Walks links breadth first from one or more start cards. Rows are ordered by `distance`, then the order of `cards` in
#' the map. When several links reach a card at the same distance, the first in `links` order wins. Every card and link
#' in the map counts: hidden cards, variants and the changes of [add_steps()] are ignored.
#'
#' With `direction = "both"`, the downstream and upstream walks run apart from the start cards and are joined, so a
#' trace never follows one link downstream and the next upstream. A card reached by both walks (in a loop, or between
#' two start cards) appears once with `direction = "both"`, the shorter `distance`, and the `through` and `kind` of
#' that walk; on a tie, the downstream walk wins. Because such a card is one row, `through` does not say which way its
#' link runs (look in `links`), and `distance` is not always the `distance` of the `through` card plus 1: the
#' `through` column forms a path only within one walk, and the row of a `"both"` card may come from the other walk.
#'
#' @param map A [stage_map()] widget.
#' @param ids Card ids to start from, as text (a factor counts as text) or whole numbers (never `NA`, never blank).
#'   `NULL` or a length-zero vector returns no rows.
#' @param ... Must stay empty. It makes every argument after it a named argument, and a typo in an argument's name an
#'   error that names it.
#' @param direction Which way to follow links: `"downstream"` (the default, from `from` to `to`), `"upstream"` (from
#'   `to` to `from`), or `"both"`.
#' @param kinds Link kind ids to follow, as text (a factor counts as text) or whole numbers (never `NA`, never blank).
#'   `NULL`, the default, follows every link, including links without a kind. `character(0)` follows no links.
#' @param max_distance Maximum number of links to follow: a whole number from `0`, or `Inf` (the default, no limit). `0`
#'   returns only the start cards.
#' @returns A plain data frame with row names `1` to `n` and columns:
#'   * `id`, `label`, `stage`, `lane` (character): the card's id, label, stage id and lane id.
#'   * `direction` (character): `"start"` for a start card, `"downstream"`, `"upstream"`, or `"both"` when both walks
#'     reach the card. Never `NA`.
#'   * `distance` (integer): number of links from a start card (`0L` for start cards).
#'   * `through` (character): id of the card this card was reached from, nearer the start (`NA` for start cards). In an
#'     upstream row the link itself runs from `id` to `through`; in a `"both"` row it may run either way.
#'   * `kind` (character): kind id of the link that reached this card (`NA` for start cards and unlabelled links).
#'
#'   With empty `ids`, the data frame has zero rows and the same column types. A wrong `map` stops with
#'   `stagemap_error_widget`; an id or kind not in the map stops with `stagemap_error_id`.
#' @family trace
#' @examples
#' map <- stage_map(
#'   cards = data.frame(
#'     id = c("req-1", "tst-1", "res-1"),
#'     label = c("Requirement", "Test", "Result"),
#'     stage = c("req", "test", "result"),
#'     lane = "core"
#'   )
#' ) |>
#'   add_links(
#'     data.frame(
#'       from = c("req-1", "tst-1"),
#'       to = c("tst-1", "res-1"),
#'       kind = c("verifies", "produces")
#'     ),
#'     kinds = data.frame(
#'       id = c("verifies", "produces"),
#'       label = c("Verifies", "Produces")
#'     )
#'   )
#' sm_trace(map, "req-1")
#' @export
sm_trace <- function(
  map,
  ids,
  ...,
  direction = c("downstream", "upstream", "both"),
  kinds = NULL,
  max_distance = Inf
) {
  call <- rlang::current_env()
  assert_trace_map(map, call = call)
  if (missing(ids)) {
    sm_abort(
      "{.arg ids} is missing; supply card ids, or {.code NULL} for none.",
      class = "stagemap_error_arg",
      call = call
    )
  }
  ids <- factor_text(ids)
  kinds <- factor_text(kinds)
  assert_id_values(ids, "ids", null_ok = TRUE, call = call)
  if (identical(direction, c("downstream", "upstream", "both"))) {
    direction <- "downstream"
  }
  checkmate::assert_choice(direction, c("downstream", "upstream", "both"))
  assert_id_values(kinds, "kinds", null_ok = TRUE, call = call)
  checkmate::assert_number(max_distance, lower = 0, finite = FALSE)
  check_dots(..., call = call)
  if (is.finite(max_distance) && max_distance != floor(max_distance)) {
    sm_abort(
      "{.arg max_distance} must be a whole number or {.code Inf}, not {.val {max_distance}}.",
      class = "stagemap_error_arg",
      call = call
    )
  }

  data <- sm_widget_data(map)
  cards <- data$cards
  card_ids <- as_text(cards$id)
  start_text <- if (is.null(ids)) character() else unique(as_text(ids))
  check_known_ids(start_text, card_ids, "card id", "ids", "The map has no cards.", call)
  if (!is.null(kinds)) {
    kinds <- as_text(kinds)
    check_known_ids(kinds, map_known_kinds(data), "link kind", "kinds", "The map has no link kinds.", call)
  }

  n_cards <- nrow(cards)
  start_idx <- match(start_text, card_ids)
  links <- data$links
  if (is.null(links) || nrow(links) == 0L) {
    from_idx <- integer()
    to_idx <- integer()
    link_kinds <- character()
  } else {
    raw_kinds <- if ("kind" %in% names(links)) as_text(links$kind) else rep(NA_character_, nrow(links))
    if (!is.null(kinds)) {
      keep_link <- raw_kinds %in% kinds
      links <- links[keep_link, , drop = FALSE]
      raw_kinds <- raw_kinds[keep_link]
    }
    from_idx <- match(as_text(links$from), card_ids)
    to_idx <- match(as_text(links$to), card_ids)
    link_kinds <- raw_kinds
  }

  run_down <- direction %in% c("downstream", "both")
  run_up <- direction %in% c("upstream", "both")
  d_walk <- if (run_down) trace_walk(start_idx, from_idx, to_idx, link_kinds, n_cards, max_distance, down = TRUE)
  u_walk <- if (run_up) trace_walk(start_idx, from_idx, to_idx, link_kinds, n_cards, max_distance, down = FALSE)

  in_down <- if (run_down) !is.na(d_walk$distance) else rep(FALSE, n_cards)
  in_up <- if (run_up) !is.na(u_walk$distance) else rep(FALSE, n_cards)
  reached <- in_down | in_up

  dir_out <- rep(NA_character_, n_cards)
  dir_out[in_down] <- "downstream"
  dir_out[in_up] <- "upstream"
  dir_out[in_down & in_up] <- "both"
  dir_out[start_idx] <- "start"

  use_down <- if (!run_up) {
    in_down
  } else if (!run_down) {
    rep(FALSE, n_cards)
  } else {
    in_down & (!in_up | d_walk$distance <= u_walk$distance)
  }

  dist_out <- rep(NA_integer_, n_cards)
  through_idx <- rep(NA_integer_, n_cards)
  kind_out <- rep(NA_character_, n_cards)
  if (run_down) {
    dist_out[use_down] <- d_walk$distance[use_down]
    through_idx[use_down] <- d_walk$through[use_down]
    kind_out[use_down] <- d_walk$kind[use_down]
  }
  if (run_up) {
    use_up <- in_up & !use_down
    dist_out[use_up] <- u_walk$distance[use_up]
    through_idx[use_up] <- u_walk$through[use_up]
    kind_out[use_up] <- u_walk$kind[use_up]
  }

  through_out <- rep(NA_character_, n_cards)
  has_through <- !is.na(through_idx)
  through_out[has_through] <- card_ids[through_idx[has_through]]

  rows <- which(reached)
  rows <- rows[order(dist_out[rows], rows)]
  out <- trace_cards_df(cards, rows)
  out$direction <- dir_out[rows]
  out$distance <- dist_out[rows]
  out$through <- through_out[rows]
  out$kind <- kind_out[rows]
  rownames(out) <- NULL
  out
}

#' Find cards with no links
#'
#' Lists cards that appear at neither end of any link, in the order of `cards` in the map. When the map has no links,
#' every card is returned. Every card and link in the map counts: hidden cards, variants and the changes of
#' [add_steps()] are ignored.
#'
#' @inheritParams sm_trace
#' @returns A plain data frame with row names `1` to `n` and character columns `id`, `label`, `stage` and `lane`. With
#'   no matches, the data frame has zero rows and the same column types. A wrong `map` stops with
#'   `stagemap_error_widget`.
#' @family trace
#' @examples
#' map <- stage_map(
#'   cards = data.frame(
#'     id = c("req-1", "req-2", "tst-1"),
#'     label = c("First", "Orphan", "Test"),
#'     stage = c("req", "req", "test"),
#'     lane = "core"
#'   )
#' ) |>
#'   add_links(data.frame(from = "req-1", to = "tst-1"))
#' sm_orphans(map)
#' @export
sm_orphans <- function(map) {
  call <- rlang::current_env()
  assert_trace_map(map, call = call)
  data <- sm_widget_data(map)
  cards <- data$cards
  links <- data$links
  if (is.null(links) || nrow(links) == 0L) {
    return(trace_cards_df(cards, seq_len(nrow(cards))))
  }
  linked <- unique(c(as_text(links$from), as_text(links$to)))
  keep <- which(!as_text(cards$id) %in% linked)
  trace_cards_df(cards, keep)
}

#' Find cards missing a direct link to a stage
#'
#' Lists cards in `stage` with no direct link, in either direction, to any card in `linked_to`. Rows stay in the order
#' of `cards` in the map. When `linked_to` equals `stage`, a card linked to itself counts as linked. Every card and link
#' in the map counts: hidden cards, variants and the changes of [add_steps()] are ignored.
#'
#' @inheritParams sm_trace
#' @param stage Stage id to inspect, as text (a factor counts as text) or a whole number (never `NA`, never blank). A
#'   stage with no cards, from the map's `stages` table or the levels of a factor, is accepted and gives zero rows.
#' @param linked_to Stage id to check links against, as text (a factor counts as text) or a whole number (never `NA`,
#'   never blank). May equal `stage`. A stage with no cards is accepted: every card in `stage` is then listed, and when
#'   `stage` has no cards either, the result has zero rows.
#' @param kinds Link kind ids to count, as text (a factor counts as text) or whole numbers (never `NA`, never blank).
#'   `NULL`, the default, counts links of any kind. `character(0)` counts no links.
#' @returns A plain data frame with row names `1` to `n` and character columns `id`, `label`, `stage` and `lane`. With
#'   no matches, the data frame has zero rows and the same column types. A wrong `map` stops with
#'   `stagemap_error_widget`; an unknown stage or kind stops with `stagemap_error_id`.
#' @family trace
#' @examples
#' map <- stage_map(
#'   cards = data.frame(
#'     id = c("req-1", "req-2", "tst-1"),
#'     label = c("First", "Missing test", "Test"),
#'     stage = c("req", "req", "test"),
#'     lane = "core"
#'   )
#' ) |>
#'   add_links(data.frame(from = "req-1", to = "tst-1"))
#' sm_missing(map, "req", "test")
#' @export
sm_missing <- function(map, stage, linked_to, ..., kinds = NULL) {
  call <- rlang::current_env()
  assert_trace_map(map, call = call)
  if (missing(stage)) {
    sm_abort("{.arg stage} is missing; supply a stage id.", class = "stagemap_error_arg", call = call)
  }
  stage <- factor_text(stage)
  assert_id_values(stage, "stage", len = 1L, call = call)
  if (missing(linked_to)) {
    sm_abort("{.arg linked_to} is missing; supply a stage id.", class = "stagemap_error_arg", call = call)
  }
  linked_to <- factor_text(linked_to)
  assert_id_values(linked_to, "linked_to", len = 1L, call = call)
  kinds <- factor_text(kinds)
  assert_id_values(kinds, "kinds", null_ok = TRUE, call = call)
  check_dots(..., call = call)

  data <- sm_widget_data(map)
  cards <- data$cards
  stage_text <- as_text(stage)
  linked_to_text <- as_text(linked_to)
  known_stages <- if (is.data.frame(data$stages)) as_text(data$stages$id) else character()
  check_known_ids(stage_text, known_stages, "stage", "stage", "The map has no stages.", call)
  check_known_ids(linked_to_text, known_stages, "stage", "linked_to", "The map has no stages.", call)
  if (!is.null(kinds)) {
    kinds <- as_text(kinds)
    check_known_ids(kinds, map_known_kinds(data), "link kind", "kinds", "The map has no link kinds.", call)
  }

  card_ids <- as_text(cards$id)
  card_stages <- as_text(cards$stage)
  links <- data$links
  if (is.null(links) || nrow(links) == 0L) {
    linked <- character()
  } else {
    if (!is.null(kinds)) {
      if ("kind" %in% names(links)) {
        links <- links[as_text(links$kind) %in% kinds, , drop = FALSE]
      } else {
        links <- links[FALSE, , drop = FALSE]
      }
    }
    from_ids <- as_text(links$from)
    to_ids <- as_text(links$to)
    targets <- card_ids[card_stages == linked_to_text]
    linked <- c(from_ids[to_ids %in% targets], to_ids[from_ids %in% targets])
  }
  keep <- which(card_stages == stage_text & !card_ids %in% linked)
  trace_cards_df(cards, keep)
}

# Refuses a missing or non-widget `map` with `stagemap_error_widget`.
assert_trace_map <- function(map, call = rlang::caller_env()) {
  checkmate::assert_environment(call)
  if (missing(map)) {
    sm_abort(
      "{.arg map} is missing; supply a widget made by a stagemap function.",
      class = "stagemap_error_widget",
      call = call
    )
  }
  if (!inherits(map, "stagemap_widget")) {
    sm_abort(
      c("{.arg map} must be a widget made by a stagemap function.", "x" = "It is {.cls {class(map)}}."),
      class = "stagemap_error_widget",
      call = call
    )
  }
  invisible(NULL)
}

# A factor argument as text, like the data columns; anything else unchanged.
factor_text <- function(x) {
  if (is.factor(x)) as.character(x) else x
}

# Runs `expr` (a checkmate assertion) and, when it fails, names the function the user called in the error: the
# assertion's own call would be the helper. The error keeps its class.
with_caller_call <- function(expr, call) {
  checkmate::assert_environment(call)
  tryCatch(
    expr,
    error = function(cnd) {
      cnd$call <- rlang::frame_call(call)
      stop(cnd)
    }
  )
}

# Link kinds the map knows: every id in `kinds` and every non-NA `kind` in `links`.
map_known_kinds <- function(data) {
  checkmate::assert_list(data, names = "named")
  kinds <- if (is.data.frame(data$kinds)) stats::na.omit(as_text(data$kinds$id)) else character()
  used <- if (is.data.frame(data$links) && "kind" %in% names(data$links)) {
    stats::na.omit(as_text(data$links$kind))
  } else {
    character()
  }
  unique(as.character(c(kinds, used)))
}

# Stops with `stagemap_error_id` when any value in `values` is absent from `known`.
check_known_ids <- function(values, known, what, arg, empty_note, call) {
  checkmate::assert_character(values, any.missing = FALSE)
  checkmate::assert_character(known, any.missing = FALSE)
  checkmate::assert_string(what, min.chars = 1L)
  checkmate::assert_string(arg, min.chars = 1L)
  checkmate::assert_string(empty_note, min.chars = 1L)
  checkmate::assert_environment(call)
  bad <- setdiff(values, known)
  if (length(bad) == 0L) {
    return(invisible(NULL))
  }
  known_note <- if (length(known) > 0L) {
    cli_escape(cli::format_inline(
      "Known {what}s: {.val {cli::cli_vec(known, list('vec-trunc' = 20L))}}."
    ))
  } else {
    empty_note
  }
  sm_abort(
    c(
      "Unknown {cli::qty(length(bad))}{what}{?s} in {.arg {arg}}: {.val {bad}}.",
      "i" = known_note
    ),
    class = "stagemap_error_id",
    call = call
  )
}

# Runs one breadth-first walk (downstream or upstream) from `start_idx` up to `max_distance` steps.
trace_walk <- function(start_idx, from_idx, to_idx, link_kinds, n_cards, max_distance, down) {
  checkmate::assert_integer(start_idx, lower = 1L, any.missing = FALSE)
  checkmate::assert_integer(from_idx, any.missing = FALSE)
  checkmate::assert_integer(to_idx, len = length(from_idx), any.missing = FALSE)
  checkmate::assert_character(link_kinds, len = length(from_idx))
  checkmate::assert_count(n_cards)
  checkmate::assert_number(max_distance, lower = 0, finite = FALSE)
  checkmate::assert_flag(down)

  dist <- rep(NA_integer_, n_cards)
  through <- rep(NA_integer_, n_cards)
  kind <- rep(NA_character_, n_cards)
  frontier <- start_idx
  dist[frontier] <- 0L
  steps <- 0L
  src <- if (down) from_idx else to_idx
  dst <- if (down) to_idx else from_idx
  # Links grouped by the card they leave, built once: each step looks at the frontier's links only.
  by_source <- split(seq_along(src), factor(src, levels = seq_len(n_cards)))
  while (length(frontier) > 0L && steps < max_distance) {
    edges <- sort.int(unlist(by_source[frontier], use.names = FALSE))
    edges <- edges[is.na(dist[dst[edges]])]
    # In link order, the first link to reach a card wins.
    edges <- edges[!duplicated(dst[edges])]
    target <- dst[edges]
    dist[target] <- steps + 1L
    through[target] <- src[edges]
    kind[target] <- link_kinds[edges]
    frontier <- target
    steps <- steps + 1L
  }
  list(distance = dist, through = through, kind = kind)
}

# Builds the four core character columns for `rows` of `cards` with row names 1 to n.
trace_cards_df <- function(cards, rows) {
  checkmate::assert_data_frame(cards)
  checkmate::assert_integerish(rows, lower = 1L, any.missing = FALSE)
  rows <- as.integer(rows)
  data.frame(
    id = as_text(cards$id[rows]),
    label = as_text(cards$label[rows]),
    stage = as_text(cards$stage[rows]),
    lane = as_text(cards$lane[rows]),
    stringsAsFactors = FALSE
  )
}
