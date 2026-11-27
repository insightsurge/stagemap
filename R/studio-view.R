# What the page shows, computed from the state: a named list of sections, each the value one renderer on the page draws.
# The server sends only the sections that changed (studio_message()). Rooms register their view builders in
# `studio_rooms` so each room is owned by its own file.

# Registered rooms and their view builders; studio_view() calls each with `state`.
studio_rooms <- list(
  ask = list(view = studio_room_ask_view),
  check = list(view = studio_room_check_view),
  code = list(view = studio_room_code_view),
  map = list(view = studio_room_map_view)
)

# The view of `state`: every core section and every registered room section.
studio_view <- function(state) {
  checkmate::assert_list(state, names = "unique")
  title <- state$doc$args$title %||% ""
  core <- list(
    header = list(title = title, facts = studio_facts(state$doc), template = state$template),
    outline = studio_view_outline(state$doc, state$target),
    inspector = studio_view_inspector(state$doc, state$target),
    journal = list(
      entries = studio_view_journal(state$journal, doc = state$doc),
      can_undo = studio_journal_can_undo(state$journal)
    ),
    start = studio_view_start(state),
    status = list(drawn_rev = state$good$rev, problems = nrow(state$check$faults), closed = state$closed),
    notice = state$notice
  )
  rooms <- lapply(studio_rooms, function(room) room$view(state))
  c(core, rooms)
}

# The line under the title that says how big the map is, such as "4 cards in 3 stages and 2 lanes, 3 links". Accepts a
# studio document or a stagemap widget.
studio_facts <- function(x) {
  checkmate::assert(
    checkmate::check_class(x, "stagemap_widget"),
    checkmate::check_list(x, names = "unique"),
    .var.name = "x"
  )
  tables <- if (inherits(x, "stagemap_widget")) sm_widget_data(x) else x$tables
  count <- function(table, one, many) {
    n <- if (is.data.frame(tables[[table]])) nrow(tables[[table]]) else 0L
    sprintf("%d %s", n, if (n == 1L) one else many)
  }
  sprintf(
    "%s in %s and %s, %s",
    count("cards", "card", "cards"),
    count("stages", "stage", "stages"),
    count("lanes", "lane", "lanes"),
    count("links", "link", "links")
  )
}

# Outline of stages, lanes, cards (for hover hints) and header add actions, with target/add event payloads built in R.
studio_view_outline <- function(doc, target) {
  studio_assert_doc(doc)
  checkmate::assert_list(target, names = "unique")
  cards_tbl <- doc$tables$cards
  has_cards <- is.data.frame(cards_tbl) && nrow(cards_tbl) > 0L

  row_label <- function(tbl, i, fallback) {
    has_lbl <- "label" %in% names(tbl) && !is.na(tbl$label[[i]]) && nzchar(trimws(as.character(tbl$label[[i]])))
    if (has_lbl) {
      return(as.character(tbl$label[[i]]))
    }
    has_id <- "id" %in% names(tbl) && !is.na(tbl$id[[i]]) && nzchar(trimws(as_text(tbl$id[[i]])))
    if (has_id) as_text(tbl$id[[i]]) else fallback
  }

  outline_items <- function(tbl_name, count_col, target_kind) {
    tbl <- doc$tables[[tbl_name]]
    if (!is.data.frame(tbl) || nrow(tbl) == 0L) {
      return(list())
    }
    col_vals <- if (has_cards && count_col %in% names(cards_tbl)) as_text(cards_tbl[[count_col]]) else character()
    lapply(seq_len(nrow(tbl)), function(i) {
      uid <- tbl$.studio_uid[[i]]
      id <- if ("id" %in% names(tbl) && !is.na(tbl$id[[i]])) as_text(tbl$id[[i]]) else ""
      n_cards <- if (nzchar(id) && length(col_vals) > 0L) sum(col_vals == id, na.rm = TRUE) else 0L
      list(
        uid = uid,
        id = id,
        label = row_label(tbl, i, paste("Untitled", target_kind)),
        cards = as.integer(n_cards),
        event = list(type = "target", data = list(kind = target_kind, uid = uid))
      )
    })
  }

  card_items <- if (has_cards) {
    lapply(seq_len(nrow(cards_tbl)), function(i) {
      list(
        uid = cards_tbl$.studio_uid[[i]],
        id = if ("id" %in% names(cards_tbl) && !is.na(cards_tbl$id[[i]])) as_text(cards_tbl$id[[i]]) else "",
        label = row_label(cards_tbl, i, "Untitled card")
      )
    })
  } else {
    list()
  }

  stage_uid <- NULL
  lane_uid <- NULL
  if (identical(target$kind, "card") && !is.null(target$uid)) {
    card_row <- studio_row(doc, "cards", target$uid)
    if (!is.null(card_row)) {
      if (!is.na(card_row$stage) && nzchar(as_text(card_row$stage))) {
        stage_uid <- studio_uid_of(doc, "stages", as_text(card_row$stage))
      }
      if (!is.na(card_row$lane) && nzchar(as_text(card_row$lane))) {
        lane_uid <- studio_uid_of(doc, "lanes", as_text(card_row$lane))
      }
    }
  } else if (identical(target$kind, "stage") && !is.null(target$uid)) {
    if (!is.null(studio_row(doc, "stages", target$uid))) {
      stage_uid <- target$uid
    }
  }

  add_action <- function(label, data) {
    list(label = label, event = list(type = "add", data = data), style = "plain", disabled = NULL, collect = FALSE)
  }

  list(
    stages = outline_items("stages", "stage", "stage"),
    lanes = outline_items("lanes", "lane", "lane"),
    cards = card_items,
    actions = list(
      add_action("+ Card", drop_nulls(list(table = "cards", stage = stage_uid, lane = lane_uid))),
      add_action("+ Stage", list(table = "stages")),
      add_action("+ Lane", list(table = "lanes"))
    )
  )
}

# Inspector head for the targeted row: `kind`, `uid`, `title`, `sub`, empty `fields`/`lists`, and Close.
studio_view_inspector <- function(doc, target) {
  studio_assert_doc(doc)
  checkmate::assert_list(target, names = "unique")
  if (identical(target$kind, "none") || is.null(target$uid)) {
    return(NULL)
  }
  tbl_name <- studio_target_table(target$kind)
  if (is.null(tbl_name)) {
    return(NULL)
  }
  row <- studio_row(doc, tbl_name, target$uid)
  if (is.null(row)) {
    return(NULL)
  }
  if (identical(target$kind, "link")) {
    title <- sprintf("%s -> %s", studio_fmt_val(row$from), studio_fmt_val(row$to))
    kind_val <- if ("kind" %in% names(row)) row$kind else NA_character_
    sub <- if (!is.na(kind_val) && nzchar(trimws(as_text(kind_val)))) as_text(kind_val) else "plain"
  } else {
    id_val <- if ("id" %in% names(row) && !is.na(row$id) && nzchar(trimws(as_text(row$id)))) as_text(row$id) else NULL
    lbl_val <- if ("label" %in% names(row) && !is.na(row$label) && nzchar(trimws(as.character(row$label)))) {
      as.character(row$label)
    } else {
      NULL
    }
    title <- lbl_val %||% id_val %||% paste("Untitled", target$kind)
    sub <- id_val %||% "(no id)"
  }
  list(
    kind = target$kind,
    uid = target$uid,
    title = title,
    sub = sub,
    fields = list(),
    lists = list(),
    actions = list(list(
      label = "Close",
      event = list(type = "target", data = list(kind = "none", uid = NULL)),
      style = "plain",
      disabled = NULL,
      collect = FALSE
    ))
  )
}

# Projects at most the newest 50 `journal` entries to the page fields (`n`, `verb`, `text`, `state`, `target`), clearing
# `target` when `doc` is given and that row no longer exists.
studio_view_journal <- function(journal, doc = NULL) {
  checkmate::assert_list(journal)
  if (!is.null(doc)) {
    studio_assert_doc(doc)
  }
  if (length(journal) > 50L) {
    journal <- utils::tail(journal, 50L)
  }
  lapply(journal, function(entry) {
    out <- entry[c("n", "verb", "text", "state", "target")]
    if (!is.null(doc) && !is.null(out$target)) {
      tbl_name <- studio_target_table(out$target$kind)
      if (is.null(tbl_name) || is.null(studio_row(doc, tbl_name, out$target$uid))) {
        out$target <- NULL
      }
    }
    out
  })
}

# Start card view: open flag and template options, switching an unconfirmed choice to confirmation text after refusal.
studio_view_start <- function(state) {
  checkmate::assert_list(state, names = "unique")
  option <- function(id, title, default_text) {
    confirm <- identical(state$confirm_open, id)
    list(
      id = id,
      title = title,
      text = if (confirm) "Click again to replace your changes" else default_text,
      event = list(type = "open", data = list(template = id, confirm = confirm))
    )
  }
  options <- list(
    option(
      "example",
      "Open the example",
      "Dose calculator validation: requirements, functions, tests and results. One link has a fault to find."
    ),
    option(
      "blank",
      "Start with one card",
      "One stage, one lane and one card. A map needs at least one card to draw."
    )
  )
  if (!is.null(state$given_map)) {
    options[[length(options) + 1L]] <- option(
      "given",
      "Your map",
      "The map you passed to stage_map_studio()."
    )
  }
  list(open = isTRUE(state$start_open), options = options)
}
