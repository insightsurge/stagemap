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
    notice_n = 0L,
    next_uid = doc$next_uid,
    ack = 0L,
    closed = FALSE,
    start_open = start_open,
    confirm_open = NULL,
    given_map = given_map
  )
  studio_tour_tick(state)
}

# Sets `state$notice` with a monotonically rising notice number across the session.
studio_next_notice <- function(state, text, tone = "info", room = NULL) {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_string(text, min.chars = 1L)
  checkmate::assert_choice(tone, c("info", "problem"))
  checkmate::assert_string(room, min.chars = 1L, null.ok = TRUE)
  n <- (state$notice_n %||% 0L) + 1L
  state$notice_n <- n
  state$notice <- list(n = n, text = text, tone = tone, room = room)
  state
}

# Produces a refused result: `state` with an incremented notice (tone `"problem"` or `"info"`, optional `room`) and
# no effects.
studio_refuse <- function(state, text, room = NULL, tone = "problem") {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_string(text, min.chars = 1L)
  checkmate::assert_string(room, min.chars = 1L, null.ok = TRUE)
  checkmate::assert_choice(tone, c("info", "problem"))
  state <- studio_next_notice(state, text, tone = tone, room = room)
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
    doc <- studio_doc(map_parts(base_map), next_uid = max(state$doc$next_uid, state$next_uid %||% 1L))
    tour_id <- NULL
  } else {
    tpl <- studio_template(data$template)
    base_map <- tpl$map
    doc <- studio_doc(map_parts(base_map), next_uid = max(state$doc$next_uid, state$next_uid %||% 1L))
    if (length(tpl$then) > 0L) {
      doc <- studio_doc_apply(doc, tpl$then)
    }
    tour_id <- tpl$tour
  }

  new_rev <- state$rev + 1L
  checked <- studio_state_build(doc, new_rev, good = state$good, fallback_map = base_map)
  state$doc <- doc
  state$base <- doc
  state$next_uid <- doc$next_uid
  state$journal <- list()
  state$rev <- new_rev
  state$good <- checked$good
  state$check <- checked$check
  state$target <- list(kind = "none", uid = NULL)
  state["ask"] <- list(NULL)
  state$template <- data$template
  state$seen <- character()
  state["tour"] <- list(
    if (!is.null(tour_id)) {
      list(id = tour_id, done = rep(FALSE, length(studio_tours[[tour_id]]$steps)))
    } else {
      NULL
    }
  )
  state$start_open <- FALSE
  state["confirm_open"] <- list(NULL)
  state["notice"] <- list(NULL)
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

# Resolves a drawn `kind` ("card" or "stage") and `id_text` to its `.studio_uid` in `state$doc` when that id sits at
# the same position in the drawn map and `state$doc` and occurs once in `state$doc`; otherwise NULL.
studio_drawn_uid <- function(state, kind, id_text) {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_string(kind, min.chars = 1L)
  checkmate::assert_string(id_text, na.ok = TRUE)
  if (!(kind %in% c("card", "stage")) || is.na(id_text) || !nzchar(trimws(id_text))) {
    return(NULL)
  }
  tbl_name <- studio_target_table(kind)
  good_tbl <- stage_map_tables(state$good$map)[[tbl_name]]
  good_ids <- if (is.data.frame(good_tbl)) as_text(good_tbl$id) else character()
  pos <- match(id_text, good_ids)
  if (is.na(pos)) {
    return(NULL)
  }
  doc_tbl <- state$doc$tables[[tbl_name]]
  doc_ids <- if (is.data.frame(doc_tbl) && "id" %in% names(doc_tbl)) as_text(doc_tbl$id) else character()
  if (pos > length(doc_ids) || !identical(doc_ids[[pos]], id_text) || sum(doc_ids == id_text, na.rm = TRUE) != 1L) {
    return(NULL)
  }
  doc_tbl$.studio_uid[[pos]]
}

# Builds a `select` effect for `state$target` when that target is unambiguously present in `state$good$map`.
studio_target_select_effect <- function(state) {
  checkmate::assert_list(state, names = "unique")
  target <- state$target
  if (!(target$kind %in% c("card", "stage")) || is.null(target$uid)) {
    return(list())
  }
  row <- studio_row(state$doc, studio_target_table(target$kind), target$uid)
  if (is.null(row) || is.na(row$id) || !nzchar(trimws(as_text(row$id)))) {
    return(list())
  }
  id_text <- as_text(row$id)
  if (identical(studio_drawn_uid(state, target$kind, id_text), target$uid)) {
    return(list(list(type = "select", kind = target$kind, id = id_text)))
  }
  list()
}

studio_step_picked <- function(state, data) {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_list(data, names = "unique")
  kind <- data$kind
  id <- data$id
  if (
    is.null(kind) ||
      kind %in% c("all", "none") ||
      is.null(id) ||
      length(id) == 0L ||
      is.na(id[[1L]]) ||
      !nzchar(as_text(id)[[1L]])
  ) {
    state$target <- list(kind = "none", uid = NULL)
    return(state)
  }
  if (kind %in% c("card", "stage")) {
    tbl_name <- studio_target_table(kind)
    good_tbl <- stage_map_tables(state$good$map)[[tbl_name]]
    id_text <- as_text(id)[[1L]]
    uid <- studio_drawn_uid(state, kind, id_text)
    if (!is.null(uid)) {
      state$target <- list(kind = kind, uid = uid)
      state["notice"] <- list(NULL)
    } else if (is.data.frame(good_tbl) && (id_text %in% as_text(good_tbl$id))) {
      return(studio_next_notice(
        state,
        "The drawn map is out of date while the map has problems. Fix them in Check first.",
        tone = "problem",
        room = "check"
      ))
    }
  }
  state
}

# Fills missing `stage` and `lane` uids on an `add` event for `cards` from the server's current `target`.
studio_add_defaults <- function(doc, target, data) {
  studio_assert_doc(doc)
  checkmate::assert_list(target, names = "unique")
  checkmate::assert_list(data, names = "unique")
  if (!identical(data$table, "cards")) {
    return(data)
  }
  if (identical(target$kind, "card") && !is.null(target$uid)) {
    card_row <- studio_row(doc, "cards", target$uid)
    if (!is.null(card_row)) {
      if (is.null(data$stage) && !is.na(card_row$stage) && nzchar(as_text(card_row$stage))) {
        data$stage <- studio_uid_of(doc, "stages", as_text(card_row$stage))
      }
      if (is.null(data$lane) && !is.na(card_row$lane) && nzchar(as_text(card_row$lane))) {
        data$lane <- studio_uid_of(doc, "lanes", as_text(card_row$lane))
      }
    }
  } else if (identical(target$kind, "stage") && !is.null(target$uid)) {
    if (is.null(data$stage) && !is.null(studio_row(doc, "stages", target$uid))) {
      data$stage <- target$uid
    }
  } else if (identical(target$kind, "lane") && !is.null(target$uid)) {
    if (is.null(data$lane) && !is.null(studio_row(doc, "lanes", target$uid))) {
      data$lane <- target$uid
    }
  }
  data
}

# Builds the `select` effect against `state$good$map`: on target change (except `picked`), when `good$serial` rises,
# or when the targeted card or stage changes id.
studio_select_effect <- function(state, old_target, old_doc, event_type, old_serial = state$good$serial) {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_list(old_target, names = "unique")
  studio_assert_doc(old_doc)
  checkmate::assert_string(event_type, min.chars = 1L)
  checkmate::assert_int(old_serial, lower = 0L)

  if (identical(event_type, "picked")) {
    return(list())
  }

  target <- state$target

  if (!identical(target, old_target)) {
    eff <- studio_target_select_effect(state)
    if (length(eff) > 0L) {
      return(eff)
    }
    if (old_target$kind %in% c("card", "stage")) {
      return(list(list(type = "select", kind = "none", id = NULL)))
    }
    return(list())
  }

  if (!identical(state$good$serial, old_serial) && target$kind %in% c("card", "stage")) {
    return(studio_target_select_effect(state))
  }

  if (target$kind %in% c("card", "stage") && !identical(state$doc, old_doc)) {
    tbl_name <- studio_target_table(target$kind)
    old_row <- studio_row(old_doc, tbl_name, target$uid)
    new_row <- studio_row(state$doc, tbl_name, target$uid)
    if (
      !is.null(old_row) &&
        !is.null(new_row) &&
        !identical(as_text(old_row$id), as_text(new_row$id))
    ) {
      return(studio_target_select_effect(state))
    }
  }
  list()
}

# Handles a server-made map pick (`kind`, `id`). Emits a `select` effect to restore the map selection whenever a card
# or stage click is refused or names an id not in the drawn map.
studio_pick <- function(state, kind, id = NULL) {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_string(kind, min.chars = 1L, null.ok = TRUE)
  checkmate::assert_string(id, null.ok = TRUE)
  if (isTRUE(state$closed)) {
    return(studio_refuse(state, "The map has gone back to R: nothing more changes here."))
  }
  has_id <- !is.null(id) && length(id) > 0L && !is.na(id[[1L]]) && nzchar(as_text(id)[[1L]])
  refused <- !is.null(kind) &&
    (kind %in% c("card", "stage")) &&
    has_id &&
    is.null(studio_drawn_uid(state, kind, as_text(id)[[1L]]))
  state <- studio_step_picked(state, list(kind = kind, id = id))
  state <- studio_tour_tick(state)
  effects <- if (refused) {
    eff <- studio_target_select_effect(state)
    if (length(eff) > 0L) eff else list(list(type = "select", kind = "none", id = NULL))
  } else {
    list()
  }
  list(state = state, effects = effects)
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
    state["confirm_open"] <- list(NULL)
  }

  old_rev <- state$rev
  old_target <- state$target
  old_doc <- state$doc
  old_serial <- state$good$serial
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
    if (identical(checked$type, "add")) {
      checked$data <- studio_add_defaults(state$doc, state$target, checked$data)
    }
    from_doc <- NULL
    if (
      identical(checked$type, "edit") &&
        identical(checked$data$field, "id") &&
        checkmate::test_string(checked$data$table, min.chars = 1L) &&
        checkmate::test_string(checked$data$uid, min.chars = 1L)
    ) {
      key <- paste("edit", checked$data$table, checked$data$uid, "id", sep = ":")
      open_idx <- studio_journal_match(state$journal, key)
      if (!is.null(open_idx)) {
        from_doc <- studio_journal_replay(state$base, state$journal[-open_idx])
      }
    }
    change <- tryCatch(
      studio_resolve(state$doc, checked, from_doc = from_doc),
      stagemap_error_payload = function(e) list(refused = "The studio could not read that change from the page.")
    )
    if (!is.null(change$refused)) {
      return(studio_refuse(state, change$refused))
    }
    if (length(change$ops) > 0L) {
      uid_cursor <- max(state$doc$next_uid, state$next_uid %||% 1L)
      first_insert <- NULL
      for (k in seq_along(change$ops)) {
        if (identical(change$ops[[k]]$op, "insert") && is.null(change$ops[[k]]$uid)) {
          uid_val <- paste0("u", uid_cursor)
          change$ops[[k]]$uid <- uid_val
          if (is.null(first_insert)) {
            first_insert <- uid_val
          }
          uid_cursor <- uid_cursor + 1L
        }
      }
      if (!is.null(first_insert) && !is.null(change$target)) {
        change$target$uid <- first_insert
      }
      state$next_uid <- uid_cursor
      old_len <- length(state$journal)
      state$journal <- studio_journal_add(state$journal, change)
      state$doc <- if (length(state$journal) > old_len) {
        studio_doc_apply(state$doc, change$ops)
      } else {
        studio_journal_replay(state$base, state$journal)
      }
      state$rev <- state$rev + 1L
      state["notice"] <- list(NULL)
      if (!is.null(change$target) && !identical(checked$type, "edit")) {
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
    state <- studio_next_notice(state, paste0("Undone: ", undone_entry$text), tone = "info", room = NULL)
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
  effects <- c(effects, studio_select_effect(state, old_target, old_doc, checked$type, old_serial = old_serial))
  list(state = state, effects = effects)
}
