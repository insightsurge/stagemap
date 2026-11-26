# The studio's state and the reducer that applies one event to it. The state is a plain list, never reactive: the server
# keeps it in one reactiveVal and calls studio_step() for each event. This is the smallest state the shell needs (the
# map, its title, the revision, the last acknowledged event, a notice and whether Done has closed the studio); the
# document of tables and the journal replace it, with the same studio_step() contract: list(state, effects).

# The state for a studio opened on `map` (a stage map widget), or on a map of one card when `map` is NULL.
studio_state_new <- function(map = NULL) {
  checkmate::assert_class(map, "stagemap_widget", null.ok = TRUE)
  map <- map %||% studio_first_map()
  list(map = map, title = studio_map_title(map), rev = 0L, ack = 0L, notice = NULL, closed = FALSE)
}

# The map the studio shows when it is given none: one card in one stage and one lane, the least a map needs to draw.
studio_first_map <- function() {
  stage_map(
    data.frame(id = "first", label = "First card", stage = "start", lane = "main"),
    data.frame(id = "start", label = "Start"),
    data.frame(id = "main", label = "Main")
  )
}

# The title of `map` as the studio edits it: its `title` option, or "" when it has none.
studio_map_title <- function(map) {
  checkmate::assert_class(map, "stagemap_widget")
  title <- sm_widget_data(map)$options[["title"]]
  if (is.null(title)) "" else title
}

# Applies the event `event` (as the page sent it, unchecked) to `state`. Returns `list(state, effects)`: the new state,
# whose `ack` is the event's `seq`, and a list of effects for the server to carry out. An event that cannot be read, or
# that the studio refuses, changes nothing but `ack` and the notice that says why.
studio_step <- function(state, event) {
  checkmate::assert_list(state, names = "unique")
  checked <- tryCatch(studio_event_check(event), stagemap_error_studio = function(e) e)
  if (inherits(checked, "error")) {
    seq <- if (is.list(event) && checkmate::test_int(event$seq, lower = 1)) as.integer(event$seq) else 0L
    state$ack <- max(state$ack, seq)
    return(studio_refuse(state, checked$problem))
  }
  state$ack <- max(state$ack, checked$seq)
  if (state$closed && !identical(checked$type, "ready")) {
    return(studio_refuse(state, "The map has gone back to R: nothing more changes here."))
  }
  switch(
    checked$type,
    ready = list(state = state, effects = list()),
    option = studio_step_option(state, checked$data),
    done = studio_step_done(state),
    studio_refuse(state, sprintf("The studio does not take a `%s` event here.", checked$type))
  )
}

# The result of a refused event: `state` with a notice that says why, and no effects. Callers: studio_step() and the
# step functions below, which have checked `state`.
studio_refuse <- function(state, text) {
  checkmate::assert_string(text, min.chars = 1L)
  n <- if (is.null(state$notice)) 1L else state$notice$n + 1L
  state$notice <- list(n = n, text = text, tone = "problem", room = NULL)
  list(state = state, effects = list())
}

# An `option` event: only `title` is taken. A blank title is refused; a title that changes raises the revision.
# Caller: studio_step(), with `data` checked.
studio_step_option <- function(state, data) {
  checkmate::assert_list(data, names = "unique")
  if (!identical(data$name, "title")) {
    return(studio_refuse(state, "The studio does not change that option here."))
  }
  value <- data$value
  if (!checkmate::test_string(value) || !nzchar(trimws(value))) {
    return(studio_refuse(state, "The title was not changed: a map's title cannot be blank."))
  }
  if (!identical(value, state$title)) {
    state$title <- value
    state$rev <- state$rev + 1L
  }
  list(state = state, effects = list())
}

# Done: the studio closes and hands its map to the server, which passes it to `on_done` once the page has been told.
studio_step_done <- function(state) {
  checkmate::assert_list(state, names = "unique")
  state$closed <- TRUE
  list(state = state, effects = list(list(type = "done", map = studio_done_map(state))))
}

# The map Done returns: the map the studio was opened on, with the title from the state once it has been changed.
studio_done_map <- function(state) {
  checkmate::assert_list(state, names = "unique")
  map <- state$map
  if (identical(state$title, studio_map_title(map))) {
    return(map)
  }
  data <- sm_widget_data(map)
  data$options <- as.list(data$options)
  data$options$title <- state$title
  sm_rebuild(map, data)
}
