# The studio's state and its pure reducer, studio_step(state, event): one event in, the next state and effects out.
# Plain functions over lists; no Shiny calls.

# Maps a target kind ("card", "stage", "lane", "link") to its document table name.
studio_target_table <- function(kind) {
  checkmate::assert_string(kind, min.chars = 1L)
  switch(kind, card = "cards", stage = "stages", lane = "lanes", link = "links", NULL)
}

# Builds and fault-checks `doc`, updating `good` (using `fallback_map` when the initial/opened doc fails to build)
# and `check`. `good$serial` increments whenever `good$map` is replaced so callers do not rely on `good$rev`.
studio_state_build <- function(doc, rev, good = NULL, fallback_map = NULL) {
  studio_assert_doc(doc)
  checkmate::assert_int(rev, lower = 0L)
  checkmate::assert_list(good, names = "unique", null.ok = TRUE)
  checkmate::assert_class(fallback_map, "stagemap_widget", null.ok = TRUE)

  built <- studio_build(doc)
  faults <- studio_faults(doc)
  serial <- if (is.null(good) || is.null(good$serial)) 0L else good$serial
  if (built$ok) {
    good <- list(rev = rev, map = built$value, serial = serial + 1L)
    check <- list(ok = TRUE, head = NULL, lines = list(), faults = faults, notes = built$warnings)
  } else {
    if (!is.null(fallback_map)) {
      good <- list(rev = rev - 1L, map = fallback_map, serial = serial + 1L)
    }
    check <- list(
      ok = FALSE,
      head = built$error$head,
      lines = built$error$lines,
      faults = faults,
      notes = built$warnings
    )
  }
  list(good = good, check = check)
}

# Initializes a studio state from `map` (a stagemap widget) or from the `"example"` template when `map` is NULL.
studio_state_new <- function(map = NULL) {
  checkmate::assert_class(map, "stagemap_widget", null.ok = TRUE)
  if (is.null(map)) {
    tpl <- studio_template("example")
    base_map <- tpl$map
    doc <- studio_doc(map_parts(base_map))
    if (length(tpl$then) > 0L) {
      doc <- studio_doc_apply(doc, tpl$then)
    }
    template <- "example"
    tour_id <- tpl$tour
    start_open <- TRUE
    given_map <- NULL
  } else {
    base_map <- map
    doc <- studio_doc(map_parts(map))
    template <- "given"
    tour_id <- NULL
    start_open <- FALSE
    given_map <- map
  }

  checked <- studio_state_build(doc, 0L, fallback_map = base_map)
  tour <- if (!is.null(tour_id)) {
    list(id = tour_id, done = rep(FALSE, length(studio_tours[[tour_id]]$steps)))
  } else {
    NULL
  }

  state <- list(
    doc = doc,
    rev = 0L,
    base = doc,
    journal = list(),
    good = checked$good,
    check = checked$check,
    target = list(kind = "none", uid = NULL),
    ask = NULL,
    template = template,
    tour = tour,
    seen = character(),
    notice = NULL,
    ack = 0L,
    closed = FALSE,
    start_open = start_open,
    confirm_open = NULL,
    given_map = given_map
  )
  studio_tour_tick(state)
}

# Produces a refused result: `state` with an incremented notice (tone `"problem"` or `"info"`, optional `room`) and
# no effects.
studio_refuse <- function(state, text, room = NULL, tone = "problem") {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_string(text, min.chars = 1L)
  checkmate::assert_string(room, min.chars = 1L, null.ok = TRUE)
  checkmate::assert_choice(tone, c("info", "problem"))
  n <- if (is.null(state$notice)) 1L else state$notice$n + 1L
  state$notice <- list(n = n, text = text, tone = tone, room = room)
  list(state = state, effects = list())
}

# Handles an `open` event (`template`, `confirm`).
studio_step_open <- function(state, data) {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_list(data, names = "unique")
  if (!checkmate::test_choice(data$template, c("example", "blank", "given"))) {
    return(studio_refuse(state, "Unknown template."))
  }
  if (!is.null(data$confirm) && !checkmate::test_flag(data$confirm)) {
    return(studio_refuse(state, "Invalid confirmation flag."))
  }
  if (studio_journal_can_undo(state$journal) && !isTRUE(data$confirm)) {
    state$confirm_open <- data$template
    return(studio_refuse(state, "Opening another map will lose your changes. Click again to confirm."))
  }

  if (identical(data$template, "given")) {
    if (is.null(state$given_map)) {
      return(studio_refuse(state, "No map was given to R when the studio opened."))
    }
    base_map <- state$given_map
    doc <- studio_doc(map_parts(base_map))
    tour_id <- NULL
  } else {
    tpl <- studio_template(data$template)
    base_map <- tpl$map
    doc <- studio_doc(map_parts(base_map))
    if (length(tpl$then) > 0L) {
      doc <- studio_doc_apply(doc, tpl$then)
    }
    tour_id <- tpl$tour
  }

  new_rev <- state$rev + 1L
  checked <- studio_state_build(doc, new_rev, good = state$good, fallback_map = base_map)
  state$doc <- doc
  state$base <- doc
  state$journal <- list()
  state$rev <- new_rev
  state$good <- checked$good
  state$check <- checked$check
  state$target <- list(kind = "none", uid = NULL)
  state$ask <- NULL
  state$template <- data$template
  state$seen <- character()
  state$tour <- if (!is.null(tour_id)) {
    list(id = tour_id, done = rep(FALSE, length(studio_tours[[tour_id]]$steps)))
  } else {
    NULL
  }
  state$start_open <- FALSE
  state$confirm_open <- NULL
  state$notice <- NULL
  state
}

# Handles `target` (`{kind, uid}`) and server-made `picked` (`{kind, id}`).
studio_step_target <- function(state, data) {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_list(data, names = "unique")
  if (!checkmate::test_choice(data$kind, c("none", "card", "stage", "lane", "link"))) {
    return(studio_refuse(state, "Unknown target kind."))
  }
  if (identical(data$kind, "none")) {
    state$target <- list(kind = "none", uid = NULL)
    return(list(state = state, effects = list(), refused = FALSE))
  }
  if (
    !checkmate::test_string(data$uid, min.chars = 1L) ||
      is.null(studio_row(state$doc, studio_target_table(data$kind), data$uid))
  ) {
    res <- studio_refuse(state, "That item is no longer in the map.")
    res$refused <- TRUE
    return(res)
  }
  state$target <- list(kind = data$kind, uid = data$uid)
  list(state = state, effects = list(), refused = FALSE)
}

studio_step_picked <- function(state, data) {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_list(data, names = "unique")
  kind <- data$kind
  id <- data$id
  if (is.null(kind) || kind %in% c("all", "none") || is.null(id) || !nzchar(as_text(id))) {
    state$target <- list(kind = "none", uid = NULL)
    return(state)
  }
  if (kind %in% c("card", "stage")) {
    tbl_name <- studio_target_table(kind)
    good_tbl <- stage_map_tables(state$good$map)[[tbl_name]]
    id_text <- as_text(id)[[1L]]
    if (is.data.frame(good_tbl) && (id_text %in% as_text(good_tbl$id))) {
      uid <- studio_uid_of(state$doc, tbl_name, id_text)
      if (!is.null(uid)) {
        state$target <- list(kind = kind, uid = uid)
      }
    }
  }
  state
}

# Builds the `select` effect when target changed (except from `picked`) or when the targeted card's id changed.
studio_select_effect <- function(state, old_target, old_doc, event_type) {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_list(old_target, names = "unique")
  studio_assert_doc(old_doc)
  checkmate::assert_string(event_type, min.chars = 1L)

  if (identical(event_type, "picked")) {
    return(list())
  }
  target <- state$target
  if (!identical(target, old_target)) {
    if (target$kind %in% c("card", "stage")) {
      row <- studio_row(state$doc, studio_target_table(target$kind), target$uid)
      if (!is.null(row) && !is.na(row$id) && nzchar(trimws(as_text(row$id)))) {
        return(list(list(type = "select", kind = target$kind, id = as_text(row$id))))
      }
      return(list())
    }
    if (old_target$kind %in% c("card", "stage")) {
      return(list(list(type = "select", kind = "none", id = NULL)))
    }
    return(list())
  }

  if (identical(target$kind, "card") && !identical(state$doc, old_doc)) {
    old_row <- studio_row(old_doc, "cards", target$uid)
    new_row <- studio_row(state$doc, "cards", target$uid)
    if (
      !is.null(old_row) &&
        !is.null(new_row) &&
        !identical(as_text(old_row$id), as_text(new_row$id)) &&
        !is.na(new_row$id) &&
        nzchar(trimws(as_text(new_row$id)))
    ) {
      return(list(list(type = "select", kind = "card", id = as_text(new_row$id))))
    }
  }
  list()
}

# Handles a server-made map pick (`kind`, `id`) without emitting a `select` effect.
studio_pick <- function(state, kind, id = NULL) {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_string(kind, min.chars = 1L, null.ok = TRUE)
  checkmate::assert_string(id, null.ok = TRUE)
  if (isTRUE(state$closed)) {
    return(studio_refuse(state, "The map has gone back to R: nothing more changes here."))
  }
  state <- studio_step_picked(state, list(kind = kind, id = id))
  state <- studio_tour_tick(state)
  list(state = state, effects = list())
}

# Applies one page event to `state`, returning `list(state, effects)`.
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
  if (!identical(checked$type, "open")) {
    state$confirm_open <- NULL
  }

  old_rev <- state$rev
  old_target <- state$target
  old_doc <- state$doc
  effects <- list()

  if (identical(checked$type, "ready")) {
    return(list(state = studio_tour_tick(state), effects = list()))
  } else if (identical(checked$type, "open")) {
    opened <- studio_step_open(state, checked$data)
    if (!is.null(opened$effects)) {
      return(opened)
    }
    state <- opened
  } else if (checked$type %in% names(studio_events())) {
    change <- tryCatch(
      studio_resolve(state$doc, checked),
      error = function(e) list(refused = cli::ansi_strip(conditionMessage(e)))
    )
    if (!is.null(change$refused)) {
      return(studio_refuse(state, change$refused))
    }
    if (length(change$ops) > 0L) {
      state$doc <- studio_doc_apply(state$doc, change$ops)
      state$journal <- studio_journal_add(state$journal, change)
      state$rev <- state$rev + 1L
      state$notice <- NULL
      if (!is.null(change$target)) {
        state$target <- change$target
      }
      if (
        !identical(state$target$kind, "none") &&
          is.null(studio_row(state$doc, studio_target_table(state$target$kind), state$target$uid))
      ) {
        state$target <- list(kind = "none", uid = NULL)
      }
    }
  } else if (identical(checked$type, "undo")) {
    if (!studio_journal_can_undo(state$journal)) {
      return(studio_refuse(state, "Nothing to undo."))
    }
    done_idx <- which(vapply(state$journal, function(e) identical(e$state, "done"), logical(1)))
    undone_entry <- state$journal[[done_idx[[length(done_idx)]]]]
    state$journal <- studio_journal_undo(state$journal)
    state$doc <- studio_journal_replay(state$base, state$journal)
    state$rev <- state$rev + 1L
    n <- if (is.null(state$notice)) 1L else state$notice$n + 1L
    state$notice <- list(n = n, text = paste0("Undone: ", undone_entry$text), tone = "info", room = NULL)
    if (
      !identical(state$target$kind, "none") &&
        is.null(studio_row(state$doc, studio_target_table(state$target$kind), state$target$uid))
    ) {
      state$target <- list(kind = "none", uid = NULL)
    }
  } else if (identical(checked$type, "target")) {
    res <- studio_step_target(state, checked$data)
    if (isTRUE(res$refused)) {
      return(list(state = res$state, effects = res$effects))
    }
    state <- res$state
  } else if (checked$type %in% c("ask", "ask_clear")) {
    return(studio_refuse(state, "Not available yet.", tone = "info"))
  } else if (identical(checked$type, "seen")) {
    if (!checkmate::test_string(checked$data$what, min.chars = 1L)) {
      return(studio_refuse(state, "Unknown view name."))
    }
    state$seen <- union(state$seen, checked$data$what)
  } else if (identical(checked$type, "done")) {
    if (!identical(state$good$rev, state$rev)) {
      return(studio_refuse(state, "Fix the problems in Check before returning the map.", room = "check"))
    }
    state$closed <- TRUE
    effects[[length(effects) + 1L]] <- list(type = "done", map = state$good$map)
  }

  if (!identical(state$rev, old_rev) && !identical(checked$type, "open")) {
    built <- studio_state_build(state$doc, state$rev, good = state$good)
    state$good <- built$good
    state$check <- built$check
    if (!is.null(state$ask)) {
      was_lit <- isTRUE(state$ask$lit)
      state$ask$stale <- TRUE
      if (was_lit) {
        state$ask$lit <- FALSE
        effects[[length(effects) + 1L]] <- list(type = "highlight", ids = character(), links = NULL)
      }
    }
  }

  state <- studio_tour_tick(state)
  effects <- c(effects, studio_select_effect(state, old_target, old_doc, checked$type))
  list(state = state, effects = effects)
}
