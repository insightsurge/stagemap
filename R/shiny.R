# The Shiny plumbing between R and a drawn map: a proxy that sends commands to the page, a reader for the state the page
# reports, the readers for what the page says the reader did, and the registration of those readers. Everything here
# is internal; the exported functions that build on it come later.

# The id without the namespace of `session` (a module's prefix, empty outside a module): the id may be plain or already
# namespaced, and the page names its inputs without the prefix.
without_namespace <- function(id, session) {
  checkmate::assert_string(id, min.chars = 1L)
  checkmate::assert_environment(session)
  prefix <- session$ns("")
  if (nzchar(prefix) && startsWith(id, prefix)) substring(id, nchar(prefix) + 1L) else id
}

# A proxy: the output's namespaced id, the session and whether commands wait for the flush. The id may be the plain
# one or already namespaced (as in a module).
sm_proxy <- function(id, session = shiny::getDefaultReactiveDomain(), defer_until_flush = TRUE) {
  checkmate::assert_string(id, min.chars = 1L)
  rlang::check_installed("shiny")
  checkmate::assert_environment(session, .var.name = "session (a Shiny session)")
  checkmate::assert_function(session$sendCustomMessage, .var.name = "session$sendCustomMessage")
  checkmate::assert_flag(defer_until_flush)
  structure(
    list(id = session$ns(without_namespace(id, session)), session = session, defer = defer_until_flush),
    class = "stagemap_proxy"
  )
}

# Sends a command to the map that is already drawn, without drawing it again. R checks the command against the
# commands the engine's contract lists: a command that is not on the list is not sent, and a warning of class
# `stagemap_warning_command` says so. The command's answer does not come back to R. Commands leave R after the outputs
# of the same flush, so a command sent in the same observer as a re-render reaches the page after the new data (unless
# the proxy was made with `defer_until_flush = FALSE`). Returns the proxy, invisibly, so calls can be piped.
sm_send <- function(proxy, command, ..., data = NULL, call = rlang::caller_env()) {
  rlang::check_installed("shiny")
  checkmate::assert_class(proxy, "stagemap_proxy")
  checkmate::assert_string(command, min.chars = 1L)
  checkmate::assert_environment(call)
  check_dots(...)
  takes <- sm_spec()$commands
  if (!command %in% takes) {
    sm_warn(
      c(
        "The command {.val {command}} was not sent: the stage map does not take it.",
        "i" = if (length(takes) > 0L) "Commands it takes: {.val {takes}}." else "It takes no commands."
      ),
      class = "stagemap_warning_command",
      call = call
    )
    return(invisible(proxy))
  }
  json <- tryCatch(convert_json(data), error = function(e) e)
  if (inherits(json, "error")) {
    sm_warn(
      c(
        "The command {.val {command}} was not sent.",
        "x" = "Its data cannot be written as JSON: {conditionMessage(json)}"
      ),
      class = "stagemap_warning_command",
      call = call
    )
    return(invisible(proxy))
  }
  message <- list(id = proxy$id, command = command, data = json, revision = latest_revision(proxy))
  if (proxy$defer) {
    queue_message(proxy$session, message)
  } else {
    proxy$session$sendCustomMessage("stagemap:command", message)
  }
  invisible(proxy)
}

# What the map holds now, as the page last reported it: the whole state, or one field of it (NULL for a field the state
# does not have, and before the page has answered once). Call it inside a reactive context: it reads one input and
# sends nothing.
sm_state <- function(output_id, name = NULL, session = shiny::getDefaultReactiveDomain()) {
  checkmate::assert_string(output_id, min.chars = 1L)
  checkmate::assert_string(name, min.chars = 1L, null.ok = TRUE)
  rlang::check_installed("shiny")
  checkmate::assert_environment(session, .var.name = "session (a Shiny session)")
  state <- session$input[[input_name(output_id, "state", session)]]
  if (is.null(name) || is.null(state)) state else state[[name]]
}

# The name of the input the page writes: `<output id>_<suffix>`. The id may be plain or already namespaced, and the name
# is the one the session sees (without its namespace).
input_name <- function(id, suffix, session) {
  checkmate::assert_string(id, min.chars = 1L)
  checkmate::assert_string(suffix, min.chars = 1L)
  checkmate::assert_environment(session)
  paste(without_namespace(id, session), suffix, sep = "_")
}

# The newest revision of the reader's choice that R has seen in this map (0 if none). The page numbers its choices, and
# drops a `select` older than its own latest one.
latest_revision <- function(proxy) {
  checkmate::assert_class(proxy, "stagemap_proxy")
  seen <- shiny::isolate(proxy$session$input[[input_name(proxy$id, "selected", proxy$session)]])
  if (is.list(seen) && !is.null(seen$revision)) as.integer(seen$revision) else 0L
}

# Keeps the commands of one session in call order and sends them all in one onFlushed callback, which runs after the
# flush's outputs. sendCustomMessage() writes at once and would overtake the outputs of the same flush.
queue_message <- function(session, message) {
  checkmate::assert_environment(session)
  checkmate::assert_list(message, names = "named")
  store <- session$userData
  if (is.null(store$stagemap_queue)) {
    store$stagemap_queue <- new.env(parent = emptyenv())
    store$stagemap_queue$pending <- list()
    store$stagemap_queue$scheduled <- FALSE
  }
  queue <- store$stagemap_queue
  queue$pending[[length(queue$pending) + 1L]] <- message
  if (!queue$scheduled) {
    queue$scheduled <- TRUE
    session$onFlushed(function() send_pending(session, queue), once = TRUE)
    # Outside a reactive event (a later() callback) nothing else would start a flush. A session without the call
    # (the test session) simply waits for the next flush.
    tryCatch(session$requestFlush(), error = function(e) NULL)
  }
  invisible(NULL)
}

send_pending <- function(session, queue) {
  checkmate::assert_environment(session)
  checkmate::assert_environment(queue)
  pending <- queue$pending
  queue$pending <- list()
  queue$scheduled <- FALSE
  for (message in pending) {
    session$sendCustomMessage("stagemap:command", message)
  }
  invisible(NULL)
}

#' @export
#' @noRd
format.stagemap_proxy <- function(x, ...) {
  c("<stagemap_proxy>", paste0("  id: ", x$id))
}

#' @export
#' @noRd
print.stagemap_proxy <- function(x, ...) {
  cli::cat_line(format(x, ...))
  invisible(x)
}

# --- What the page tells R ---------------------------------------------------------------------------------------

# An event of the engine as R sees it: one value per field the contract lists for that event, in the contract's order,
# so a field the engine adds or stamps (`via`, `at`, `seq`, `part`, `name`) reaches R without a change here. `event` is
# the event's short name ("select"), `value` what the page sent. A scalar the page left out is `NA` of its type (never
# NULL); `ids` is a character vector (`character(0)` for none); the other `json` fields (`details`, `about`, `still`)
# are lists or NULL, and `details$kpis` is always a list. A choice by the reader carries the page's own number for it,
# `revision`, as an integer (0 when there is none).
sm_event <- function(event, value) {
  checkmate::assert_string(event, min.chars = 1L)
  spec <- sm_spec()
  fields <- spec$event_data[[paste(spec$prefix, event, sep = ":")]]
  if (is.null(fields)) {
    sm_abort("The stage-map engine has no event {.val {event}}.", class = "stagemap_error_unknown")
  }
  out <- lapply(names(fields), function(name) event_field(name, fields[[name]]$type, value[[name]]))
  names(out) <- names(fields)
  if (identical(event, "select")) {
    out$revision <- as.integer(value$revision %||% 0L)
  }
  out
}

# One field of an event, as R holds it, by the type the contract gives it.
event_field <- function(name, type, x) {
  checkmate::assert_string(name, min.chars = 1L)
  checkmate::assert_string(type, min.chars = 1L)
  if (identical(name, "ids")) {
    return(as.character(unlist(x)))
  }
  switch(
    type,
    integer = if (is.null(x)) NA_integer_ else as.integer(x),
    number = if (is.null(x)) NA_real_ else as.numeric(x),
    json = if (is.list(x) && !is.null(x$kpis)) {
      x$kpis <- as.list(x$kpis)
      x
    } else {
      x
    },
    if (is.null(x)) NA_character_ else as.character(x)
  )
}

# The fields of the state that hold ids. The contract describes them in words ("lists of ids"), so the names are kept
# here, and test-kit.R checks that the contract still says so.
state_id_lists <- c("selected_ids", "hidden", "disabled")

# The state a map reported in answer to the `state` command. Shiny hands over JSON arrays as lists; a list of single
# values becomes a vector (`selected_ids` is a character vector), and an empty list stays `list()` because R cannot
# tell what it would have held, except for the fields that hold ids: those are `character(0)` when empty, as `ids` is
# in an event. The highlight's `ids` is one of them.
sm_state_value <- function(value, shinysession, name) {
  state <- simplify_state(value)
  if (!is.list(state)) {
    return(state)
  }
  for (field in intersect(state_id_lists, names(state))) {
    state[[field]] <- as.character(unlist(state[[field]]))
  }
  if (is.list(state$highlighted) && "ids" %in% names(state$highlighted)) {
    state$highlighted$ids <- as.character(unlist(state$highlighted$ids))
  }
  state
}

# Recursive: it runs once per node of one answer, and its only caller passes what Shiny decoded, so it asserts nothing.
simplify_state <- function(x) {
  if (!is.list(x)) {
    return(x)
  }
  x <- lapply(x, simplify_state)
  single <- function(item) is.atomic(item) && length(item) == 1L
  if (is.null(names(x)) && length(x) > 0L && all(vapply(x, single, logical(1)))) {
    return(unlist(x, use.names = FALSE))
  }
  x
}

# The input handler for the event `event`: what Shiny calls with the value the page sent.
sm_event_reader <- function(event) {
  checkmate::assert_string(event, min.chars = 1L)
  force(event)
  function(value, shinysession, name) sm_event(event, value)
}

# On load, only the input types the widget uses are registered. Shiny is never loaded here.
.onLoad <- function(libname, pkgname) {
  register <- function(...) {
    for (event in c("select", "hover")) {
      shiny::registerInputHandler(paste0("stagemap.", event), sm_event_reader(event), force = TRUE)
    }
    shiny::registerInputHandler("stagemap.state", sm_state_value, force = TRUE)
  }
  if (isNamespaceLoaded("shiny")) {
    register()
  } else {
    setHook(packageEvent("shiny", "onLoad"), register) # nocov
  }
}
