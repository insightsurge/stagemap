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
    outline = studio_view_outline(state$doc),
    inspector = studio_view_inspector(state$doc, state$target, faults = state$check$faults),
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

# Builds one action button description for the page.
studio_action <- function(label, event, style = "plain", disabled = NULL, collect = FALSE, aria_label = NULL) {
  checkmate::assert_string(label, min.chars = 1L)
  checkmate::assert_list(event, names = "unique")
  checkmate::assert_choice(style, c("plain", "primary", "danger"))
  checkmate::assert_string(disabled, min.chars = 1L, null.ok = TRUE)
  checkmate::assert_flag(collect)
  checkmate::assert_string(aria_label, min.chars = 1L, null.ok = TRUE)
  out <- list(
    label = label,
    event = event,
    style = style,
    disabled = disabled,
    collect = collect
  )
  if (!is.null(aria_label)) {
    out$aria_label <- aria_label
  }
  out
}

# Builds one choice for a select or radio field.
studio_choice <- function(value, label, glyph = NULL, missing = FALSE) {
  checkmate::assert_string(value)
  checkmate::assert_string(label, min.chars = 1L)
  checkmate::assert_string(glyph, min.chars = 1L, null.ok = TRUE)
  checkmate::assert_flag(missing)
  list(value = value, label = label, glyph = glyph, missing = missing)
}

# Builds one form field description for the generic form renderer (`form.js`).
studio_field <- function(
  name,
  label,
  type,
  value,
  event,
  choices = NULL,
  hint = NULL,
  problem = NULL,
  action = NULL
) {
  checkmate::assert_string(name, min.chars = 1L)
  checkmate::assert_string(label, min.chars = 1L)
  checkmate::assert_choice(type, c("text", "id", "textarea", "select", "radio", "date", "number", "toggle"))
  checkmate::assert_list(event, names = "unique", null.ok = TRUE)
  checkmate::assert_list(choices, null.ok = TRUE)
  checkmate::assert_string(hint, min.chars = 1L, null.ok = TRUE)
  checkmate::assert_list(problem, names = "unique", null.ok = TRUE)
  checkmate::assert_list(action, names = "unique", null.ok = TRUE)
  out <- list(
    name = name,
    label = label,
    type = type,
    value = value,
    choices = choices,
    hint = hint,
    problem = problem,
    event = event
  )
  if (!is.null(action)) {
    out$action <- action
  }
  out
}

# Display text for row `i` of `tbl`: its label when non-blank, else its id, else `fallback`.
studio_row_title <- function(tbl, i, fallback) {
  checkmate::assert_data_frame(tbl)
  checkmate::assert_count(i, positive = TRUE)
  checkmate::assert_string(fallback, min.chars = 1L)
  has_lbl <- "label" %in% names(tbl) && !is.na(tbl$label[[i]]) && nzchar(trimws(as.character(tbl$label[[i]])))
  if (has_lbl) {
    return(as.character(tbl$label[[i]]))
  }
  has_id <- "id" %in% names(tbl) && !is.na(tbl$id[[i]]) && nzchar(trimws(as_text(tbl$id[[i]])))
  if (has_id) as_text(tbl$id[[i]]) else fallback
}

# Capitalises the first character of a non-empty word.
studio_cap <- function(x) {
  checkmate::assert_string(x, min.chars = 1L)
  paste0(toupper(substr(x, 1L, 1L)), substr(x, 2L, nchar(x)))
}

# Reads a cell of a 1-row data frame as text ("" when missing or NA).
studio_cell_text <- function(row, col) {
  checkmate::assert_data_frame(row, nrows = 1L)
  checkmate::assert_string(col, min.chars = 1L)
  if (!(col %in% names(row))) {
    return("")
  }
  val <- row[[col]][[1L]]
  if (is.null(val) || is.na(val)) {
    return("")
  }
  if (inherits(val, "Date")) {
    return(format(val, "%Y-%m-%d"))
  }
  as.character(val)
}

# Ensures `value` is present in `choices`, appending a `missing = TRUE` choice when absent.
studio_ensure_choice <- function(choices, value, missing_word) {
  checkmate::assert_list(choices)
  checkmate::assert_string(value)
  checkmate::assert_string(missing_word, min.chars = 1L)
  vals <- vapply(choices, `[[`, "", "value")
  if (value %in% vals) {
    return(choices)
  }
  label <- if (nzchar(value)) {
    sprintf("%s (no such %s)", value, missing_word)
  } else {
    sprintf("No %s", missing_word)
  }
  c(choices, list(studio_choice(value, label, missing = TRUE)))
}

# Builds choices from a table (`id` as value, label or id as text), optionally prefixed with a `"None"` choice.
studio_table_choices <- function(doc, table, include_none = FALSE, value_col = "id") {
  studio_assert_doc(doc)
  checkmate::assert_string(table, min.chars = 1L)
  checkmate::assert_flag(include_none)
  checkmate::assert_choice(value_col, c("id", ".studio_uid"))
  out <- if (include_none) list(studio_choice("", "None")) else list()
  tbl <- doc$tables[[table]]
  if (!is.data.frame(tbl) || nrow(tbl) == 0L || !(value_col %in% names(tbl))) {
    return(out)
  }
  row_word <- if (!is.null(stage_map_table_words[[table]])) stage_map_table_words[[table]]$row else table
  for (i in seq_len(nrow(tbl))) {
    val <- if (identical(value_col, "id")) as_text(tbl$id[[i]]) else tbl$.studio_uid[[i]]
    if (is.na(val) || !nzchar(trimws(val))) {
      next
    }
    lbl <- studio_row_title(tbl, i, paste("Untitled", row_word))
    out[[length(out) + 1L]] <- studio_choice(val, lbl)
  }
  out
}

# Tone choices for `table`, read from `sm_spec()`, prefixed with `"None"`.
studio_tone_choices <- function(table) {
  checkmate::assert_string(table, min.chars = 1L)
  vals <- sm_spec()$fields[[table]]$fields$tone$values
  c(list(studio_choice("", "None")), lapply(vals, function(v) studio_choice(v, studio_cap(v))))
}

# Status choices for the map: built-in statuses (with overrides and glyphs), custom status rows, plus None.
studio_status_choices <- function(doc) {
  studio_assert_doc(doc)
  built_in <- sm_spec()$fields$options$fields$statuses$fields
  glyphs <- c(done = "check", running = "play", waiting = "dots", failed = "cross", skipped = "dash")
  words <- doc$args$statuses

  choices <- lapply(names(built_in), function(id) {
    lbl <- if (is.character(words) && id %in% names(words)) {
      unname(words[[id]])
    } else {
      studio_cap(built_in[[id]]$default %||% id)
    }
    glyph <- if (id %in% names(glyphs)) unname(glyphs[[id]]) else NULL
    studio_choice(id, lbl, glyph = glyph)
  })
  seen <- vapply(choices, `[[`, "", "value")

  custom <- doc$tables$statuses
  if (is.data.frame(custom) && nrow(custom) > 0L && "id" %in% names(custom)) {
    for (i in seq_len(nrow(custom))) {
      id <- as_text(custom$id[[i]])
      if (is.na(id) || !nzchar(trimws(id))) {
        next
      }
      lbl <- studio_row_title(custom, i, id)
      idx <- match(id, seen)
      if (!is.na(idx)) {
        choices[[idx]]$label <- lbl
      } else {
        choices[[length(choices) + 1L]] <- studio_choice(id, lbl)
        seen <- c(seen, id)
      }
    }
  }

  c(choices, list(studio_choice("", "None")))
}

# Kind choices from `doc$tables$kinds`, with line style in words and glyph when `include_line` is TRUE, plus `"None"`.
studio_kind_choices <- function(doc, include_line = TRUE) {
  studio_assert_doc(doc)
  checkmate::assert_flag(include_line)
  kinds <- doc$tables$kinds
  out <- list()
  if (is.data.frame(kinds) && nrow(kinds) > 0L && "id" %in% names(kinds)) {
    for (i in seq_len(nrow(kinds))) {
      id <- as_text(kinds$id[[i]])
      if (is.na(id) || !nzchar(trimws(id))) {
        next
      }
      lbl <- studio_row_title(kinds, i, id)
      line <- if ("line" %in% names(kinds) && !is.na(kinds$line[[i]]) && nzchar(trimws(as_text(kinds$line[[i]])))) {
        as_text(kinds$line[[i]])
      } else {
        "solid"
      }
      if (include_line) {
        out[[length(out) + 1L]] <- studio_choice(
          id,
          sprintf("%s (%s)", lbl, line),
          glyph = paste0("line-", line)
        )
      } else {
        out[[length(out) + 1L]] <- studio_choice(id, lbl)
      }
    }
  }
  c(out, list(studio_choice("", "None")))
}

# Problem descriptor (`list(text, fixes)`) for cell `(table, uid, field)`, or NULL when clean.
studio_field_problem <- function(doc, faults, table, uid, field) {
  studio_assert_doc(doc)
  checkmate::assert_data_frame(faults)
  checkmate::assert_string(table, min.chars = 1L)
  checkmate::assert_string(uid, min.chars = 1L)
  checkmate::assert_string(field, min.chars = 1L)
  if (nrow(faults) == 0L) {
    return(NULL)
  }
  hit <- which(faults$table == table & faults$uid == uid & faults$field == field)
  if (length(hit) == 0L) {
    return(NULL)
  }
  f <- faults[hit[[1L]], , drop = FALSE]
  fixes_raw <- studio_fixes(doc, f)
  fix_actions <- lapply(names(fixes_raw), function(fix_name) {
    studio_action(
      fixes_raw[[fix_name]]$label,
      list(type = "fix", data = list(fault = f$id, fix = fix_name))
    )
  })
  list(text = f$text, fixes = fix_actions)
}

# Outline of menus (stages, lanes), hover hint lookup keyed by kind/id, and header add actions.
# The server decides default stage/lane for `+ Card` from `state$target`.
studio_view_outline <- function(doc) {
  studio_assert_doc(doc)
  cards_tbl <- doc$tables$cards
  has_cards <- is.data.frame(cards_tbl) && nrow(cards_tbl) > 0L

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
        label = studio_row_title(tbl, i, paste("Untitled", target_kind)),
        count = as.integer(n_cards),
        event = list(type = "target", data = list(kind = target_kind, uid = uid))
      )
    })
  }

  hint_map <- function(tbl_name, prefix, fallback) {
    tbl <- doc$tables[[tbl_name]]
    if (!is.data.frame(tbl) || nrow(tbl) == 0L || !("id" %in% names(tbl))) {
      return(structure(list(), names = character()))
    }
    ids <- as_text(tbl$id)
    keep <- which(!is.na(tbl$id) & nzchar(trimws(ids)))
    keep <- keep[!duplicated(ids[keep])]
    if (length(keep) == 0L) {
      return(structure(list(), names = character()))
    }
    vals <- vapply(keep, function(i) sprintf("%s: %s", prefix, studio_row_title(tbl, i, fallback)), character(1))
    stats::setNames(as.list(vals), ids[keep])
  }

  list(
    menus = list(
      list(id = "stages", label = "Stages", items = outline_items("stages", "stage", "stage")),
      list(id = "lanes", label = "Lanes", items = outline_items("lanes", "lane", "lane"))
    ),
    hints = list(
      card = hint_map("cards", "Card", "Untitled card"),
      stage = hint_map("stages", "Stage", "Untitled stage")
    ),
    actions = list(
      studio_action("+ Card", list(type = "add", data = list(table = "cards"))),
      studio_action("+ Stage", list(type = "add", data = list(table = "stages"))),
      studio_action("+ Lane", list(type = "add", data = list(table = "lanes")))
    )
  )
}

# Builds the card inspector form: fields, incoming/outgoing link lists with connect forms, and card actions.
studio_form_card <- function(doc, row, faults) {
  studio_assert_doc(doc)
  checkmate::assert_data_frame(row, nrows = 1L)
  checkmate::assert_data_frame(faults)
  uid <- row$.studio_uid[[1L]]
  card_id <- studio_cell_text(row, "id")
  offered <- function(col) identical(studio_arg_where("cards", col), "inspector")
  edit_ev <- function(col) list(type = "edit", data = list(table = "cards", uid = uid, field = col))
  prob <- function(col) studio_field_problem(doc, faults, "cards", uid, col)

  zone_val <- studio_cell_text(row, "zone")
  has_zones <- (is.data.frame(doc$tables$zones) && nrow(doc$tables$zones) > 0L) || nzchar(zone_val)
  stage_val <- studio_cell_text(row, "stage")
  stage_uid <- if (nzchar(stage_val)) studio_uid_of(doc, "stages", stage_val) else NULL
  stage_act <- if (!is.null(stage_uid)) {
    studio_action(
      "Edit",
      list(type = "target", data = list(kind = "stage", uid = stage_uid)),
      aria_label = "Edit stage"
    )
  }
  lane_val <- studio_cell_text(row, "lane")
  lane_uid <- if (nzchar(lane_val)) studio_uid_of(doc, "lanes", lane_val) else NULL
  lane_act <- if (!is.null(lane_uid)) {
    studio_action(
      "Edit",
      list(type = "target", data = list(kind = "lane", uid = lane_uid)),
      aria_label = "Edit lane"
    )
  }
  status_val <- studio_cell_text(row, "status")
  tone_val <- studio_cell_text(row, "tone")
  ms_val <- "milestone" %in% names(row) && isTRUE(row$milestone[[1L]])

  fields <- drop_nulls(list(
    if (offered("label")) {
      studio_field("label", "Label", "text", studio_cell_text(row, "label"), edit_ev("label"), problem = prob("label"))
    },
    if (offered("id")) {
      studio_field("id", "Id", "id", card_id, edit_ev("id"), problem = prob("id"))
    },
    if (offered("stage")) {
      studio_field(
        "stage",
        "Stage",
        "select",
        stage_val,
        edit_ev("stage"),
        choices = studio_ensure_choice(studio_table_choices(doc, "stages"), stage_val, "stage"),
        problem = prob("stage"),
        action = stage_act
      )
    },
    if (offered("lane")) {
      studio_field(
        "lane",
        "Lane",
        "select",
        lane_val,
        edit_ev("lane"),
        choices = studio_ensure_choice(studio_table_choices(doc, "lanes"), lane_val, "lane"),
        problem = prob("lane"),
        action = lane_act
      )
    },
    if (offered("status")) {
      studio_field(
        "status",
        "Status",
        "radio",
        status_val,
        edit_ev("status"),
        choices = studio_ensure_choice(studio_status_choices(doc), status_val, "status"),
        problem = prob("status")
      )
    },
    if (offered("sub")) {
      studio_field("sub", "Second line", "text", studio_cell_text(row, "sub"), edit_ev("sub"), problem = prob("sub"))
    },
    if (offered("tone")) {
      studio_field(
        "tone",
        "Tone",
        "select",
        tone_val,
        edit_ev("tone"),
        choices = studio_ensure_choice(studio_tone_choices("cards"), tone_val, "tone"),
        problem = prob("tone")
      )
    },
    if (offered("zone") && has_zones) {
      studio_field(
        "zone",
        "Zone",
        "select",
        zone_val,
        edit_ev("zone"),
        choices = studio_ensure_choice(studio_table_choices(doc, "zones", include_none = TRUE), zone_val, "zone"),
        problem = prob("zone")
      )
    },
    if (offered("milestone")) {
      studio_field("milestone", "Milestone", "toggle", ms_val, edit_ev("milestone"), problem = prob("milestone"))
    },
    if (offered("text")) {
      studio_field(
        "text",
        "Note",
        "textarea",
        studio_cell_text(row, "text"),
        edit_ev("text"),
        hint = "Markdown",
        problem = prob("text")
      )
    }
  ))

  # Link lists: "Comes from" and "Goes to"
  cards_tbl <- doc$tables$cards
  card_label_of <- function(cid) {
    if (is.na(cid) || !nzchar(trimws(cid))) {
      return("(no card)")
    }
    if (is.data.frame(cards_tbl) && "id" %in% names(cards_tbl)) {
      idx <- match(cid, as_text(cards_tbl$id))
      if (!is.na(idx)) {
        return(studio_row_title(cards_tbl, idx, cid))
      }
    }
    sprintf("%s (no such card)", cid)
  }

  kinds_tbl <- doc$tables$kinds
  has_kinds <- is.data.frame(kinds_tbl) && nrow(kinds_tbl) > 0L
  kind_label_of <- function(kid) {
    if (is.na(kid) || !nzchar(trimws(kid))) {
      return(NULL)
    }
    if (has_kinds && "id" %in% names(kinds_tbl)) {
      idx <- match(kid, as_text(kinds_tbl$id))
      if (!is.na(idx)) {
        return(studio_row_title(kinds_tbl, idx, kid))
      }
    }
    sprintf("%s (no such kind)", kid)
  }

  links_tbl <- doc$tables$links
  link_rows <- function(match_col, other_col) {
    if (!nzchar(trimws(card_id)) || !is.data.frame(links_tbl) || nrow(links_tbl) == 0L) {
      return(list())
    }
    hit <- which(as_text(links_tbl[[match_col]]) == card_id)
    lapply(hit, function(i) {
      lk_uid <- links_tbl$.studio_uid[[i]]
      other_id <- as_text(links_tbl[[other_col]][[i]])
      kid <- if ("kind" %in% names(links_tbl)) as_text(links_tbl$kind[[i]]) else NA_character_
      list(
        uid = lk_uid,
        text = card_label_of(other_id),
        sub = kind_label_of(kid),
        actions = list(
          studio_action("Edit", list(type = "target", data = list(kind = "link", uid = lk_uid))),
          studio_action("Remove", list(type = "remove", data = list(table = "links", uid = lk_uid)), style = "danger")
        )
      )
    })
  }

  other_card_choices <- list()
  if (is.data.frame(cards_tbl) && nrow(cards_tbl) > 0L) {
    for (i in seq_len(nrow(cards_tbl))) {
      c_uid <- cards_tbl$.studio_uid[[i]]
      c_id <- if ("id" %in% names(cards_tbl)) as_text(cards_tbl$id[[i]]) else NA_character_
      if (identical(c_uid, uid) || is.na(c_id) || !nzchar(trimws(c_id))) {
        next
      }
      other_card_choices[[length(other_card_choices) + 1L]] <- studio_choice(
        c_uid,
        studio_row_title(cards_tbl, i, c_id)
      )
    }
  }

  connect_disabled <- if (!nzchar(trimws(card_id))) {
    "Give this card an id first."
  } else if (length(other_card_choices) == 0L) {
    "Add another card first."
  } else {
    NULL
  }

  connect_form <- function(draft_name, fixed_data) {
    first_val <- if (length(other_card_choices) > 0L) other_card_choices[[1L]]$value else ""
    card_choices <- if (length(other_card_choices) > 0L) {
      other_card_choices
    } else {
      list(studio_choice("", "No other cards"))
    }
    add_fields <- list(studio_field(draft_name, "Card", "select", first_val, NULL, choices = card_choices))
    if (has_kinds) {
      add_fields[[length(add_fields) + 1L]] <- studio_field(
        "kind",
        "Kind",
        "select",
        "",
        NULL,
        choices = studio_kind_choices(doc, include_line = FALSE)
      )
    }
    list(
      fields = add_fields,
      action = studio_action(
        "Connect",
        list(type = "link_add", data = c(fixed_data, list(kind = NULL))),
        style = "plain",
        disabled = connect_disabled,
        collect = TRUE
      )
    )
  }

  lists <- list(
    list(
      name = "in",
      label = "Comes from",
      rows = link_rows("to", "from"),
      add = connect_form("from", list(to = uid))
    ),
    list(
      name = "out",
      label = "Goes to",
      rows = link_rows("from", "to"),
      add = connect_form("to", list(from = uid))
    )
  )

  rm_disabled <- if (nrow(cards_tbl) <= 1L) "Cannot remove the last card." else NULL
  actions <- list(
    studio_action(
      "Trace from here",
      list(type = "ask", data = list(question = "trace", ids = list(uid), direction = "downstream"))
    ),
    studio_action(
      "Remove card",
      list(type = "remove", data = list(table = "cards", uid = uid)),
      style = "danger",
      disabled = rm_disabled
    )
  )

  list(fields = fields, lists = lists, actions = actions)
}

# Builds the "Cards here" list rows for a stage or lane row.
studio_cards_here <- function(doc, col, id_val, other_tbl, other_col) {
  studio_assert_doc(doc)
  checkmate::assert_string(col, min.chars = 1L)
  checkmate::assert_string(id_val)
  checkmate::assert_string(other_tbl, min.chars = 1L)
  checkmate::assert_string(other_col, min.chars = 1L)
  cards <- doc$tables$cards
  if (!nzchar(trimws(id_val)) || !is.data.frame(cards) || nrow(cards) == 0L || !(col %in% names(cards))) {
    return(list())
  }
  other <- doc$tables[[other_tbl]]
  other_ids <- if (is.data.frame(other) && "id" %in% names(other)) as_text(other$id) else character()
  hit <- which(as_text(cards[[col]]) == id_val)
  lapply(hit, function(i) {
    c_uid <- cards$.studio_uid[[i]]
    sub_val <- NULL
    if (other_col %in% names(cards)) {
      oid <- as_text(cards[[other_col]][[i]])
      if (!is.na(oid) && nzchar(trimws(oid))) {
        idx <- match(oid, other_ids)
        sub_val <- if (!is.na(idx)) studio_row_title(other, idx, oid) else oid
      }
    }
    list(
      uid = c_uid,
      text = studio_row_title(cards, i, "Untitled card"),
      sub = sub_val,
      actions = list(studio_action("Edit", list(type = "target", data = list(kind = "card", uid = c_uid))))
    )
  })
}

# Builds the stage inspector form: fields, cards list, and order/add/remove actions.
studio_form_stage <- function(doc, row, faults) {
  studio_assert_doc(doc)
  checkmate::assert_data_frame(row, nrows = 1L)
  checkmate::assert_data_frame(faults)
  uid <- row$.studio_uid[[1L]]
  stage_id <- studio_cell_text(row, "id")
  offered <- function(col) identical(studio_arg_where("stages", col), "inspector")
  edit_ev <- function(col) list(type = "edit", data = list(table = "stages", uid = uid, field = col))
  prob <- function(col) studio_field_problem(doc, faults, "stages", uid, col)

  tone_val <- studio_cell_text(row, "tone")
  fields <- drop_nulls(list(
    if (offered("label")) {
      studio_field("label", "Label", "text", studio_cell_text(row, "label"), edit_ev("label"), problem = prob("label"))
    },
    if (offered("id")) {
      studio_field("id", "Id", "id", stage_id, edit_ev("id"), problem = prob("id"))
    },
    if (offered("kicker")) {
      studio_field(
        "kicker",
        "Kicker",
        "text",
        studio_cell_text(row, "kicker"),
        edit_ev("kicker"),
        problem = prob("kicker")
      )
    },
    if (offered("text")) {
      studio_field(
        "text",
        "Note",
        "textarea",
        studio_cell_text(row, "text"),
        edit_ev("text"),
        hint = "Markdown",
        problem = prob("text")
      )
    },
    if (offered("date")) {
      studio_field("date", "Date", "date", studio_cell_text(row, "date"), edit_ev("date"), problem = prob("date"))
    },
    if (offered("flag")) {
      studio_field("flag", "Flag", "text", studio_cell_text(row, "flag"), edit_ev("flag"), problem = prob("flag"))
    },
    if (offered("tone")) {
      studio_field(
        "tone",
        "Tone",
        "select",
        tone_val,
        edit_ev("tone"),
        choices = studio_ensure_choice(studio_tone_choices("stages"), tone_val, "tone"),
        problem = prob("tone")
      )
    }
  ))

  rows <- studio_cards_here(doc, "stage", stage_id, "lanes", "lane")
  lists <- list(list(name = "cards", label = "Cards here", rows = rows, add = NULL))

  stages <- doc$tables$stages
  idx <- match(uid, stages$.studio_uid)
  n_cards <- length(rows)
  rm_disabled <- if (nrow(stages) <= 1L) {
    "Cannot remove the last stage."
  } else if (n_cards > 0L) {
    sprintf("Move its %d %s first.", n_cards, if (n_cards == 1L) "card" else "cards")
  } else {
    NULL
  }
  add_disabled <- if (!nzchar(trimws(stage_id))) "Give this stage an id first." else NULL

  actions <- list(
    studio_action(
      "Earlier",
      list(type = "move", data = list(table = "stages", uid = uid, by = -1L)),
      disabled = if (idx <= 1L) "Already the first stage." else NULL
    ),
    studio_action(
      "Later",
      list(type = "move", data = list(table = "stages", uid = uid, by = 1L)),
      disabled = if (idx >= nrow(stages)) "Already the last stage." else NULL
    ),
    studio_action(
      "Add a card here",
      list(type = "add", data = list(table = "cards", stage = uid)),
      disabled = add_disabled
    ),
    studio_action(
      "Remove stage",
      list(type = "remove", data = list(table = "stages", uid = uid)),
      style = "danger",
      disabled = rm_disabled
    )
  )

  list(fields = fields, lists = lists, actions = actions)
}

# Builds the lane inspector form: fields, cards list, and order/remove actions.
studio_form_lane <- function(doc, row, faults) {
  studio_assert_doc(doc)
  checkmate::assert_data_frame(row, nrows = 1L)
  checkmate::assert_data_frame(faults)
  uid <- row$.studio_uid[[1L]]
  lane_id <- studio_cell_text(row, "id")
  offered <- function(col) identical(studio_arg_where("lanes", col), "inspector")
  edit_ev <- function(col) list(type = "edit", data = list(table = "lanes", uid = uid, field = col))
  prob <- function(col) studio_field_problem(doc, faults, "lanes", uid, col)

  tone_val <- studio_cell_text(row, "tone")
  fields <- drop_nulls(list(
    if (offered("label")) {
      studio_field("label", "Label", "text", studio_cell_text(row, "label"), edit_ev("label"), problem = prob("label"))
    },
    if (offered("id")) {
      studio_field("id", "Id", "id", lane_id, edit_ev("id"), problem = prob("id"))
    },
    if (offered("tone")) {
      studio_field(
        "tone",
        "Tone",
        "select",
        tone_val,
        edit_ev("tone"),
        choices = studio_ensure_choice(studio_tone_choices("lanes"), tone_val, "tone"),
        problem = prob("tone")
      )
    },
    if (offered("text")) {
      studio_field(
        "text",
        "Note",
        "textarea",
        studio_cell_text(row, "text"),
        edit_ev("text"),
        hint = "Markdown",
        problem = prob("text")
      )
    }
  ))

  rows <- studio_cards_here(doc, "lane", lane_id, "stages", "stage")
  lists <- list(list(name = "cards", label = "Cards here", rows = rows, add = NULL))

  lanes <- doc$tables$lanes
  idx <- match(uid, lanes$.studio_uid)
  n_cards <- length(rows)
  rm_disabled <- if (nrow(lanes) <= 1L) {
    "Cannot remove the last lane."
  } else if (n_cards > 0L) {
    sprintf("Move its %d %s first.", n_cards, if (n_cards == 1L) "card" else "cards")
  } else {
    NULL
  }

  actions <- list(
    studio_action(
      "Higher",
      list(type = "move", data = list(table = "lanes", uid = uid, by = -1L)),
      disabled = if (idx <= 1L) "Already the first lane." else NULL
    ),
    studio_action(
      "Lower",
      list(type = "move", data = list(table = "lanes", uid = uid, by = 1L)),
      disabled = if (idx >= nrow(lanes)) "Already the last lane." else NULL
    ),
    studio_action(
      "Remove lane",
      list(type = "remove", data = list(table = "lanes", uid = uid)),
      style = "danger",
      disabled = rm_disabled
    )
  )

  list(fields = fields, lists = lists, actions = actions)
}

# Builds the link inspector form: ends, kind (when map has kinds), label, and swap/remove actions.
studio_form_link <- function(doc, row, faults) {
  studio_assert_doc(doc)
  checkmate::assert_data_frame(row, nrows = 1L)
  checkmate::assert_data_frame(faults)
  uid <- row$.studio_uid[[1L]]
  offered <- function(col) identical(studio_arg_where("links", col), "inspector")
  edit_ev <- function(col) list(type = "edit", data = list(table = "links", uid = uid, field = col))
  prob <- function(col) studio_field_problem(doc, faults, "links", uid, col)

  card_choices <- studio_table_choices(doc, "cards")
  from_val <- studio_cell_text(row, "from")
  to_val <- studio_cell_text(row, "to")
  kind_val <- studio_cell_text(row, "kind")
  has_kinds <- (is.data.frame(doc$tables$kinds) && nrow(doc$tables$kinds) > 0L) || nzchar(kind_val)
  fields <- drop_nulls(list(
    if (offered("from")) {
      studio_field(
        "from",
        "From",
        "select",
        from_val,
        edit_ev("from"),
        choices = studio_ensure_choice(card_choices, from_val, "card"),
        problem = prob("from")
      )
    },
    if (offered("to")) {
      studio_field(
        "to",
        "To",
        "select",
        to_val,
        edit_ev("to"),
        choices = studio_ensure_choice(card_choices, to_val, "card"),
        problem = prob("to")
      )
    },
    if (offered("kind") && has_kinds) {
      studio_field(
        "kind",
        "Kind",
        "radio",
        kind_val,
        edit_ev("kind"),
        choices = studio_ensure_choice(studio_kind_choices(doc, include_line = TRUE), kind_val, "kind"),
        problem = prob("kind")
      )
    },
    if (offered("label")) {
      studio_field("label", "Label", "text", studio_cell_text(row, "label"), edit_ev("label"), problem = prob("label"))
    }
  ))

  actions <- list(
    studio_action("Swap ends", list(type = "link_reverse", data = list(uid = uid))),
    studio_action("Remove link", list(type = "remove", data = list(table = "links", uid = uid)), style = "danger")
  )

  list(fields = fields, lists = list(), actions = actions)
}

# Inspector section for the targeted row: head (`kind`, `uid`, `title`, `sub`) plus its form.
studio_view_inspector <- function(doc, target, faults = NULL) {
  studio_assert_doc(doc)
  checkmate::assert_list(target, names = "unique")
  checkmate::assert_data_frame(faults, null.ok = TRUE)
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
  if (is.null(faults)) {
    faults <- studio_faults(doc)
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
  form <- switch(
    target$kind,
    card = studio_form_card(doc, row, faults),
    stage = studio_form_stage(doc, row, faults),
    lane = studio_form_lane(doc, row, faults),
    link = studio_form_link(doc, row, faults)
  )
  list(
    kind = target$kind,
    uid = target$uid,
    title = title,
    sub = sub,
    fields = form$fields,
    lists = form$lists,
    actions = form$actions
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
