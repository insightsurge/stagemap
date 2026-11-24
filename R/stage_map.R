#' Draw work moving through stages and lanes
#'
#' A stage map shows pieces of work (cards) placed in stages (columns) and lanes (rows), with a status on each card.
#' `stage_map()` draws the cards, stages and lanes, with a legend, the details of the card under the pointer, a side
#' panel for the chosen stage and the notes of the zones. It shows no title unless given one, and no step player unless
#' it has steps. Add the rest with the pipe: links with [add_links()], zones with [add_zones()], steps to play through
#' with [add_steps()] (which brings the player) and variants with [add_variants()].
#'
#' Each list in the picture is one data frame, one row per record, and ids join the lists the way a key joins two data
#' frames: a card's `stage` and `lane` name a stage id and a lane id. The engine that draws the map checks these joins
#' and shows what is wrong inside the widget.
#'
#' Column names are the engine's field names. A column the engine has no field for is not sent to it and gives no
#' warning: it stays in the data the widget keeps in R, so a table that carries more columns than the map needs can be
#' passed as it is. A name with no field inside an option, such as an entry of `statuses` that is not a built-in status
#' or a key in `highlight` that the engine does not know, is dropped with a warning that names it. An `NA` in an
#' optional column counts as left out. Ids are written as text, so `7` and `"7"` are the same id.
#'
#' @section Columns:
#' Required columns are marked with an asterisk.
#'
#' * `cards`: `id*`, `label*`, `stage*`, `lane*`, `sub` (a second line, such as a person), `status` (the id of a
#'   status: one of the five built-in ones, `"done"`, `"running"`, `"waiting"`, `"failed"` and `"skipped"`, or an id
#'   you add with `statuses`), `tone`, `text` (shown in the card's details), `zone` (a zone id, see [add_zones()]),
#'   `milestone` (`TRUE` to draw the card as a milestone; left out, it is `r sm_default("cards", "milestone")`),
#'   `variants` (variant ids separated by commas, such as `"full, docs"`; left out, the card is in every variant; see
#'   [add_variants()]).
#' * `stages`: `id*`, `label*`, `kicker`, `text`, `date` (a `Date`, or text like `"2026-03-02"`), `flag` (a word shown
#'   on the stage's head, such as `"Stuck"`), `tone` (the flag's colour), `file`, `code` (a file's text, shown in the
#'   side panel under `file`), `code_lines` (the lines of `code` to mark, such as `"3, 5-7"`).
#' * `lanes`: `id*`, `label*`, `tone`, `text`.
#'
#' A `cards` row can also have `hidden` (`TRUE` leaves the card out of the picture), `disabled` (`TRUE` dims it and
#' stops it being chosen) and `reason` (why the card is in its state; the map shows it on a disabled card); left out,
#' `hidden` and `disabled` are `r sm_default("cards", "hidden")` and `r sm_default("cards", "disabled")`.
#'
#' The `text` columns of `cards`, `stages`, `lanes`, `steps` and `zones`, and the `note` of a zone, are read as
#' Markdown, so `*word*`, backticks and `[words](https://example.org)` draw as formatting. A zone's `text` and `note`
#' are one line.
#'
#' A `tone` is one of `"teal"`, `"good"`, `"warn"`, `"bad"`, `"muted"`, `"orange"`, `"blue"`, `"violet"`, `"pink"`,
#' `"gold"` or `"grey"`.
#'
#' @section Statuses:
#' A card's `status` is the id of a status. Five are built in: `"done"`, `"running"`, `"waiting"`, `"failed"` and
#' `"skipped"`. The `statuses` argument takes two forms:
#'
#' * A named character vector, such as `c(done = "Pass", failed = "Not passed")`, gives your word for a built-in status
#'   (the short form). The names are built-in ids; any other name is dropped with a warning.
#' * A data frame has one row per status, with the columns `id*`, `label`, `tone` and `icon` (the name of one of the
#'   engine's icons). A row whose `id` is a built-in id restyles that status (its label, colour and icon), and does not
#'   add a sixth. A row with any other id adds a status of your own, such as `"blocked"`.
#'
#' `cards$status` (and the `status` of [add_steps()]'s `changes`) may then use any id from `statuses`; any other id is
#' an error of class `stagemap_error_data` that names it, lists the ids allowed and says to add it to `statuses`. An id
#' given twice in a `statuses` data frame is an error too. A `tone` is checked against the tones listed under
#' "Columns", and the error names the value and lists the ones allowed. Give `statuses` in one form per call.
#'
#' @section Scrolling and moving:
#' Stage headings and lane names stay in view while the reader scrolls the map, but only when the map sits in a box
#' that scrolls itself; a page that scrolls as a whole does not keep them in view. In the layout that stacks stage by
#' stage (a box under 500 pixels wide), only the stage headings stay in view.
#'
#' When a step of [add_steps()] moves a card to another stage, the card glides there, and a card that appears fades
#' in. The glide follows the reader's reduced-motion setting. `motion = FALSE` turns it off.
#'
#' @param cards A data frame with one row per card. Columns are listed under "Columns".
#' @param stages A data frame with one row per stage (a column of the picture). See "Columns".
#' @param lanes A data frame with one row per lane (a row of the picture). See "Columns". Links read best when they
#'   run along a lane, so choose lanes that follow the work's flow (a topic, a product, a team that hands work on),
#'   not lanes that most links have to cross; show who owns a card with its `sub` column instead.
#' @param ... Must stay empty. It makes every argument after it a named argument, and a typo in an option's name an
#'   error that names it.
#' @param title The map's title, as one string, drawn above it. `NULL` draws no title; the drawing is then named "Stage
#'   map" for screen readers.
#' @param layout One of the layouts the engine lists: `"grid"`, `"levels"` or `"dates"`. `NULL` uses the engine's
#'   default, `r sm_default("options", "layout")`. The grid puts stages in columns and lanes in rows; `"levels"` draws
#'   each lane as a band flowing into `target`; `"dates"` draws a table of lanes by stages with one stage per day and no
#'   links.
#' @param target The id of the card the levels layout flows into, as text or a whole number. `NULL` for none.
#' @param variant The id of the variant to start on (levels layout), from [add_variants()], as text or a whole number.
#'   `NULL` lets the engine choose.
#' @param statuses Your words and looks for the statuses, in one of two forms (see "Statuses"): a named character
#'   vector giving your word for a built-in status, such as `c(done = "Pass")`, or a data frame with the columns `id*`,
#'   `label`, `tone` and `icon`, one row per status. A data frame row with a built-in id restyles that status, and any
#'   other id adds a status. `NULL`, or a data frame with no rows, uses the engine's default words; a status you leave
#'   out keeps its default.
#' @param motion `FALSE` to move between steps without travelling dots and without the card gliding to its new stage,
#'   or `TRUE` to allow them. `NULL` uses the engine's default (`r sm_default("options", "motion")`). The reader's own
#'   reduced-motion setting is always respected.
#' @param legend `FALSE` hides the legend; `TRUE` or `NULL` shows it (the engine's default is
#'   `r sm_default("options", "legend")`).
#' @param cell_columns How many columns of cards a cell holds when a stage has several cards in one lane: a whole
#'   number from 1 to 6, or `"auto"` to let the map's width decide (up to 6). `NULL` uses the engine's default
#'   (`r sm_default("options", "cell_columns")`, one column). Six is the most because six cards side by side are wider
#'   than a screen and would scroll. It is one number for the whole map, and a stage with several columns is wider
#'   than the others. Only the `"grid"` layout uses it, and a box under 500 pixels wide, which stacks stage by stage,
#'   ignores it.
#' @param bundle_links `TRUE` draws the forward links of one card as a single trunk that splits next to the cards they
#'   reach, when three or more of them have the same kind and no label; other links are drawn as usual. `FALSE` or
#'   `NULL` draws every link on its own (the engine's default is `r sm_default("options", "bundle_links")`). Only the
#'   `"grid"` layout uses it, and a box under 500 pixels wide ignores it.
#' @param highlight Cards and links to keep clear from the first draw, with every other card and link faded: a named
#'   list with `ids` (card ids, none of them `NA`) and, optionally, `links` (a data frame with the columns `from*`,
#'   `to*` and `kind`, or a list of named lists; a data frame with no rows counts as none). With no `links`, every link
#'   between two lit cards is lit; with `links`, exactly those, and a link with no `kind` lights every link of that
#'   pair. A hidden card stays hidden. `NULL`, or an empty list, lights nothing special.
#' @param dismiss What a click outside the map does to the reader's pick (a chosen card, stage or step).
#'   `"no_outside"` keeps the pick, so a click on a Shiny button, a filter or a tab beside the map leaves it alone and a
#'   bookmark button can save it. `"any"` lets go of the pick on any click outside the map, as the engine does when
#'   given nothing. With either value the reader still lets go of a pick with Escape, a second click on it, or a click
#'   on empty space in the map. One of the values the engine lists.
#' @param player The step player: its buttons, caption and step list. `NULL` shows it once the map has steps from
#'   [add_steps()] and hides it before. `TRUE` always shows it (without steps, the engine plays one step per stage), and
#'   `FALSE` never does.
#' @param panels `TRUE`, the default, shows what the map holds below and beside the picture: the details of the card
#'   under the pointer or chosen, the side panel of the chosen stage and the notes of the zones. `FALSE` hides all
#'   three, for a page that shows them itself or none at all.
#' @param width,height A CSS size as text (such as `"100%"` or `"480px"`), a number of pixels, or `NULL`. The default
#'   width is `"100%"`, and the default height follows the picture's content.
#' @param element_id A fixed HTML id for the widget, or `NULL` to let the widget system choose one. Give one when the
#'   map is drawn inside [shiny::renderUI()], so its inputs have a known name.
#'
#' @returns An HTML widget (class `stagemap_widget`). Print it to view it, use it in R Markdown or Quarto, or pipe it
#'   into an `add_*()` function. A problem in the data is an error of class `stagemap_error_data` that lists up to ten
#'   problems with their paths.
#' @family stage map
#' @examples
#' map <- stage_map(
#'   cards = data.frame(
#'     id = c("draft", "review"),
#'     label = c("Draft", "Review"),
#'     stage = c("write", "check"),
#'     lane = c("docs", "docs"),
#'     status = c("done", "running")
#'   ),
#'   stages = data.frame(id = c("write", "check"), label = c("Write", "Check")),
#'   lanes = data.frame(id = "docs", label = "Docs"),
#'   title = "A small piece of work"
#' ) |>
#'   add_links(data.frame(from = "draft", to = "review"))
#' class(map)
#' @examplesIf interactive()
#' map
#' @export
stage_map <- function(
  cards,
  stages,
  lanes,
  ...,
  title = NULL,
  layout = NULL,
  target = NULL,
  variant = NULL,
  statuses = NULL,
  motion = NULL,
  legend = NULL,
  cell_columns = NULL,
  bundle_links = NULL,
  highlight = NULL,
  dismiss = "no_outside",
  player = NULL,
  panels = TRUE,
  width = NULL,
  height = NULL,
  element_id = NULL
) {
  checkmate::assert_data_frame(cards)
  checkmate::assert_data_frame(stages)
  checkmate::assert_data_frame(lanes)
  checkmate::assert_string(title, min.chars = 1L, null.ok = TRUE)
  checkmate::assert_choice(layout, sm_spec()$fields$options$fields$layout$values, null.ok = TRUE)
  assert_id_option(target)
  assert_id_option(variant)
  checkmate::assert(
    checkmate::check_character(statuses, any.missing = FALSE, min.len = 1L, names = "unique", null.ok = TRUE),
    checkmate::check_data_frame(statuses),
    .var.name = "statuses (a named character vector or a data frame)"
  )
  checkmate::assert_flag(motion, null.ok = TRUE)
  checkmate::assert_flag(legend, null.ok = TRUE)
  checkmate::assert(
    checkmate::check_int(cell_columns, lower = 1L, upper = 6L, null.ok = TRUE),
    checkmate::check_choice(cell_columns, "auto"),
    .var.name = "cell_columns (a whole number from 1 to 6, or \"auto\")"
  )
  checkmate::assert_flag(bundle_links, null.ok = TRUE)
  checkmate::assert_list(highlight, names = "unique", null.ok = TRUE)
  assert_dismiss(dismiss)
  checkmate::assert_flag(player, null.ok = TRUE)
  checkmate::assert_flag(panels)
  assert_widget_args(width, height, element_id)
  check_dots(...)
  call <- rlang::current_env()
  highlight <- normalise_highlight(highlight, call)

  # The engine's regions the page may host itself: with `panels = FALSE` the three panels go to a host that is not
  # there, so they do not show; the step player stays out of sight until add_steps() brings it, unless it is asked for.
  # The player choice is kept with the widget, so add_steps() can follow it.
  hosted <- c(if (!panels) stage_map_panel_regions, if (!isTRUE(player)) "steps")
  # The two forms of `statuses`: words for the built-in statuses go to the engine's options, rows go to its data.
  rows <- if (is.data.frame(statuses) && nrow(statuses) > 0L) statuses
  options <- list(
    layout = layout,
    title = title,
    motion = motion,
    target = target,
    variant = variant,
    statuses = if (is.character(statuses)) statuses,
    legend = legend,
    cell_columns = if (is.numeric(cell_columns)) as.integer(cell_columns) else cell_columns,
    bundle_links = bundle_links,
    highlight = highlight,
    dismiss = dismiss,
    hosted = if (length(hosted) > 0L) hosted
  )
  data <- list(
    options = drop_nulls(options),
    stages = stages,
    lanes = lanes,
    cards = cards,
    statuses = rows
  )
  widget <- sm_widget(
    drop_nulls(data),
    width,
    height,
    element_id,
    call = call,
    keep = list(player = player)
  )
  # After the converter, so a missing column or a bad tone is reported first, with the rest of the data's problems.
  stage_map_check_statuses(drop_nulls(data), call)
  widget
}

# A whole number or a non-empty string, as the engine's `id` and `scalar` types take an id: 7 and "7" are the same id.
# `null.ok` because NULL leaves the option out.
assert_id_option <- function(x, label = checkmate::vname(x)) {
  checkmate::assert(
    checkmate::check_string(x, min.chars = 1L, null.ok = TRUE),
    checkmate::check_int(x),
    .var.name = paste0(label, " (one id: text, or a whole number)")
  )
}

# The `highlight` argument as the option the engine reads, or NULL when it holds nothing to light: NULL items and an
# empty `links` data frame count as left out, and an NA among the ids is refused (the converter takes an NA in an
# optional field as left out, which would light nothing without saying so). `highlight` was checked as a list.
normalise_highlight <- function(highlight, call) {
  checkmate::assert_list(highlight, null.ok = TRUE)
  checkmate::assert_environment(call)
  if (is.null(highlight)) {
    return(NULL)
  }
  highlight <- drop_nulls(highlight)
  if (is.data.frame(highlight$links) && nrow(highlight$links) == 0L) {
    highlight$links <- NULL
  }
  if (anyNA(highlight$ids)) {
    sm_abort(
      c(
        "The data cannot be turned into what the stage-map engine reads.",
        "x" = "`options$highlight$ids` must have no NA: give the ids of the cards to light."
      ),
      class = "stagemap_error_data",
      problems = "`options$highlight$ids` must have no NA: give the ids of the cards to light.",
      call = call
    )
  }
  if (length(highlight) > 0L) highlight
}

# The regions of the engine that `panels = FALSE` hands over to the host: the details of a card, the stage's side panel
# and the zone notes. Named in the contract's `hosted` option, which a test checks.
stage_map_panel_regions <- c("details", "stage", "zones")

# `x` without its NULL items.
drop_nulls <- function(x) {
  checkmate::assert_list(x)
  x[!vapply(x, is.null, logical(1))]
}

# The contract's default for the field `name` of `block` (`"options"`, or the name of a data list such as `"cards"`),
# written as it reads in a help page. Used by the roxygen text only, so a help page cannot state a default the engine
# does not have.
sm_default <- function(block, name) {
  checkmate::assert_string(block, min.chars = 1L)
  checkmate::assert_string(name, min.chars = 1L)
  value <- sm_spec()$fields[[block]]$fields[[name]]$default
  if (is.null(value)) {
    sm_abort(
      "The engine's contract gives {.field {block}${name}} no default.",
      class = "stagemap_error_spec",
      call = NULL
    )
  }
  if (is.character(value)) paste0("`\"", value, "\"`") else paste0("`", format(value), "`")
}

# The map `x` with its step player shown, unless stage_map() was given player = FALSE.
stage_map_show_player <- function(x, call) {
  checkmate::assert_class(x, "stagemap_widget")
  checkmate::assert_environment(call)
  if (isFALSE(x$stagemap$keep$player)) {
    return(x)
  }
  data <- sm_widget_data(x)
  hosted <- setdiff(data$options$hosted, "steps")
  data$options$hosted <- if (length(hosted) > 0L) hosted
  sm_rebuild(x, data, call = call)
}

# The status ids a map knows: the five the engine builds in (the keys of the `statuses` option) and the ids of the
# `statuses` data frame, when the map has one. `data` is the map's R data.
stage_map_status_ids <- function(data) {
  built_in <- names(sm_spec()$fields$options$fields$statuses$fields)
  unique(c(built_in, if (is.data.frame(data$statuses)) as_text(data$statuses$id)))
}

# The error lines for the status ids in `found` (a column named `field`, such as "cards$status") that the map does not
# know, with the ids allowed and the fix; NULL when all are known. The text is ready to use in a cli message. Callers:
# stage_map_check_statuses() and stage_map_check_changes().
stage_map_status_problems <- function(found, field, data) {
  found <- as_text(found)
  known <- stage_map_status_ids(data)
  bad <- unique(found[!is.na(found) & !found %in% known])
  if (length(bad) == 0L) {
    return(NULL)
  }
  lines <- c(
    "x" = cli::format_inline("{.field {field}} has statuses that are not known: {.val {bad}}."),
    "i" = cli::format_inline(
      "Known statuses: {.val {known}}. To use another one, add it to {.arg statuses} of {.fn stage_map}, ",
      "as a data frame with an {.field id} column."
    )
  )
  stats::setNames(cli_escape(lines), names(lines))
}

# Refuses what the engine refuses in the browser about statuses, with the values and the fix: a card whose `status` is
# not a status of the map, and a `statuses` data frame that gives an id twice. `data` is the map's R data, already
# accepted by the converter, so its columns exist. Caller: stage_map().
stage_map_check_statuses <- function(data, call) {
  twice <- if (is.data.frame(data$statuses)) {
    ids <- as_text(data$statuses$id)
    unique(ids[!is.na(ids) & duplicated(ids)])
  }
  problems <- c(
    stage_map_status_problems(data$cards$status, "cards$status", data),
    if (length(twice) > 0L) {
      c(
        "x" = cli_escape(cli::format_inline("{.field statuses$id} has ids given more than once: {.val {twice}}.")),
        "i" = "Give each status one row."
      )
    }
  )
  if (length(problems) > 0L) {
    sm_abort(
      c("The statuses do not match the cards.", problems),
      class = "stagemap_error_data",
      call = call
    )
  }
  invisible(NULL)
}
