# The stage map in Shiny: the output, the render function, the proxy and the six verbs. The plumbing they stand on (the
# proxy object, the queue of commands, the readers of what the page reports) is in shiny.R.

# The ids of a verb as text, without repeats, in the order given. `NULL` and a vector of length zero are `character(0)`:
# the empty choice. Ids are text or whole numbers and never `NA`, and are compared as text (7 and "7" are one id).
sm_ids <- function(ids, arg = "ids", unique = TRUE) {
  checkmate::assert_string(arg, min.chars = 1L)
  checkmate::assert_flag(unique)
  if (length(ids) == 0L) {
    return(character())
  }
  # A factor is its labels, as it is in the cards' table.
  if (is.factor(ids)) {
    ids <- as.character(ids)
  }
  # Whole numbers of any size: checkmate's integerish check stops at the largest integer, and stage_map() does not.
  whole <- is.numeric(ids) && all(is.finite(ids)) && all(ids == round(ids))
  checkmate::assert(
    checkmate::check_character(ids, any.missing = FALSE, min.chars = 1L),
    checkmate::check_true(whole),
    .var.name = paste0(arg, " (ids: text or whole numbers, none missing)")
  )
  text <- as_text(ids)
  if (unique) base::unique(text) else text
}

# What `map` is, for a verb: "proxy" (made by stage_map_proxy()) or "widget" (made by stage_map()), or a classed error.
# A widget is refused unless the verb takes one (`widget_ok`), and anything else is refused. `call` is the verb.
sm_map_kind <- function(map, widget_ok, call) {
  checkmate::assert_flag(widget_ok)
  checkmate::assert_environment(call)
  if (inherits(map, "stagemap_proxy")) {
    return("proxy")
  }
  if (inherits(map, "stagemap_widget")) {
    if (widget_ok) {
      return("widget")
    }
    sm_abort(
      c(
        "{.arg map} must be a map drawn in Shiny: this function changes a map that is already on the page.",
        "i" = "Make a proxy with {.fn stage_map_proxy} and give that as {.arg map}."
      ),
      class = "stagemap_error_widget",
      call = call
    )
  }
  sm_abort(
    c(
      if (widget_ok) {
        "{.arg map} must be a proxy made by {.fn stage_map_proxy} or a widget made by {.fn stage_map}."
      } else {
        "{.arg map} must be a proxy made by {.fn stage_map_proxy}."
      },
      "x" = "It is {.cls {class(map)}}."
    ),
    class = "stagemap_error_widget",
    call = call
  )
}

# Sends `command` once for each of `ids` (the engine takes one id for show, hide, enable and disable). `extra` is a
# list of what else each command carries, one item per id or one for all. Returns the proxy, invisibly.
sm_send_each <- function(proxy, command, ids, extra = list(), call = rlang::caller_env()) {
  checkmate::assert_class(proxy, "stagemap_proxy")
  checkmate::assert_string(command, min.chars = 1L)
  checkmate::assert_character(ids, any.missing = FALSE)
  checkmate::assert_list(extra, names = "unique")
  checkmate::assert_environment(call)
  for (i in seq_along(ids)) {
    each <- lapply(extra, function(item) if (length(item) == 1L) item else item[[i]])
    sm_send(proxy, command, data = c(list(id = ids[[i]]), each), call = call)
  }
  invisible(proxy)
}

#' Show a stage map in a Shiny app
#'
#' `stage_map_output()` puts a map in the user interface and `render_stage_map()` draws a [stage_map()] in it from the
#' server. `stage_map_proxy()` makes the proxy that the verbs ([stage_map_select()], [stage_map_highlight()],
#' [stage_map_show()], [stage_map_hide()], [stage_map_enable()] and [stage_map_disable()]) send their commands
#' through, so the map changes without being drawn again.
#'
#' The map is drawn again whenever the expression of `render_stage_map()` gives a new map, in place. The reader's pick
#' stays while its card is still in the new map, and is let go when the card is gone: `input$map_pick` then reports it
#' with `by = "data"`. A map in a tab that is not shown yet is drawn when the tab is
#' shown, and one inside [shiny::renderUI()], [shiny::insertUI()], a module or a modal works as it does anywhere else.
#' In a module, give the output `ns("map")` and the proxy `"map"` (the plain or the namespaced id both work); the inputs
#' below keep the module's own names, so the server reads `input$map_selected`.
#'
#' @section Inputs:
#' For an output with the id `map`, the server reads these inputs. A value that holds ids is a character vector, and
#' no ids is `character(0)`: `req(input$map_selected)` waits until something is selected.
#'
#' * `input$map_selected`: the ids of the selected cards, the lead (the one whose details show) last. It changes when
#'   the selection changes, whether the reader, a verb or new data changed it, and it is `character(0)` while nothing
#'   is selected. When the reader picks a card, `input$map_pick` changes in the same message, so an observer of the
#'   pick reads the new selection.
#' * `input$map_hovered` `r lifecycle::badge("experimental")`: the id of the card under the pointer, or `character(0)`
#'   when there is none. A stage under the pointer is not reported.
#' * `input$map_pick`: the reader's last pick, as a list of `kind` (`"card"`, `"stage"` or `"all"` when the reader let
#'   go of everything), `id` (the lead card, or the stage), `ids` (the picked cards, the lead last, or the stage's id),
#'   `from` (the id that was picked before), `label`, `still` and `by` (`"reader"`, or `"data"` when new data changed
#'   the pick). A field with nothing to say is `NULL`, and `ids` is `character(0)`; `still` is `NULL`, or a list of
#'   `kind`, `id` and `ids` for the pick that stays when the reader lets go of the other kind (a card stays picked
#'   when the stage is let go). It changes when the reader picks or lets go, and when new data changes the pick, never
#'   for a verb. Fields may be added later and none will be removed. `ids` belongs with `kind`: for a stage pick it
#'   holds the stage's id, so read the selected cards from `input$map_selected`.
#' * `input$map_state`: what the map holds now, as a list of `selected` (the selected card ids, the lead last),
#'   `stage` (the chosen stage's id, or `character(0)`), `step` (the step the player shows, counting from 1; `0` at
#'   the start or without a player), `highlighted` (a list of `ids` and `links`, a data frame with the columns `from`,
#'   `to` and `kind`, with no rows when none), `hidden` and `disabled` (card ids). It changes when any of them
#'   changes. `stage_map_highlight(proxy, state$highlighted$ids, links = state$highlighted$links)` puts back what the
#'   state holds.
#'
#' Bookmarking in Shiny does not save the map's selection or what a verb changed. To restore them, save
#' `input$map_selected` yourself and give it to [stage_map_select()] when the app is restored.
#'
#' @param output_id The output's id, as one string. In a module, give `ns("map")` to `stage_map_output()`; the proxy
#'   takes the plain `"map"` or the namespaced id.
#' @param width,height The output's CSS size as text (such as `"100%"` or `"480px"`) or a number of pixels. The
#'   default height, `"auto"`, follows the picture's content; any other height makes the output a box that scrolls
#'   inside, so a map taller than the box does not spill over what follows.
#' @param expr An expression that gives a [stage_map()] widget, or `NULL` to show nothing. A promise of one works too.
#' @param env The environment in which to evaluate `expr`.
#' @param quoted Whether `expr` is already a quoted expression.
#' @param session The Shiny session. The default is the current one, so a proxy is made inside the server function.
#' @param ... Must stay empty. It makes every argument after it a named argument.
#' @param defer_until_flush `TRUE`, the default, sends a command after the outputs of the current flush, so a command
#'   sent in the same observer as a new map reaches the page after the map. `FALSE` sends it at once.
#'
#' @returns `stage_map_output()` returns the HTML of the output. `render_stage_map()` returns a render function for an
#'   output; anything but a [stage_map()] widget (or `NULL`) is an error of class `stagemap_error_widget`.
#'   `stage_map_proxy()` returns a proxy (class `stagemap_proxy`) to give as `map` to the verbs.
#' @family shiny
#' @examplesIf requireNamespace("shiny", quietly = TRUE)
#' # The output goes in the user interface; it is a piece of HTML.
#' class(stage_map_output("map", "100%", "480px"))
#' @examplesIf interactive()
#' library(shiny)
#' cards <- data.frame(
#'   id = c("draft", "review", "publish"),
#'   label = c("Draft", "Review", "Publish"),
#'   stage = c("write", "check", "ship"),
#'   lane = "docs"
#' )
#' ui <- fluidPage(
#'   stage_map_output("map", height = "420px"),
#'   verbatimTextOutput("picked"),
#'   actionButton("publish", "Select Publish")
#' )
#' server <- function(input, output, session) {
#'   output$map <- render_stage_map(
#'     stage_map(cards, title = "A small piece of work") |>
#'       add_links(data.frame(from = c("draft", "review"), to = c("review", "publish")))
#'   )
#'   output$picked <- renderPrint(input$map_selected)
#'   observeEvent(input$publish, {
#'     stage_map_proxy("map") |> stage_map_select("publish")
#'   })
#' }
#' shinyApp(ui, server)
#' @export
stage_map_output <- function(output_id, width = "100%", height = "auto") {
  checkmate::assert_string(output_id, min.chars = 1L)
  assert_widget_args(width, height, NULL)
  rlang::check_installed("shiny")
  out <- htmlwidgets::shinyWidgetOutput(output_id, "stage_map", width, height, package = "stagemap")
  # A fixed height is a box: a map taller than it scrolls inside it and does not spill over what follows.
  if (!is.null(height) && !identical(height, "auto")) {
    out[[1]] <- htmltools::tagAppendAttributes(out[[1]], style = "overflow: auto;")
  }
  out
}

#' @rdname stage_map_output
#' @export
render_stage_map <- function(expr, env = parent.frame(), quoted = FALSE) {
  checkmate::assert_environment(env)
  checkmate::assert_flag(quoted)
  rlang::check_installed("shiny")
  if (!quoted) {
    expr <- substitute(expr)
  }
  checked <- as.call(list(sm_checked_widget, expr))
  htmlwidgets::shinyRenderWidget(checked, stage_map_output, env, quoted = TRUE)
}

#' @rdname stage_map_output
#' @export
stage_map_proxy <- function(
  output_id,
  session = shiny::getDefaultReactiveDomain(),
  ...,
  defer_until_flush = TRUE
) {
  rlang::check_installed("shiny")
  checkmate::assert_string(output_id, min.chars = 1L)
  checkmate::assert_flag(defer_until_flush)
  check_dots(...)
  sm_proxy(output_id, session, defer_until_flush)
}

#' Change a stage map in Shiny without drawing it again
#'
#' Six verbs that act on a map already on the page, through a proxy from [stage_map_proxy()]. Each takes the proxy
#' first and returns it invisibly, so calls pipe. They change what the reader sees and what `input$<id>_selected` and
#' `input$<id>_state` report (see [stage_map_output()]); a verb never changes `input$<id>_pick`, which is the reader's.
#'
#' * `stage_map_select()` selects the cards in `ids`, the last as the lead, and lets go of what was selected before.
#' * `stage_map_highlight()` keeps the cards in `ids` and the links between them clear and fades the rest.
#' * `stage_map_show()` and `stage_map_hide()` show a card again and hide it.
#' * `stage_map_enable()` and `stage_map_disable()` take a card out of use and put it back. A disabled card is greyed
#'   out, the reader cannot select it, and the map shows the `reason`.
#'
#' `stage_map_highlight()` also takes a [stage_map()] widget, to light cards from the first draw: it checks the ids
#' against the map, replaces what an earlier call lit, and returns the widget. The other five need a map that is
#' drawn, so a widget is an error of class `stagemap_error_widget`.
#'
#' Ids are text or whole numbers and are compared as text, so `7` and `"7"` are one id. `ids` has no default, so a
#' forgotten argument is an error and never a silent clear. `NULL` and a vector of length zero mean no ids:
#' `stage_map_select()` and `stage_map_highlight()` let go, and the other four do nothing. A card the map does not
#' have is not an error for a proxy, which does not know the map: the page writes a warning to the browser's
#' console and changes nothing. `stage_map_show()`, `stage_map_hide()`, `stage_map_enable()` and `stage_map_disable()`
#' send one command for each id.
#'
#' `r lifecycle::badge("experimental")` `stage_map_show()`, `stage_map_hide()`, `stage_map_enable()` and
#' `stage_map_disable()` may change.
#'
#' @param map A proxy made by [stage_map_proxy()]. `stage_map_highlight()` also takes a [stage_map()] widget.
#' @param ids The ids of the cards, as text or whole numbers with none missing; `NULL` or a vector of length zero for
#'   none. It has no default.
#' @param ... Must stay empty. It makes every argument after it a named argument.
#' @param links A data frame with the columns `from` and `to` (card ids) and, if wanted, `kind`, or `NULL`. It lights
#'   exactly those links instead of every link between two lit cards; a link with no `kind` lights every link of that
#'   pair. Both ends must be in `ids`, so `links` with no `ids` is an error; a data frame with no rows counts as
#'   `NULL`. The `links` of `input$<id>_state$highlighted` can be given back as they are.
#' @param reason Why the card is disabled, shown to the reader: one string for all the ids, or one for each id. It has
#'   no default and cannot be blank.
#'
#' @returns The `map`: a proxy is returned invisibly, a widget (`stage_map_highlight()` only) as it is, with the
#'   highlight set. An id that a widget does not have is an error of class `stagemap_error_id`, a link that does not
#'   join `ids` an error of class `stagemap_error_data`, and a `map` of the wrong kind an error of class
#'   `stagemap_error_widget`.
#' @family shiny
#' @examples
#' map <- stage_map(
#'   cards = data.frame(
#'     id = c("draft", "review", "publish"),
#'     label = c("Draft", "Review", "Publish"),
#'     stage = c("write", "check", "ship"),
#'     lane = "docs"
#'   )
#' ) |>
#'   add_links(data.frame(from = c("draft", "review"), to = c("review", "publish")))
#' # Light two cards from the first draw; the link between them stays clear and the rest fades.
#' lit <- stage_map_highlight(map, c("draft", "review"))
#' class(lit)
#' @examplesIf interactive()
#' library(shiny)
#' cards <- data.frame(
#'   id = c("draft", "review", "publish"),
#'   label = c("Draft", "Review", "Publish"),
#'   stage = c("write", "check", "ship"),
#'   lane = "docs"
#' )
#' ui <- fluidPage(
#'   stage_map_output("map", height = "420px"),
#'   actionButton("hide", "Hide Review"),
#'   actionButton("show", "Show Review"),
#'   actionButton("block", "Disable Publish")
#' )
#' server <- function(input, output, session) {
#'   output$map <- render_stage_map(
#'     stage_map(cards) |>
#'       add_links(data.frame(from = c("draft", "review"), to = c("review", "publish")))
#'   )
#'   proxy <- stage_map_proxy("map")
#'   observeEvent(input$hide, stage_map_hide(proxy, "review"))
#'   observeEvent(input$show, stage_map_show(proxy, "review"))
#'   observeEvent(input$block, stage_map_disable(proxy, "publish", reason = "Waiting for the review"))
#'   # Light the cards that are selected, and let go when nothing is.
#'   observeEvent(input$map_selected, ignoreNULL = FALSE, {
#'     stage_map_highlight(proxy, input$map_selected)
#'   })
#' }
#' shinyApp(ui, server)
#' @name stage_map_select
#' @export
stage_map_select <- function(map, ids) {
  call <- rlang::current_env()
  sm_map_kind(map, widget_ok = FALSE, call = call)
  ids <- sm_ids(ids)
  sm_send(map, "select", data = if (length(ids) > 0L) list(kind = "card", ids = I(ids)), call = call)
  invisible(map)
}

#' @rdname stage_map_select
#' @export
stage_map_highlight <- function(map, ids, ..., links = NULL) {
  call <- rlang::current_env()
  kind <- sm_map_kind(map, widget_ok = TRUE, call = call)
  checkmate::assert_data_frame(links, null.ok = TRUE)
  check_dots(...)
  ids <- sm_ids(ids)
  links <- sm_highlight_links(links, ids, call)
  if (identical(kind, "widget")) {
    return(sm_highlight_widget(map, ids, links, call))
  }
  data <- if (length(ids) > 0L) drop_nulls(list(ids = I(ids), links = links))
  sm_send(map, "highlight", data = data, call = call)
  invisible(map)
}

#' @rdname stage_map_select
#' @export
stage_map_show <- function(map, ids) {
  call <- rlang::current_env()
  sm_map_kind(map, widget_ok = FALSE, call = call)
  sm_send_each(map, "show", sm_ids(ids), call = call)
}

#' @rdname stage_map_select
#' @export
stage_map_hide <- function(map, ids) {
  call <- rlang::current_env()
  sm_map_kind(map, widget_ok = FALSE, call = call)
  sm_send_each(map, "hide", sm_ids(ids), call = call)
}

#' @rdname stage_map_select
#' @export
stage_map_enable <- function(map, ids) {
  call <- rlang::current_env()
  sm_map_kind(map, widget_ok = FALSE, call = call)
  sm_send_each(map, "enable", sm_ids(ids), call = call)
}

#' @rdname stage_map_select
#' @export
stage_map_disable <- function(map, ids, reason) {
  call <- rlang::current_env()
  sm_map_kind(map, widget_ok = FALSE, call = call)
  ids <- sm_ids(ids, unique = FALSE)
  # One reason for all the ids, or one for each (counted before a repeated id is dropped); blank means only spaces.
  checkmate::assert_character(reason, any.missing = FALSE, min.len = 1L, len = if (length(reason) > 1L) length(ids))
  checkmate::assert_character(trimws(reason), min.chars = 1L, .var.name = "reason (not blank)")
  once <- !duplicated(ids)
  sm_send_each(map, "disable", ids[once], list(reason = if (length(reason) > 1L) reason[once] else reason), call = call)
}

# The `links` of stage_map_highlight() as the engine reads them: NULL for none (also a data frame with no rows), else
# the rows with `from` and `to` as text and `kind` as text (left out when no row has one). Both ends of every link
# must be in `ids`, and a link needs lit cards to join, so links with no ids are refused.
sm_highlight_links <- function(links, ids, call) {
  checkmate::assert_data_frame(links, null.ok = TRUE)
  checkmate::assert_character(ids, any.missing = FALSE)
  checkmate::assert_environment(call)
  if (is.null(links) || nrow(links) == 0L) {
    return(NULL)
  }
  checkmate::assert_names(names(links), must.include = c("from", "to"), .var.name = "names(links)")
  if (length(ids) == 0L) {
    sm_abort(
      c(
        "{.arg links} needs {.arg ids}.",
        "i" = "A link is lit only between cards that are lit: give both ends in {.arg ids}."
      ),
      class = "stagemap_error_data",
      call = call
    )
  }
  # The ends are checked here (none missing, none blank); they are used as given below.
  sm_ids(links$from, "links$from")
  sm_ids(links$to, "links$to")
  out <- data.frame(from = as_text(links$from), to = as_text(links$to))
  kind <- if (!is.null(links$kind)) as_text(links$kind)
  if (!is.null(kind) && !all(is.na(kind))) {
    out$kind <- kind
  }
  outside <- setdiff(c(out$from, out$to), ids)
  if (length(outside) > 0L) {
    sm_abort(
      c(
        "{.arg links} joins cards that are not in {.arg ids}: {.val {outside}}.",
        "i" = "A link is lit only between cards that are lit: add them to {.arg ids}, or leave the link out."
      ),
      class = "stagemap_error_data",
      call = call
    )
  }
  out
}

# The map `map` (a stage_map() widget) drawn again with `ids` and `links` lit, in place of what an earlier call lit:
# none lets go. The ids must be cards of the map.
sm_highlight_widget <- function(map, ids, links, call) {
  checkmate::assert_class(map, "stagemap_widget")
  checkmate::assert_character(ids, any.missing = FALSE)
  checkmate::assert_data_frame(links, null.ok = TRUE)
  checkmate::assert_environment(call)
  data <- sm_widget_data(map)
  unknown <- setdiff(ids, as_text(data$cards$id))
  if (length(unknown) > 0L) {
    sm_abort(
      c(
        "{.arg ids} has cards that the map does not have: {.val {unknown}}.",
        "i" = "Use an id from {.field cards$id}."
      ),
      class = "stagemap_error_id",
      call = call
    )
  }
  data$options <- as.list(data$options)
  data$options$highlight <- if (length(ids) > 0L) drop_nulls(list(ids = I(ids), links = links))
  sm_rebuild(map, data, call = call)
}
