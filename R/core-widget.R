# The widget factory and the check the render function applies. Callers: the stage map's function (sm_widget()) and
# render_stage_map() (sm_checked_widget()). The engine's names (the visual, the global, the prefix) come from
# the contract through sm_spec(); the widget carries them to the page.

# How many problems a data error lists before it counts the rest.
problem_limit <- 10L

# Stops with one classed error, `stagemap_error_data`, that lists up to `problem_limit` of the problems in `data` as
# the spec's `fields` judge it, and holds all of them.
assert_sm_data <- function(data, fields, call) {
  checkmate::assert_list(data, names = "named")
  checkmate::assert_list(fields, names = "named")
  checkmate::assert_environment(call)
  problems <- convert_problems(data, fields)
  if (length(problems) == 0L) {
    return(invisible(NULL))
  }
  shown <- cli_escape(problems[seq_len(min(problem_limit, length(problems)))])
  more <- length(problems) - length(shown)
  sm_abort(
    c(
      "The data cannot be turned into what the stage-map engine reads.",
      bullets(shown, "x"),
      if (more > 0L) c("i" = sprintf("... and %d more.", more))
    ),
    class = "stagemap_error_data",
    problems = problems,
    call = call
  )
}

# Builds the htmlwidget from the R data (a named list shaped as the spec says). `call` is the function the user called.
# `keep` holds the caller's own choices that are not the engine's data (a named list), carried over when a layer
# function builds the widget again.
sm_widget <- function(
  data,
  width = NULL,
  height = NULL,
  element_id = NULL,
  call = rlang::caller_env(),
  keep = list()
) {
  checkmate::assert_list(data, names = "named")
  checkmate::assert_list(keep, names = "unique")
  assert_widget_args(width, height, element_id)
  checkmate::assert_environment(call)
  spec <- sm_spec()
  assert_sm_data(data, spec$fields, call)
  x <- list(
    v = 1L,
    engine = list(global = spec$global, prefix = spec$prefix, visual = spec$name),
    data = convert_json(data, spec$fields, call = call),
    look = NULL
  )
  widget <- htmlwidgets::createWidget(
    "stage_map",
    x,
    width = width,
    height = height,
    sizingPolicy = htmlwidgets::sizingPolicy(
      defaultWidth = "100%",
      defaultHeight = "auto",
      knitr.figure = FALSE,
      viewer.fill = FALSE,
      browser.fill = FALSE,
      fill = FALSE
    ),
    package = "stagemap",
    dependencies = sm_dependencies(),
    elementId = element_id
  )
  class(widget) <- append(class(widget), "stagemap_widget", after = 1L)
  # The R data as given, kept so that a layer function can add to it and build the widget again. htmlwidgets reads
  # only its own fields, so this one never reaches the page.
  widget$stagemap <- list(data = data, keep = keep)
  widget
}

# Passes NULL on (the output then shows nothing, as for any htmlwidget) and refuses anything but this package's
# widget. A promise (a render that runs in the background) is checked when it resolves. In a Shiny session it stamps
# the render with its number, which the page writes as data-stagemap-stamp so that tests can wait for their own render,
# and it asks the engine to follow the colours of the page (look mode "host"), unless the widget has a look of its own.
sm_checked_widget <- function(widget) {
  if (is.null(widget)) {
    return(NULL)
  }
  if (rlang::is_installed("promises") && promises::is.promising(widget)) {
    return(promises::then(promises::as.promise(widget), sm_checked_widget))
  }
  if (!inherits(widget, "stagemap_widget")) {
    sm_abort(
      c(
        "The render function needs a widget made by a stagemap function.",
        "x" = "It was given {.cls {class(widget)}}."
      ),
      class = "stagemap_error_widget",
      call = NULL
    )
  }
  session <- shiny::getDefaultReactiveDomain()
  if (!is.null(session)) {
    store <- session$userData
    store$stagemap_stamp <- (if (is.null(store$stagemap_stamp)) 0L else store$stagemap_stamp) + 1L
    widget$x$stamp <- store$stagemap_stamp
    widget$x$look <- widget$x$look %||% list(mode = "host")
  }
  widget
}
