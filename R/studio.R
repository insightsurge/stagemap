#' Change a stage map in an app, then take it back to R
#'
#' `r lifecycle::badge("experimental")` `stage_map_studio()` opens the stagemap studio, a 'Shiny' app that shows a map
#' on a drawing sheet and changes it through forms. Click a card, a stage, a lane or a link on the map, or choose one
#' from the **Stages** and **Lanes** menus, and a form opens for it; there you edit its fields, connect cards, reorder
#' stages and lanes and remove things. The studio edits through forms and does not drag. The map's title is above the
#' map, and a journal under it lists the changes made since the map was opened, with **Undo**.
#'
#' The rooms along the bottom each answer a question about the map:
#' * **Map** sets the arguments of [stage_map()] that shape the drawing: the layout (grid, levels or dates; the last
#'   two are experimental), the cards per cell, bundled links and the legend.
#' * **Ask** runs [sm_trace()], [sm_orphans()] or [sm_missing()] on the map, lights the cards of the answer on the map
#'   and shows the call as R code. An edit marks the answer as out of date.
#' * **Check** shows what R says when [stage_map()] stops on the map, and one card for each place at fault (a blank id
#'   or label, an id given twice, a link or card that points at nothing) with the fixes it offers. While the map does
#'   not build, the map shows the last version that worked, and **Done** is refused.
#' * **R code** shows the code that builds the map, with the lines changed since the map was opened marked, and
#'   **Copy**, a `.R` download and a CSV download for each table. **Copy** copies the code for the latest change, also
#'   when the click comes before the server has answered.
#'
#' On the built-in example, a guide called **Try it** lists six steps and ticks each one when it is done. Kinds,
#' zones, statuses, steps, changes and variants are carried through the studio and written into the code, but have no
#' form. Click **Done** to close the studio and return the map to R; closing its page without **Done** returns `NULL`.
#' The studio runs in this R session, and it can be used from the keyboard and on a phone-sized screen.
#'
#' Experimental means the studio's names, arguments and layout can still change before the first release.
#'
#' @param map A [stage_map()] widget to open the studio on, or `NULL` (the default) to open on the built-in example map
#'   with the start card.
#' @param ... Must stay empty. It makes every argument after it a named argument, and a typo in an argument's name an
#'   error.
#' @param run `TRUE` (the default) runs the studio and waits for it to close; it needs an interactive R session.
#'   `FALSE` returns the app without running it, for [shiny::runApp()] or a test.
#' @returns With `run = TRUE`, the map from **Done** (a [stage_map()] widget, with the changes made in the studio),
#'   invisibly, or `NULL` invisibly when the studio's page was closed without **Done**. With `run = FALSE`, the app, a
#'   `shiny.appobj`.
#' @examples
#' if (rlang::is_installed("shiny")) {
#'   cards <- data.frame(
#'     id = c("draft", "review"),
#'     label = c("Draft", "Review"),
#'     stage = c("write", "check"),
#'     lane = "docs"
#'   )
#'   map <- stage_map(cards)
#'   app <- stage_map_studio(map, run = FALSE)
#'   class(app)
#' }
#' @examplesIf interactive()
#' map <- stage_map_studio()
#' @export
stage_map_studio <- function(map = NULL, ..., run = TRUE) {
  call <- rlang::current_env()
  if (!is.null(map) && !inherits(map, "stagemap_widget")) {
    sm_abort(
      c("{.arg map} must be a widget made by a stagemap function, or NULL.", "x" = "It is {.cls {class(map)}}."),
      class = "stagemap_error_widget",
      call = call
    )
  }
  checkmate::assert_flag(run)
  check_dots(...)
  rlang::check_installed("shiny", reason = "to run the stagemap studio.", version = "1.7.5")
  app <- studio_app(map, stop_when_closed = run)
  if (!run) {
    return(app)
  }
  if (!studio_interactive()) {
    sm_abort(
      c(
        "The studio needs an interactive R session.",
        "i" = "Use {.code run = FALSE} to get the app without running it."
      ),
      class = "stagemap_error_studio",
      call = call
    )
  }
  invisible(studio_run(app))
}

# The studio as a Shiny app: the module `studio` on its own page. `on_done` is called with the map from Done (by
# default it stops the app, whose value is then that map); `options` are the page's settings (studio_options()). The
# server closes over `map`: no option, global or query string carries it. With `stop_when_closed` (the app that
# stage_map_studio() runs for its caller) the app also stops, with the value NULL, once its last page has been gone for
# a second without a Done, so closing the tab returns the call; a page that reloads has its new session by then.
studio_app <- function(map = NULL, on_done = shiny::stopApp, options = list(), stop_when_closed = FALSE) {
  checkmate::assert_class(map, "stagemap_widget", null.ok = TRUE)
  checkmate::assert_function(on_done)
  studio_options(options)
  checkmate::assert_flag(stop_when_closed)
  # From 1.7.5 Shiny leaves an input marked data-shiny-no-bind-input alone, which the studio's fields need.
  rlang::check_installed("shiny", version = "1.7.5")
  app <- new.env(parent = emptyenv())
  app$sessions <- 0L
  app$done <- FALSE
  shiny::shinyApp(
    ui = function(request) studio_ui("studio", options),
    server = function(input, output, session) {
      app$sessions <- app$sessions + 1L
      done <- function(map) {
        app$done <- TRUE
        on_done(map)
      }
      studio_server("studio", map, done, options)
      if (stop_when_closed) {
        session$onSessionEnded(function() {
          app$sessions <- app$sessions - 1L
          studio_after(1, function() {
            if (app$sessions == 0L && !app$done) studio_stop()
          })
        })
      }
    }
  )
}

# Calls `fn` after `seconds`, in the app's own loop, and stops the running app with the value NULL: wrappers of
# later::later() and shiny::stopApp(), so a test can stand in for them. Not covered: they need the loop of a running app
# (the page's reload and its close are tried by hand).
# nocov start
studio_after <- function(seconds, fn) {
  rlang::check_installed("later")
  later::later(fn, seconds)
}

studio_stop <- function() {
  shiny::stopApp(NULL)
}
# nocov end

# Whether R runs interactively: a wrapper, so a test can stand in for either answer.
studio_interactive <- function() {
  interactive()
}

# Runs `app` and returns its value: a wrapper of shiny::runApp(), so a test can stand in for it. Not covered: it runs
# an app and waits for it to close, which no test can do in its own session (the browser tests run the app instead).
# nocov start
studio_run <- function(app) {
  checkmate::assert_class(app, "shiny.appobj")
  shiny::runApp(app)
}
# nocov end
