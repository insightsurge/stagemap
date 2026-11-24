# The stage map's data layers: each adds one list of the map's own data to a stage_map() widget, with the pipe. They
# are thin wrappers on the core's sm_add_data(), which refuses a field the engine does not take and one the widget
# already has.

# A data frame with no rows (also `data.frame()`, which has no columns) as NULL, which a layer reads as "none": a
# pipeline that filters its links down to nothing can still call add_links().
none_if_empty <- function(x) {
  checkmate::assert_data_frame(x, null.ok = TRUE)
  if (is.null(x) || nrow(x) == 0L) NULL else x
}

#' Add links between cards to a stage map
#'
#' Draws an arrow, or another kind of line, from one card to another: who handed what to whom.
#'
#' @section Columns:
#' Required columns are marked with an asterisk.
#' * `links`: `from*`, `to*` (card ids), `kind` (a `kinds` id), `label`, `step` (the id of the step the link plays
#'   at, see [add_steps()]), `variants` (variant ids separated by commas, see [add_variants()]).
#' * `kinds`: `id*`, `label*`, `line` (`"solid"`, `"dashed"`, `"dotted"` or `"dashdot"`), `end` (`"arrow"`,
#'   `"ring"` or `"none"`), `tone`, `quiet` (`TRUE` draws the links of that kind faint until the reader hovers over,
#'   focuses or picks them, or a step plays them; in print and in forced colours they are full strength; left out, it
#'   is `r sm_default("kinds", "quiet")`). Use it for a kind that would otherwise crowd the picture.
#'
#' A column the engine has no field for stays in the data the widget keeps in R and is not sent to the engine.
#'
#' @param x A [stage_map()] widget.
#' @param links A data frame with one row per link. See "Columns". `NULL`, or a data frame with no rows (such as
#'   `data.frame()`), adds no links.
#' @param ... Must stay empty. It makes every argument after it a named argument.
#' @param kinds A data frame with one row per kind of link, named in the legend, or `NULL`: every link is then a
#'   plain arrow. Added only with `links`: when `links` adds none, so do the kinds.
#' @returns The widget, with the links added. A widget that has links already is an error of class
#'   `stagemap_error_layer`.
#' @family stage map
#' @examples
#' map <- stage_map(
#'   nodes = data.frame(
#'     id = c("a", "b"),
#'     label = c("Draft", "Review"),
#'     stage = c("w", "c"),
#'     lane = "docs"
#'   ),
#'   stages = data.frame(id = c("w", "c"), label = c("Write", "Check")),
#'   lanes = data.frame(id = "docs", label = "Docs")
#' ) |>
#'   add_links(
#'     data.frame(from = "a", to = "b", kind = "hand"),
#'     kinds = data.frame(id = "hand", label = "Handed over", line = "dashed")
#'   )
#' class(map)
#' @examplesIf interactive()
#' map
#' @export
add_links <- function(x, links, ..., kinds = NULL) {
  checkmate::assert_data_frame(links, null.ok = TRUE)
  checkmate::assert_data_frame(kinds, null.ok = TRUE)
  check_dots(...)
  links <- none_if_empty(links)
  # The kinds belong to the links: with no links there is nothing to name, so none are added (a later call can).
  kinds <- if (!is.null(links)) none_if_empty(kinds)
  sm_add_data(x, list(links = links, kinds = kinds), call = rlang::current_env())
}

#' Add zones to a stage map
#'
#' Draws a labelled outline around a group of cards, such as "Needs sign-off". A card joins a zone through its `zone`
#' column. The map shows the zone notes beside the picture unless [stage_map()] was given `panels = FALSE`.
#'
#' @section Columns:
#' Required columns are marked with an asterisk.
#' * `zones`: `id*`, `label*`, `text`, `note`, `tone`.
#'
#' @inheritParams add_links
#' @param zones A data frame with one row per zone. See "Columns". `NULL`, or a data frame with no rows (such as
#'   `data.frame()`), adds no zones.
#' @returns The widget, with the zones added. A widget that has zones already is an error of class
#'   `stagemap_error_layer`.
#' @family stage map
#' @examples
#' map <- stage_map(
#'   nodes = data.frame(id = "a", label = "Draft", stage = "w", lane = "docs", zone = "sign"),
#'   stages = data.frame(id = "w", label = "Write"),
#'   lanes = data.frame(id = "docs", label = "Docs")
#' ) |>
#'   add_zones(data.frame(id = "sign", label = "Needs sign-off"))
#' class(map)
#' @examplesIf interactive()
#' map
#' @export
add_zones <- function(x, zones, ...) {
  checkmate::assert_data_frame(zones, null.ok = TRUE)
  check_dots(...)
  sm_add_data(x, list(zones = none_if_empty(zones)), call = rlang::current_env())
}

#' Add steps to play through a stage map
#'
#' Turns the map into a story the reader plays step by step, with a caption for each step. Without steps, the map
#' has one step per stage and shows no player. Adding steps brings the step player, unless [stage_map()] was given
#' `player = FALSE`.
#'
#' A step can also change cards. `changes` lists, for each step, the cards whose status, stage or visibility change
#' when the reader reaches it, and they keep the change in the steps after it. A card moved to another stage glides
#' there, following the map's motion (see [stage_map()]). The change shows in the picture as a map drawn again at that
#' step.
#'
#' @section Columns:
#' Required columns are marked with an asterisk.
#' * `steps`: `id*`, `label*`, `kicker`, `text`, `stage` (the stage the step is about), `file`, `code`, `highlight`
#'   (a file's text and the lines to mark, as for a stage).
#' * `changes`: `step*` (a `steps` id), `card*` (a card id from the map's `nodes`), `status` (a status id, see the
#'   "Statuses" section of [stage_map()]), `stage` (a stage id: the card moves there), `hidden` (`TRUE` hides the card,
#'   `FALSE` shows it again). One row per card per step. `NA` in `status`, `stage` or `hidden` leaves that
#'   property as it was; a status can be changed to another, but not cleared.
#'
#' @inheritParams add_links
#' @param steps A data frame with one row per step, in playing order. See "Columns". `NULL`, or a data frame with no
#'   rows (such as `data.frame()`), adds no steps and no player.
#' @param changes A data frame with one row per card per step, or `NULL` (or no rows) for steps that change no card.
#'   Every `changes$step` must be an id in `steps$id`, every `changes$card` an id in the map's `nodes$id`, every
#'   `changes$stage` an id in its `stages$id` and every `changes$status` a status of the map; a card can change once
#'   at a step. An id that does not match, or a card changed twice at a step, is an error of class
#'   `stagemap_error_layer` that names the ids or rows (a missing column is an error of class `stagemap_error_data`).
#'   See "Columns".
#' @param intro The caption shown before the first step, as one string, or `NULL` for none. Added only with `steps`.
#' @returns The widget, with the steps added. A widget that has steps already is an error of class
#'   `stagemap_error_layer`.
#' @family stage map
#' @examples
#' map <- stage_map(
#'   nodes = data.frame(id = "a", label = "Draft", stage = "w", lane = "docs", status = "running"),
#'   stages = data.frame(id = c("w", "c"), label = c("Write", "Check")),
#'   lanes = data.frame(id = "docs", label = "Docs")
#' ) |>
#'   add_steps(
#'     data.frame(id = c("one", "two"), label = c("The draft starts", "The draft moves on")),
#'     changes = data.frame(step = "two", card = "a", status = "done", stage = "c"),
#'     intro = "How the notes were written"
#'   )
#' class(map)
#' @examplesIf interactive()
#' map
#' @export
add_steps <- function(x, steps, ..., changes = NULL, intro = NULL) {
  checkmate::assert_data_frame(steps, null.ok = TRUE)
  checkmate::assert_data_frame(changes, null.ok = TRUE)
  checkmate::assert_string(intro, min.chars = 1L, null.ok = TRUE)
  check_dots(...)
  call <- rlang::current_env()
  steps <- none_if_empty(steps)
  changes <- none_if_empty(changes)
  # The caption belongs to the steps: with no steps there is nothing to introduce, so none is added (a later call can).
  map <- sm_add_data(
    x,
    list(steps = steps, changes = changes),
    options = list(intro = if (!is.null(steps)) intro),
    call = call
  )
  # After the data's own checks, so a wrong type, a missing column or "already has steps" comes first.
  stage_map_check_changes(changes, steps, sm_widget_data(map), call)
  if (is.null(steps)) map else stage_map_show_player(map, call)
}

# Refuses `changes` the engine would refuse in the browser, with the values and the fix, in one error: a step `steps`
# lacks, a card or a stage the map lacks, a status the map does not know, a card changed twice at one step, or
# `changes` with no steps at all. `map_data` is the map's R data (its nodes, stages and statuses). Caller: add_steps(),
# which has asserted its arguments (`steps` is NULL when it was given none). A row's NA in step or card is the
# converter's to report, and so is a missing column, so the data keeps one message for each mistake.
stage_map_check_changes <- function(changes, steps, map_data, call) {
  if (is.null(changes)) {
    return(invisible(NULL))
  }
  if (is.null(steps)) {
    sm_abort(
      c("{.arg changes} needs {.arg steps}.", "i" = "Each row of {.arg changes} happens at a step: add the steps too."),
      class = "stagemap_error_layer",
      call = call
    )
  }
  unlisted <- function(found, known) {
    found <- as_text(found)
    unique(found[!is.na(found) & !found %in% as_text(known)])
  }
  bad_steps <- if ("step" %in% names(changes) && "id" %in% names(steps)) unlisted(changes$step, steps$id)
  bad_cards <- if ("card" %in% names(changes)) unlisted(changes$card, map_data$nodes$id)
  bad_stages <- if ("stage" %in% names(changes)) unlisted(changes$stage, map_data$stages$id)
  problems <- c(
    if (length(bad_steps) > 0L) {
      c(
        "x" = "{.field changes$step} has ids that {.field steps$id} lacks: {.val {bad_steps}}.",
        "i" = "Use an id from {.field steps$id}, or add that step to {.arg steps}."
      )
    },
    if (length(bad_cards) > 0L) {
      c(
        "x" = "{.field changes$card} has ids that are not cards of the map: {.val {bad_cards}}.",
        "i" = "Use an id from the map's {.field nodes$id}."
      )
    },
    if (length(bad_stages) > 0L) {
      c(
        "x" = "{.field changes$stage} has ids that are not stages of the map: {.val {bad_stages}}.",
        "i" = "Use an id from the map's {.field stages$id}."
      )
    },
    stage_map_status_problems(changes$status, "changes$status", map_data),
    stage_map_twice_problems(changes)
  )
  if (length(problems) > 0L) {
    sm_abort(
      c("{.arg changes} does not match the steps and cards.", problems),
      class = "stagemap_error_layer",
      call = call
    )
  }
  invisible(NULL)
}

# The error line for cards that `changes` changes twice at one step (the engine allows one row per card per step), with
# the rows to look at; NULL when there are none. Rows with an NA step or card are the converter's to report.
stage_map_twice_problems <- function(changes) {
  if (!all(c("step", "card") %in% names(changes))) {
    return(NULL)
  }
  step <- as_text(changes$step)
  card <- as_text(changes$card)
  key <- ifelse(is.na(step) | is.na(card), NA_character_, paste(step, card, sep = "\r"))
  repeated <- unique(key[!is.na(key) & duplicated(key)])
  if (length(repeated) == 0L) {
    return(NULL)
  }
  where <- vapply(
    repeated,
    function(one) {
      rows <- which(key == one)
      sprintf(
        "card \"%s\" at step \"%s\" (rows %s)",
        card[rows[[1]]],
        step[rows[[1]]],
        paste(rows, collapse = ", ")
      )
    },
    ""
  )
  c(
    "x" = cli_escape(paste0(
      cli::format_inline("{.field changes} changes a card twice at one step: "),
      paste(where, collapse = "; "),
      "."
    )),
    "i" = "Keep one row for each card at each step, with all its changes on it."
  )
}

#' Add variants to a stage map
#'
#' Variants are versions of one map that the reader switches between, such as a full release and a docs-only one. A
#' card or a link lists the variants it belongs to in its `variants` column; [stage_map()]'s `variant` says which to
#' start on.
#'
#' @section Columns:
#' Required columns are marked with an asterisk.
#' * `variants`: `id*`, `label*`.
#'
#' @inheritParams add_links
#' @param variants A data frame with one row per variant. See "Columns". `NULL`, or a data frame with no rows (such
#'   as `data.frame()`), adds no variants.
#' @returns The widget, with the variants added. A widget that has variants already is an error of class
#'   `stagemap_error_layer`.
#' @family stage map
#' @examples
#' map <- stage_map(
#'   nodes = data.frame(id = "a", label = "Draft", stage = "w", lane = "docs", variants = "full"),
#'   stages = data.frame(id = "w", label = "Write"),
#'   lanes = data.frame(id = "docs", label = "Docs"),
#'   variant = "full"
#' ) |>
#'   add_variants(data.frame(id = c("full", "docs"), label = c("Full release", "Docs only")))
#' class(map)
#' @examplesIf interactive()
#' map
#' @export
add_variants <- function(x, variants, ...) {
  checkmate::assert_data_frame(variants, null.ok = TRUE)
  check_dots(...)
  sm_add_data(x, list(variants = none_if_empty(variants)), call = rlang::current_env())
}
