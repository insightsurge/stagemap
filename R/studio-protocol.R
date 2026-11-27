# The studio's protocol between the page and R: the events the page sends (one input, `event`, inside the module) and
# the message R sends back (one custom message type, `stagemap:studio`). Callers: studio_step() checks every event
# here before anything reads it, and the server builds each message with studio_message().

# The events the page sends, each with the fields its `data` must hold. A field may hold `null` (it is still named).
studio_event_types <- list(
  ready = character(),
  open = c("template", "confirm"),
  edit = c("table", "uid", "field", "value"),
  option = c("name", "value"),
  add = "table",
  remove = c("table", "uid"),
  move = c("table", "uid", "by"),
  link_add = c("from", "to", "kind"),
  link_reverse = "uid",
  fix = c("fault", "fix"),
  undo = character(),
  target = c("kind", "uid"),
  ask = "question",
  ask_clear = character(),
  seen = "what",
  done = character()
)

# The event `event` as the page sent it (`{seq, type, data, rev}`), checked: a list with a whole `seq` from 1, a `type`
# from studio_event_types, a `data` list with every name given and none repeated that holds every field the type needs,
# and a whole `rev` from 0. Returns the event with `seq` and `rev` as integers and `data` as a list, or stops with an
# error of class `stagemap_error_studio` that says what is wrong. Shiny reads the page's JSON without simplifying it,
# so `{}` arrives as an empty list and a number may arrive as a double. It takes anything on purpose (the page's value,
# unread): checking it is its whole work, and a bad event must end as this class, not as a checkmate error.
studio_event_check <- function(event) {
  problem <- studio_event_problem(event)
  if (!is.null(problem)) {
    sm_abort(
      c("The studio could not read an event from the page.", "x" = cli_escape(problem)),
      class = "stagemap_error_studio",
      problem = problem
    )
  }
  event$seq <- as.integer(event$seq)
  event$rev <- as.integer(event$rev)
  event$data <- as.list(event$data)
  event
}

# What is wrong with `event`, as a sentence, or NULL when nothing is. Caller: studio_event_check(); like it, it takes
# anything and checks it with checkmate's check_*() functions.
studio_event_problem <- function(event) {
  shape <- checkmate::check_list(event, names = "unique")
  if (!isTRUE(shape)) {
    return(paste0("The event: ", shape))
  }
  missing <- setdiff(c("seq", "type", "data", "rev"), names(event))
  if (length(missing) > 0L) {
    return(paste("The event has no", paste(missing, collapse = ", ")))
  }
  checks <- list(
    seq = checkmate::check_int(event$seq, lower = 1),
    type = if (!checkmate::test_choice(event$type, names(studio_event_types))) "It is not an event the studio knows.",
    data = checkmate::check_list(event$data, names = "unique"),
    rev = checkmate::check_int(event$rev, lower = 0)
  )
  bad <- !vapply(checks, function(check) isTRUE(check) || is.null(check), logical(1))
  if (any(bad)) {
    name <- names(checks)[bad][[1]]
    return(paste0("Its `", name, "`: ", checks[[name]]))
  }
  missing <- setdiff(studio_event_types[[event$type]], names(event$data))
  if (length(missing) > 0L) {
    return(sprintf("A `%s` event needs %s in its data.", event$type, paste0("`", missing, "`", collapse = ", ")))
  }
  NULL
}

# The part of a message that depends on what was sent before: `list(sections = ...)` with the sections of `view` (a
# named list) whose value is not identical to the one in `sent`, the view of the last message. With `sent` NULL (the
# first message, and the answer to `ready`) every section is there. An empty result is still a named list, so it
# reaches the page as an object.
studio_message <- function(view, sent) {
  checkmate::assert_list(view, names = "unique")
  checkmate::assert_list(sent, names = "unique", null.ok = TRUE)
  changed <- if (is.null(sent)) {
    names(view)
  } else {
    names(view)[!vapply(names(view), function(name) identical(view[[name]], sent[[name]]), logical(1))]
  }
  sections <- view[changed]
  if (length(sections) == 0L) {
    sections <- structure(list(), names = character())
  }
  list(sections = sections)
}
