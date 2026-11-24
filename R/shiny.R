# The Shiny plumbing between R and a drawn map: a proxy that sends commands to the page, a reader for the state the page
# reports, the readers for what the page says the reader did, and the registration of those readers. Everything here
# is internal; the exported functions that build on it are in stage_map-shiny.R.

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

# The newest revision of the reader's choice that R has seen in this map (0 if none). The page numbers the reader's
# choices, sends the number to a private input and drops a `select` older than its own latest one.
latest_revision <- function(proxy) {
  checkmate::assert_class(proxy, "stagemap_proxy")
  seen <- shiny::isolate(proxy$session$input[[input_name(proxy$id, revision_suffix, proxy$session)]])
  if (is.numeric(seen) && length(seen) == 1L && !is.na(seen)) as.integer(seen) else 0L
}

# The private input of the reader's choice count: `<output id>_stagemap_revision`. The page writes it under this name.
revision_suffix <- "stagemap_revision"

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

# The fields of a pick (`input$<id>_pick`), in order. The engine's `select` event holds more (`details`, `about`, `via`,
# `at`, `seq`, `part` and `name`); they are not passed, and fields may be added here later but none removed. test-kit.R
# checks that the contract still lists each.
pick_fields <- c("kind", "id", "ids", "from", "label", "still", "by")

# The fields of the state that hold ids. The contract describes them in words ("lists of ids"), so the names are kept
# here, and test-kit.R checks that the contract still says so.
state_id_lists <- c("selected_ids", "hidden", "disabled")

# Ids as the page sent them (a vector, or a list from an empty or one-item array) as a character vector: `character(0)`
# for none.
as_id_vector <- function(x) as.character(unlist(x))

# One field of a pick that is text: NULL when the page sent nothing, never NA.
pick_text <- function(x) if (is.null(x)) NULL else as.character(x)

# The input handler for `input$<id>_selected` and `input$<id>_hovered`: a character vector, and `character(0)` for the
# empty list Shiny makes of an empty array (without this, `req()` would let an empty selection through).
sm_ids_value <- function(value, shinysession, name) as_id_vector(value)

# The input handler for `input$<id>_pick`: the seven fields of `pick_fields`, whatever else the page sent. A field with
# nothing to say is NULL (not NA), `ids` is `character(0)`, and `still` is NULL or a list of `kind`, `id` and `ids`.
sm_pick_value <- function(value, shinysession, name) {
  still <- value$still
  list(
    kind = pick_text(value$kind),
    id = pick_text(value$id),
    ids = as_id_vector(value$ids),
    from = pick_text(value$from),
    label = pick_text(value$label),
    still = if (!is.null(still)) {
      list(kind = pick_text(still$kind), id = pick_text(still$id), ids = as_id_vector(still$ids))
    },
    by = pick_text(value$by)
  )
}

# The highlighted links of the state as a data frame with the columns `from`, `to` and `kind` (NA for a link with no
# kind), and no rows when there are none, so it can be given back to stage_map_highlight() as it is.
state_links <- function(links) {
  column <- function(name) {
    vapply(links, function(link) as.character(link[[name]] %||% NA_character_), character(1))
  }
  data.frame(from = column("from"), to = column("to"), kind = column("kind"))
}

# The input handler for `input$<id>_state`: the six fields of the state R sees, from what the engine answered to the
# `state` command. Ids are character vectors (`character(0)` when none); `stage` has length 0 or 1; `step` counts from
# 1, with 0 at the start or without a player (the engine counts from 0 and says -1 for that); `highlighted$links` is a
# data frame. The engine's `selected_ids` is `selected` here, and its `selected` (the lead) and `host_changes` are not
# passed. Anything that is not a list passes as it is.
sm_state_value <- function(value, shinysession, name) {
  if (!is.list(value)) {
    return(value)
  }
  list(
    selected = as_id_vector(value$selected_ids),
    stage = as_id_vector(value$stage),
    step = as.integer(value$step %||% -1L) + 1L,
    highlighted = list(
      ids = as_id_vector(value$highlighted$ids),
      links = state_links(value$highlighted$links)
    ),
    hidden = as_id_vector(value$hidden),
    disabled = as_id_vector(value$disabled)
  )
}

# On load, only the input types the widget uses are registered. Shiny is never loaded here.
.onLoad <- function(libname, pkgname) {
  register <- function(...) {
    shiny::registerInputHandler("stagemap.ids", sm_ids_value, force = TRUE)
    shiny::registerInputHandler("stagemap.pick", sm_pick_value, force = TRUE)
    shiny::registerInputHandler("stagemap.state", sm_state_value, force = TRUE)
  }
  if (isNamespaceLoaded("shiny")) {
    register()
  } else {
    setHook(packageEvent("shiny", "onLoad"), register) # nocov
  }
}
