#' Change a stage map in an app, then take it back to R
#'
#' `r lifecycle::badge("experimental")` `stage_map_studio()` opens the stagemap studio, a 'Shiny' app that shows a map
#' on a drawing sheet, with its title above it and the R code that makes it one click away. Click **Done** to close the
#' studio and return the map to R. The studio runs in this R session; what it shows comes from the server, so **Copy**
#' copies the code for the latest change, also when the click comes before the server has answered.
#'
#' @param map A [stage_map()] widget to open the studio on, or `NULL` (the default) for a map of one card.
#' @param ... Must stay empty. It makes every argument after it a named argument, and a typo in an argument's name an
#'   error.
#' @param run `TRUE` (the default) runs the studio and waits for it to close; it needs an interactive R session.
#'   `FALSE` returns the app without running it, for [shiny::runApp()] or a test.
#' @returns With `run = TRUE`, the map from **Done** (a [stage_map()] widget, with the title set in the studio),
#'   invisibly, or `NULL` invisibly when the app was stopped another way. With `run = FALSE`, the app, a
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
  app <- studio_app(map)
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
# server closes over `map`: no option, global or query string carries it.
studio_app <- function(map = NULL, on_done = shiny::stopApp, options = list()) {
  checkmate::assert_class(map, "stagemap_widget", null.ok = TRUE)
  checkmate::assert_function(on_done)
  studio_options(options)
  # From 1.7.5 Shiny leaves an input marked data-shiny-no-bind-input alone, which the studio's fields need.
  rlang::check_installed("shiny", version = "1.7.5")
  shiny::shinyApp(
    ui = function(request) studio_ui("studio", options),
    server = function(input, output, session) studio_server("studio", map, on_done, options)
  )
}

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
