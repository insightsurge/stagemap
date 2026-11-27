# Ask room: runs sm_trace(), sm_orphans() and sm_missing() on the current valid map, records the answer and
# highlight effects in state, and builds the `ask` section view (question forms and answer table).

# Unwraps a string or list of strings sent from the page (`data$ids`, `data$kinds`) into a character vector, or
# NULL when absent/empty. Aborts with `stagemap_error_arg` on invalid types or NAs.
studio_ask_unwrap <- function(raw, arg_name, allow_empty = TRUE) {
  checkmate::assert_string(arg_name, min.chars = 1L)
  checkmate::assert_flag(allow_empty)
  if (is.null(raw)) {
    if (allow_empty) {
      return(NULL)
    }
    sm_abort("{.arg {arg_name}} is missing.", class = "stagemap_error_arg")
  }
  if (is.list(raw)) {
    if (length(raw) == 0L) {
      if (allow_empty) {
        return(NULL)
      }
      sm_abort("{.arg {arg_name}} is empty.", class = "stagemap_error_arg")
    }
    ok <- all(vapply(raw, function(x) is.character(x) && length(x) == 1L && !is.na(x), logical(1)))
    if (!ok) {
      sm_abort("{.arg {arg_name}} must contain text values.", class = "stagemap_error_arg")
    }
    vals <- unlist(raw, use.names = FALSE)
  } else if (is.character(raw)) {
    if (anyNA(raw)) {
      sm_abort("{.arg {arg_name}} must not contain NA.", class = "stagemap_error_arg")
    }
    vals <- raw
  } else {
    sm_abort("{.arg {arg_name}} must be text.", class = "stagemap_error_arg")
  }
  if (length(vals) == 1L && !nzchar(vals[[1L]])) {
    vals <- character()
  }
  if (length(vals) == 0L) {
    if (allow_empty) {
      return(NULL)
    }
    sm_abort("Choose a value for {.arg {arg_name}}.", class = "stagemap_error_arg")
  }
  if (any(!nzchar(trimws(vals)))) {
    sm_abort("{.arg {arg_name}} must not contain blank values.", class = "stagemap_error_arg")
  }
  vals
}

# Resolves row keys (`.studio_uid`) in `table` to their current `id` values.
studio_ask_resolve_uids <- function(doc, table, raw, arg_name, what, allow_empty = TRUE, single = FALSE) {
  studio_assert_doc(doc)
  checkmate::assert_string(table, min.chars = 1L)
  checkmate::assert_string(arg_name, min.chars = 1L)
  checkmate::assert_string(what, min.chars = 1L)
  checkmate::assert_flag(allow_empty)
  checkmate::assert_flag(single)

  uids <- studio_ask_unwrap(raw, arg_name, allow_empty = allow_empty)
  if (is.null(uids)) {
    return(NULL)
  }
  if (single && length(uids) != 1L) {
    sm_abort("{.arg {arg_name}} must name one {what}.", class = "stagemap_error_arg")
  }
  tbl <- doc$tables[[table]]
  known <- if (is.data.frame(tbl)) tbl$.studio_uid else character()
  idx <- match(uids, known)
  if (anyNA(idx)) {
    sm_abort("Unknown {what} key in {.arg {arg_name}}: {.val {uids[is.na(idx)]}}.", class = "stagemap_error_id")
  }
  ids <- as_text(tbl$id[idx])
  if (anyNA(ids) || any(!nzchar(trimws(ids)))) {
    sm_abort("That {what} has no id yet.", class = "stagemap_error_id")
  }
  ids
}

# Resolves `max_distance` from JS (NULL, "", numeric, or string) into `Inf` or a numeric value for `sm_trace()`.
studio_ask_resolve_distance <- function(raw) {
  if (is.null(raw) || (is.character(raw) && length(raw) == 1L && !nzchar(trimws(raw)))) {
    return(Inf)
  }
  if (is.numeric(raw) && length(raw) == 1L && !is.na(raw)) {
    return(if (is.infinite(raw)) Inf else as.numeric(raw))
  }
  if (is.character(raw) && length(raw) == 1L) {
    num <- suppressWarnings(as.numeric(raw))
    if (!is.na(num)) {
      return(num)
    }
  }
  sm_abort(
    "{.arg max_distance} must be a whole number from 0, or empty for no limit.",
    class = "stagemap_error_arg"
  )
}

# Formats a question call node into R code text.
studio_ask_call_text <- function(fn, args) {
  checkmate::assert_string(fn, min.chars = 1L)
  checkmate::assert_list(args)
  paste(code_lines(code_call(fn, args)), collapse = "\n")
}

# Resolves the link rows for `sm_trace()` highlight effects. Each non-start row with `through` gives one link row
# (`from`, `to`, `kind`) oriented in the link's own direction in `map`: downstream (`through -> id`), upstream
# (`id -> through`), and for `"both"` looked up in the map's links table (downstream wins ties, matching sm_trace()).
studio_ask_trace_links <- function(rows, map) {
  checkmate::assert_data_frame(rows)
  checkmate::assert_class(map, "stagemap_widget")
  if (nrow(rows) == 0L || !("through" %in% names(rows))) {
    return(NULL)
  }
  keep <- which(!is.na(rows$through) & nzchar(rows$through))
  if (length(keep) == 0L) {
    return(NULL)
  }
  links_tbl <- sm_widget_data(map)$links
  has_links <- is.data.frame(links_tbl) && nrow(links_tbl) > 0L
  l_from <- if (has_links) as_text(links_tbl$from) else character()
  l_to <- if (has_links) as_text(links_tbl$to) else character()
  l_kind <- if (has_links && "kind" %in% names(links_tbl)) {
    as_text(links_tbl$kind)
  } else {
    rep(NA_character_, length(l_from))
  }

  has_link <- function(from_id, to_id, kind_val) {
    same_k <- if (is.na(kind_val)) is.na(l_kind) else !is.na(l_kind) & l_kind == kind_val
    any(l_from == from_id & l_to == to_id & same_k)
  }

  n <- length(keep)
  out_from <- character(n)
  out_to <- character(n)
  out_kind <- character(n)
  for (j in seq_len(n)) {
    r <- rows[keep[[j]], , drop = FALSE]
    id_val <- as_text(r$id)
    through_val <- as_text(r$through)
    dir_val <- as_text(r$direction)
    kind_val <- as_text(r$kind)
    if (identical(dir_val, "downstream")) {
      out_from[[j]] <- through_val
      out_to[[j]] <- id_val
    } else if (identical(dir_val, "upstream")) {
      out_from[[j]] <- id_val
      out_to[[j]] <- through_val
    } else if (has_link(through_val, id_val, kind_val)) {
      out_from[[j]] <- through_val
      out_to[[j]] <- id_val
    } else {
      out_from[[j]] <- id_val
      out_to[[j]] <- through_val
    }
    out_kind[[j]] <- kind_val
  }
  data.frame(from = out_from, to = out_to, kind = out_kind, stringsAsFactors = FALSE)
}

# Builds a failed `state$ask` entry and emits an unlight highlight effect.
studio_ask_error <- function(state, question, data, head, lines = list(), notice_room = NULL) {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_string(question, min.chars = 1L)
  checkmate::assert_list(data, names = "unique")
  checkmate::assert_string(head)
  checkmate::assert_list(lines)
  checkmate::assert_string(notice_room, min.chars = 1L, null.ok = TRUE)

  state$ask <- list(
    question = question,
    params = data,
    call = NULL,
    rows = NULL,
    links = NULL,
    rev = state$rev,
    run = state$ack,
    stale = FALSE,
    lit = FALSE,
    error = list(head = head, lines = lines)
  )
  if (!is.null(notice_room)) {
    state <- studio_next_notice(state, head, tone = "problem", room = notice_room)
  } else {
    state["notice"] <- list(NULL)
  }
  list(state = state, effects = list(list(type = "highlight", ids = character(), links = NULL)))
}

# Steps an `ask` event (`question` in `"trace"`, `"orphans"`, `"missing"`), returning `list(state, effects)`.
studio_room_ask_step <- function(state, data) {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_list(data, names = "unique")
  studio_assert_doc(state$doc)

  question <- data$question
  if (!checkmate::test_choice(question, c("trace", "orphans", "missing"))) {
    return(studio_refuse(state, "Unknown question."))
  }
  if (!identical(state$good$rev, state$rev)) {
    return(studio_ask_error(
      state,
      question,
      data,
      "Fix the problems under Check first: questions run on a map that stage_map() accepts.",
      notice_room = "check"
    ))
  }

  map <- state$good$map
  doc <- state$doc
  meta <- list()

  run <- studio_try({
    if (identical(question, "trace")) {
      card_ids <- studio_ask_resolve_uids(doc, "cards", data$ids, "ids", "card", allow_empty = TRUE)
      direction <- if (is.null(data$direction) || identical(data$direction, "")) "downstream" else data$direction
      kinds <- studio_ask_unwrap(data$kinds, "kinds", allow_empty = TRUE)
      max_distance <- studio_ask_resolve_distance(data$max_distance)

      res <- sm_trace(map, card_ids, direction = direction, kinds = kinds, max_distance = max_distance)
      call_args <- list(code_atom("map"), code_value(card_ids))
      if (!identical(direction, "downstream")) {
        call_args$direction <- code_value(direction)
      }
      if (!is.null(kinds)) {
        call_args$kinds <- code_value(kinds)
      }
      if (!isTRUE(is.infinite(max_distance))) {
        call_args$max_distance <- code_value(as.numeric(max_distance))
      }
      meta$direction <- direction
      meta$kinds <- kinds
      meta$max_distance <- max_distance
      meta$call <- studio_ask_call_text("sm_trace", call_args)
      res
    } else if (identical(question, "orphans")) {
      res <- sm_orphans(map)
      meta$call <- studio_ask_call_text("sm_orphans", list(code_atom("map")))
      res
    } else {
      stage_id <- studio_ask_resolve_uids(
        doc,
        "stages",
        data$stage,
        "stage",
        "stage",
        allow_empty = FALSE,
        single = TRUE
      )
      linked_id <- studio_ask_resolve_uids(
        doc,
        "stages",
        data$linked_to,
        "linked_to",
        "stage",
        allow_empty = FALSE,
        single = TRUE
      )
      kinds <- studio_ask_unwrap(data$kinds, "kinds", allow_empty = TRUE)

      res <- sm_missing(map, stage_id, linked_id, kinds = kinds)
      call_args <- list(code_atom("map"), code_value(stage_id), code_value(linked_id))
      if (!is.null(kinds)) {
        call_args$kinds <- code_value(kinds)
      }
      meta$kinds <- kinds
      meta$stage_id <- stage_id
      meta$linked_to_id <- linked_id
      meta$call <- studio_ask_call_text("sm_missing", call_args)
      res
    }
  })

  if (!run$ok) {
    return(studio_ask_error(state, question, data, run$error$head, lines = run$error$lines))
  }

  rows <- run$value
  cards_tbl <- doc$tables$cards
  rows$uid <- if (nrow(rows) > 0L) {
    cards_tbl$.studio_uid[match(rows$id, as_text(cards_tbl$id))]
  } else {
    character()
  }

  links <- if (identical(question, "trace")) studio_ask_trace_links(rows, map) else NULL
  hl_ids <- if (nrow(rows) > 0L) unique(as.character(rows$id)) else character()
  lit <- length(hl_ids) > 0L

  state$ask <- list(
    question = question,
    params = data,
    call = meta$call,
    rows = rows,
    links = links,
    rev = state$rev,
    run = state$ack,
    stale = FALSE,
    lit = lit,
    error = NULL,
    direction = meta$direction,
    kinds = meta$kinds,
    max_distance = meta$max_distance,
    stage_id = meta$stage_id,
    linked_to_id = meta$linked_to_id
  )
  state["notice"] <- list(NULL)
  effects <- list(list(type = "highlight", ids = hl_ids, links = if (lit) links else NULL))
  list(state = state, effects = effects)
}

# Steps an `ask_clear` event: clears `state$ask` and unlights the map.
studio_room_ask_clear <- function(state) {
  checkmate::assert_list(state, names = "unique")
  state["ask"] <- list(NULL)
  state["notice"] <- list(NULL)
  list(state = state, effects = list(list(type = "highlight", ids = character(), links = NULL)))
}

# Link kind choices for Ask (`""` = Every kind), returning NULL when the map has no kinds.
studio_ask_kind_choices <- function(doc) {
  studio_assert_doc(doc)
  choices <- list()
  seen <- character()
  kinds <- doc$tables$kinds
  if (is.data.frame(kinds) && nrow(kinds) > 0L && "id" %in% names(kinds)) {
    for (i in seq_len(nrow(kinds))) {
      id <- as_text(kinds$id[[i]])
      if (is.na(id) || !nzchar(trimws(id)) || (id %in% seen)) {
        next
      }
      seen <- c(seen, id)
      choices[[length(choices) + 1L]] <- studio_choice(id, studio_row_title(kinds, i, id))
    }
  }
  links <- doc$tables$links
  if (is.data.frame(links) && nrow(links) > 0L && "kind" %in% names(links)) {
    used <- stats::na.omit(as_text(links$kind))
    for (k in unique(used[nzchar(trimws(used))])) {
      if (!(k %in% seen)) {
        seen <- c(seen, k)
        choices[[length(choices) + 1L]] <- studio_choice(k, k)
      }
    }
  }
  if (length(choices) == 0L) {
    return(NULL)
  }
  c(list(studio_choice("", "Every kind")), choices)
}

# Builds the three question specifications (`trace`, `orphans`, `missing`) for the Ask view.
studio_ask_questions <- function(state) {
  doc <- state$doc
  card_choices <- studio_table_choices(doc, "cards", value_col = ".studio_uid")
  if (length(card_choices) == 0L) {
    card_choices <- list(studio_choice("", "No cards"))
  }
  card_vals <- vapply(card_choices, `[[`, "", "value")
  default_card <- if (
    identical(state$target$kind, "card") && !is.null(state$target$uid) && (state$target$uid %in% card_vals)
  ) {
    state$target$uid
  } else {
    card_vals[[1L]]
  }

  stage_choices <- studio_table_choices(doc, "stages", value_col = ".studio_uid")
  if (length(stage_choices) == 0L) {
    stage_choices <- list(studio_choice("", "No stages"))
  }
  stage_vals <- vapply(stage_choices, `[[`, "", "value")
  first_stage <- stage_vals[[1L]]
  second_stage <- if (length(stage_vals) >= 2L) stage_vals[[2L]] else first_stage

  kind_choices <- studio_ask_kind_choices(doc)
  kind_field <- if (!is.null(kind_choices)) {
    studio_field("kinds", "Link kind", "select", "", NULL, choices = kind_choices)
  }

  trace_fields <- drop_nulls(list(
    studio_field("ids", "Start card", "select", default_card, NULL, choices = card_choices),
    studio_field(
      "direction",
      "Direction",
      "radio",
      "downstream",
      NULL,
      choices = list(
        studio_choice("downstream", "Downstream"),
        studio_choice("upstream", "Upstream"),
        studio_choice("both", "Both")
      )
    ),
    kind_field,
    studio_field("max_distance", "Distance", "number", NULL, NULL, hint = "Leave blank for no limit")
  ))

  missing_fields <- drop_nulls(list(
    studio_field("stage", "Stage", "select", first_stage, NULL, choices = stage_choices),
    studio_field("linked_to", "Linked to stage", "select", second_stage, NULL, choices = stage_choices),
    kind_field
  ))

  list(
    list(
      id = "trace",
      label = "Trace",
      fields = trace_fields,
      run = studio_action("Run", list(type = "ask", data = list(question = "trace")), style = "primary", collect = TRUE)
    ),
    list(
      id = "orphans",
      label = "Loose ends",
      fields = list(),
      run = studio_action(
        "Run",
        list(type = "ask", data = list(question = "orphans")),
        style = "primary",
        collect = TRUE
      )
    ),
    list(
      id = "missing",
      label = "Gaps",
      fields = missing_fields,
      run = studio_action(
        "Run",
        list(type = "ask", data = list(question = "missing")),
        style = "primary",
        collect = TRUE
      )
    )
  )
}

# Builds the summary sentence for a successful Ask answer.
studio_ask_head <- function(ask, doc) {
  checkmate::assert_list(ask, names = "unique")
  studio_assert_doc(doc)
  rows <- ask$rows
  q <- ask$question

  title_of <- function(table, id) {
    if (is.null(id) || is.na(id) || !nzchar(id)) {
      return("")
    }
    tbl <- doc$tables[[table]]
    if (is.data.frame(tbl) && "id" %in% names(tbl)) {
      idx <- match(id, as_text(tbl$id))
      if (!is.na(idx)) {
        return(studio_row_title(tbl, idx, id))
      }
    }
    id
  }
  stage_title <- function(sid) title_of("stages", sid)
  # The chosen link kinds as words ("Verifies or Hand"), or "" when every kind counts.
  kinds_text <- function() {
    kinds <- ask$kinds
    if (length(kinds) == 0L) {
      return("")
    }
    paste(vapply(kinds, function(k) title_of("kinds", k), ""), collapse = " or ")
  }

  if (identical(q, "trace")) {
    n_start <- sum(rows$direction == "start")
    n_other <- nrow(rows) - n_start
    start_lbls <- if (n_start > 0L) {
      ifelse(
        nzchar(trimws(rows$label[rows$direction == "start"])),
        rows$label[rows$direction == "start"],
        rows$id[rows$direction == "start"]
      )
    } else {
      character()
    }
    if (length(start_lbls) == 0L) {
      return("0 cards traced")
    }
    dir <- ask$direction %||% "downstream"
    phrase <- switch(
      dir,
      downstream = "downstream of",
      upstream = "upstream of",
      both = "either side of",
      "downstream of"
    )
    within <- if (isTRUE(is.finite(ask$max_distance))) {
      steps <- as.integer(ask$max_distance)
      sprintf(" within %d %s", steps, if (steps == 1L) "step" else "steps")
    } else {
      ""
    }
    return(sprintf(
      "%d %s %s %s%s",
      n_other,
      if (n_other == 1L) "card" else "cards",
      phrase,
      paste(start_lbls, collapse = ", "),
      within
    ))
  }

  if (identical(q, "orphans")) {
    n <- nrow(rows)
    if (n == 0L) {
      return("Every card has a link")
    }
    return(sprintf("%d %s with no link", n, if (n == 1L) "card" else "cards"))
  }

  n <- nrow(rows)
  s_lbl <- stage_title(ask$stage_id)
  l_lbl <- stage_title(ask$linked_to_id)
  k_lbl <- kinds_text()
  if (n == 0L) {
    return(sprintf(
      "No gaps: every %s card %s to %s",
      s_lbl,
      if (nzchar(k_lbl)) sprintf("has a %s link", k_lbl) else "links",
      l_lbl
    ))
  }
  sprintf(
    "%d %s in %s with no direct %slink to %s",
    n,
    if (n == 1L) "card" else "cards",
    s_lbl,
    if (nzchar(k_lbl)) paste0(k_lbl, " ") else "",
    l_lbl
  )
}

# Builds the `ask` section view for `state`: `questions` and `answer`.
studio_room_ask_view <- function(state) {
  checkmate::assert_list(state, names = "unique")
  studio_assert_doc(state$doc)

  questions <- studio_ask_questions(state)
  ask <- state$ask
  if (is.null(ask)) {
    return(list(questions = questions, answer = NULL))
  }

  stale <- isTRUE(ask$stale) || !identical(ask$rev, state$rev)
  if (!is.null(ask$error)) {
    return(list(
      questions = questions,
      answer = list(
        question = ask$question,
        call = ask$call,
        run = ask$run,
        stale = stale,
        error = ask$error,
        head = NULL,
        columns = list(),
        rows = list(),
        count = 0L
      )
    ))
  }

  rows_df <- ask$rows
  is_trace <- identical(ask$question, "trace")
  columns <- if (is_trace) list("Card", "Stage", "Distance") else list("Card", "Stage")

  cards_tbl <- state$doc$tables$cards
  live_uids <- if (is.data.frame(cards_tbl)) cards_tbl$.studio_uid else character()
  stages_tbl <- state$doc$tables$stages
  stage_label_of <- function(sid) {
    if (is.data.frame(stages_tbl) && "id" %in% names(stages_tbl)) {
      idx <- match(sid, as_text(stages_tbl$id))
      if (!is.na(idx)) {
        return(studio_row_title(stages_tbl, idx, sid))
      }
    }
    sid
  }

  max_d <- if (is_trace && nrow(rows_df) > 0L) min(6L, max(1L, max(rows_df$distance))) else 1L
  view_rows <- lapply(seq_len(nrow(rows_df)), function(i) {
    uid_i <- if ("uid" %in% names(rows_df)) rows_df$uid[[i]] else NA_character_
    alive <- !is.na(uid_i) && nzchar(uid_i) && (uid_i %in% live_uids)
    card_lbl <- if (nzchar(trimws(rows_df$label[[i]]))) rows_df$label[[i]] else rows_df$id[[i]]
    stage_lbl <- stage_label_of(rows_df$stage[[i]])
    cells <- list(
      list(kind = "card", text = card_lbl),
      list(kind = "text", text = stage_lbl)
    )
    if (is_trace) {
      d <- as.integer(rows_df$distance[[i]])
      dir_r <- rows_df$direction[[i]]
      d_text <- if (identical(dir_r, "start")) {
        "start"
      } else if (identical(dir_r, "upstream")) {
        sprintf("%d up", d)
      } else if (identical(dir_r, "downstream")) {
        sprintf("%d down", d)
      } else {
        sprintf("%d both", d)
      }
      cells[[3L]] <- list(kind = "distance", value = d, max = max_d, text = d_text)
    }
    list(
      uid = if (!is.na(uid_i) && nzchar(uid_i)) uid_i else NULL,
      event = if (alive) list(type = "target", data = list(kind = "card", uid = uid_i)) else NULL,
      cells = cells
    )
  })

  list(
    questions = questions,
    answer = list(
      question = ask$question,
      call = ask$call,
      run = ask$run,
      stale = stale,
      error = NULL,
      head = studio_ask_head(ask, state$doc),
      columns = columns,
      rows = view_rows,
      count = as.integer(nrow(rows_df))
    )
  )
}
