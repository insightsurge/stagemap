# Document-changing events: payload checks and resolution into changes (with cascades and plain refusal reasons).
# Callers: studio_step() calls studio_resolve(doc, event).

# Formats a cell or option value for a journal entry line.
studio_fmt_val <- function(x) {
  checkmate::assert(
    checkmate::check_null(x),
    checkmate::check_atomic(x)
  )
  if (is.null(x) || (length(x) == 1L && is.na(x))) {
    return("(none)")
  }
  text <- if (inherits(x, "Date")) format(x, "%Y-%m-%d") else as.character(x)[[1L]]
  if (!nzchar(text)) "(blank)" else text
}

# The short name shown for a row in journal text (its `id`, or `from -> to` for links).
studio_row_label <- function(table, row) {
  checkmate::assert_string(table, min.chars = 1L)
  checkmate::assert_data_frame(row, nrows = 1L)
  if (identical(table, "links")) {
    return(sprintf("%s -> %s", studio_fmt_val(row$from), studio_fmt_val(row$to)))
  }
  studio_fmt_val(row$id)
}

# Operations that cascade an `id` rename in `table` from `old_id` to `new_id` across `stage_map_joins`,
# `changes`, and `args$target`/`args$variant`. Blank or duplicate values never cascade.
studio_cascade_ops <- function(doc, table, old_id, new_id) {
  studio_assert_doc(doc)
  checkmate::assert_string(table, min.chars = 1L)
  checkmate::assert_string(old_id, na.ok = TRUE)
  checkmate::assert_string(new_id, na.ok = TRUE)

  if (is.na(old_id) || !nzchar(trimws(old_id)) || is.na(new_id) || !nzchar(trimws(new_id))) {
    return(list())
  }
  target_tbl <- doc$tables[[table]]
  if (is.null(target_tbl) || !("id" %in% names(target_tbl))) {
    return(list())
  }
  existing <- as_text(target_tbl$id)
  if (sum(existing == old_id, na.rm = TRUE) != 1L || sum(existing == new_id, na.rm = TRUE) > 0L) {
    return(list())
  }

  ops <- list()
  for (join in stage_map_joins) {
    if (!identical(join$to, table)) {
      next
    }
    tbl <- doc$tables[[join$table]]
    if (is.null(tbl) || !(join$column %in% names(tbl))) {
      next
    }
    vals <- as_text(tbl[[join$column]])
    for (i in seq_len(nrow(tbl))) {
      v <- vals[[i]]
      if (is.na(v)) {
        next
      }
      if (isTRUE(join$split)) {
        parts <- trimws(strsplit(v, ",", fixed = TRUE)[[1L]])
        if (old_id %in% parts) {
          parts[parts == old_id] <- new_id
          ops[[length(ops) + 1L]] <- list(
            op = "set",
            table = join$table,
            uid = tbl$.studio_uid[[i]],
            field = join$column,
            value = paste(parts, collapse = ", ")
          )
        }
      } else if (identical(v, old_id)) {
        ops[[length(ops) + 1L]] <- list(
          op = "set",
          table = join$table,
          uid = tbl$.studio_uid[[i]],
          field = join$column,
          value = new_id
        )
      }
    }
  }

  changes <- doc$tables$changes
  if (is.data.frame(changes) && nrow(changes) > 0L) {
    col <- switch(table, cards = "card", stages = "stage", steps = "step", NULL)
    if (!is.null(col) && (col %in% names(changes))) {
      vals <- as_text(changes[[col]])
      for (i in which(vals == old_id)) {
        ops[[length(ops) + 1L]] <- list(
          op = "set",
          table = "changes",
          uid = changes$.studio_uid[[i]],
          field = col,
          value = new_id
        )
      }
    }
  }

  if (identical(table, "cards") && identical(as_text(doc$args$target), old_id)) {
    ops[[length(ops) + 1L]] <- list(op = "arg", name = "target", value = new_id)
  }
  if (identical(table, "variants") && identical(as_text(doc$args$variant), old_id)) {
    ops[[length(ops) + 1L]] <- list(op = "arg", name = "variant", value = new_id)
  }

  ops
}

# Checks and resolves an `edit` event: `{table, uid, field, value}`.
studio_check_edit <- function(data) {
  checkmate::assert_list(data, names = "unique")
  checkmate::assert_string(data$table, min.chars = 1L)
  checkmate::assert_string(data$uid, min.chars = 1L)
  checkmate::assert_string(data$field, min.chars = 1L)
  checkmate::assert(
    checkmate::check_string(data$value, null.ok = TRUE),
    checkmate::check_flag(data$value),
    checkmate::check_number(data$value),
    checkmate::check_date(data$value),
    .var.name = "data$value"
  )
  invisible(data)
}

studio_resolve_edit <- function(doc, data) {
  studio_assert_doc(doc)
  studio_check_edit(data)
  if (!identical(studio_arg_where(data$table, data$field), "inspector")) {
    return(list(refused = sprintf("The studio cannot edit `%s` on %s here.", data$field, data$table)))
  }
  row <- studio_row(doc, data$table, data$uid)
  if (is.null(row)) {
    return(list(refused = "That item is no longer in the map."))
  }
  spec <- studio_field_spec(data$table, data$field)
  new_val <- tryCatch(
    studio_coerce_cell(data$table, data$field, data$value),
    stagemap_error_studio = function(e) structure(list(msg = cli::ansi_strip(conditionMessage(e))), class = "bad_val")
  )
  if (inherits(new_val, "bad_val")) {
    return(list(refused = new_val$msg))
  }
  old_val <- if (data$field %in% names(row)) {
    v <- row[[data$field]]
    if (is.factor(v)) as.character(v) else v
  } else {
    studio_typed_na(spec$type, 1L)
  }
  if (
    identical(new_val, old_val) || (length(new_val) == 1L && length(old_val) == 1L && is.na(new_val) && is.na(old_val))
  ) {
    return(list(verb = "Edit", text = "", key = NA_character_, target = NULL, ops = list()))
  }

  ops <- list(list(op = "set", table = data$table, uid = data$uid, field = data$field, value = new_val))
  if (identical(data$field, "id")) {
    ops <- c(ops, studio_cascade_ops(doc, data$table, as_text(old_val), as_text(new_val)))
  }

  row_word <- if (identical(data$table, "links")) "link" else stage_map_table_words[[data$table]]$row
  old_text <- studio_fmt_val(old_val)
  new_text <- studio_fmt_val(new_val)
  prefix <- sprintf("%s %s %s: ", row_word, studio_row_label(data$table, row), data$field)
  list(
    verb = "Edit",
    text = paste0(prefix, old_text, " > ", new_text),
    key = paste("edit", data$table, data$uid, data$field, sep = ":"),
    target = list(kind = row_word, uid = data$uid),
    ops = ops,
    join = list(
      first_val = old_val,
      first_text = old_text,
      new_val = new_val,
      new_text = new_text,
      prefix = prefix
    )
  )
}

# Checks and resolves an `option` event: `{name, value}`.
studio_check_option <- function(data) {
  checkmate::assert_list(data, names = "unique")
  checkmate::assert_string(data$name, min.chars = 1L)
  checkmate::assert(
    checkmate::check_string(data$value, null.ok = TRUE),
    checkmate::check_flag(data$value),
    checkmate::check_number(data$value),
    .var.name = "data$value"
  )
  invisible(data)
}

studio_resolve_option <- function(doc, data) {
  studio_assert_doc(doc)
  studio_check_option(data)
  where <- studio_arg_where("arg", data$name)
  if (is.null(where) || !(where %in% c("header", "map"))) {
    return(list(refused = "The studio does not change that option here."))
  }
  value <- data$value
  if (identical(data$name, "title")) {
    if (!checkmate::test_string(value) || !nzchar(trimws(value))) {
      return(list(refused = "The title was not changed: a map's title cannot be blank."))
    }
  } else if (identical(data$name, "layout")) {
    choices <- sm_spec()$fields$options$fields$layout$values
    if (!checkmate::test_choice(value, choices)) {
      return(list(refused = sprintf("Layout must be one of: %s.", paste(choices, collapse = ", "))))
    }
  } else if (identical(data$name, "target")) {
    if (is.null(value) || (is.character(value) && !nzchar(value))) {
      value <- NULL
    } else {
      if (is.numeric(value)) {
        if (!is.finite(value) || value != floor(value)) {
          return(list(refused = "Target must be a card id."))
        }
        value <- as_text(value)
      }
      if (!is.character(value) || !nzchar(trimws(value)) || !(value %in% as_text(doc$tables$cards$id))) {
        return(list(refused = "Target must be a card of the map."))
      }
    }
  } else if (data$name %in% c("legend", "bundle_links")) {
    if (!checkmate::test_flag(value)) {
      return(list(refused = sprintf("Option `%s` must be TRUE or FALSE.", data$name)))
    }
  } else if (identical(data$name, "cell_columns")) {
    if (is.numeric(value)) {
      if (!checkmate::test_int(value, lower = 1L, upper = 6L)) {
        return(list(refused = "Cards per cell must be a whole number from 1 to 6, or \"auto\"."))
      }
      value <- as.integer(value)
    } else if (!identical(value, "auto")) {
      return(list(refused = "Cards per cell must be a whole number from 1 to 6, or \"auto\"."))
    }
  }

  old_val <- doc$args[[data$name]]
  same_num <- is.numeric(value) && is.numeric(old_val) && isTRUE(value == old_val)
  if (identical(value, old_val) || same_num) {
    return(list(verb = "Set", text = "", key = NA_character_, target = NULL, ops = list()))
  }

  old_text <- studio_fmt_val(old_val)
  new_text <- studio_fmt_val(value)
  prefix <- sprintf("Set %s: ", data$name)
  list(
    verb = "Set",
    text = paste0(prefix, old_text, " > ", new_text),
    key = paste0("arg:", data$name),
    target = NULL,
    ops = list(list(op = "arg", name = data$name, value = value)),
    join = list(
      first_val = old_val,
      first_text = old_text,
      new_val = value,
      new_text = new_text,
      prefix = prefix
    )
  )
}

# Checks and resolves an `add` event: `{table, stage, lane}` (`stage` and `lane` optional uids).
studio_check_add <- function(data) {
  checkmate::assert_list(data, names = "unique")
  checkmate::assert_choice(data$table, c("cards", "stages", "lanes"))
  checkmate::assert_string(data$stage, min.chars = 1L, null.ok = TRUE)
  checkmate::assert_string(data$lane, min.chars = 1L, null.ok = TRUE)
  invisible(data)
}

studio_resolve_add <- function(doc, data) {
  studio_assert_doc(doc)
  studio_check_add(data)
  new_id <- studio_free_id(doc, data$table)
  new_uid <- paste0("u", doc$next_uid)
  row_word <- stage_map_table_words[[data$table]]$row

  if (identical(data$table, "cards")) {
    stages <- doc$tables$stages
    lanes <- doc$tables$lanes
    if (is.null(stages) || nrow(stages) == 0L || is.null(lanes) || nrow(lanes) == 0L) {
      return(list(refused = "Add a stage and a lane before adding a card."))
    }
    stage_row <- if (!is.null(data$stage)) studio_row(doc, "stages", data$stage) else stages[1L, , drop = FALSE]
    if (is.null(stage_row)) {
      return(list(refused = "That stage is no longer in the map."))
    }
    lane_row <- if (!is.null(data$lane)) studio_row(doc, "lanes", data$lane) else lanes[1L, , drop = FALSE]
    if (is.null(lane_row)) {
      return(list(refused = "That lane is no longer in the map."))
    }
    stage_id <- as_text(stage_row$id)
    lane_id <- as_text(lane_row$id)
    if (is.na(stage_id) || !nzchar(trimws(stage_id)) || is.na(lane_id) || !nzchar(trimws(lane_id))) {
      return(list(refused = "Give the stage and lane an id before adding a card to them."))
    }
    row <- list(id = new_id, label = "New card", stage = stage_id, lane = lane_id)
  } else {
    row <- list(id = new_id, label = paste("New", row_word))
  }

  list(
    verb = "Add",
    text = sprintf("Add %s %s", row_word, new_id),
    key = NA_character_,
    target = list(kind = row_word, uid = new_uid),
    ops = list(list(op = "insert", table = data$table, row = row, after = NULL))
  )
}

# Checks and resolves a `remove` event: `{table, uid}`.
studio_check_remove <- function(data) {
  checkmate::assert_list(data, names = "unique")
  checkmate::assert_choice(data$table, c("cards", "stages", "lanes", "links"))
  checkmate::assert_string(data$uid, min.chars = 1L)
  invisible(data)
}

studio_resolve_remove <- function(doc, data) {
  studio_assert_doc(doc)
  studio_check_remove(data)
  row <- studio_row(doc, data$table, data$uid)
  if (is.null(row)) {
    return(list(refused = "That item is no longer in the map."))
  }
  row_word <- if (identical(data$table, "links")) "link" else stage_map_table_words[[data$table]]$row
  if (data$table %in% c("cards", "stages", "lanes") && nrow(doc$tables[[data$table]]) <= 1L) {
    return(list(refused = sprintf("Cannot remove the last %s.", row_word)))
  }
  if (data$table %in% c("stages", "lanes")) {
    col <- if (identical(data$table, "stages")) "stage" else "lane"
    row_id <- as_text(row$id)
    n_cards <- if (!is.na(row_id) && nzchar(row_id)) {
      sum(as_text(doc$tables$cards[[col]]) == row_id, na.rm = TRUE)
    } else {
      0L
    }
    if (n_cards > 0L) {
      return(list(refused = sprintf("Move its %d %s first.", n_cards, if (n_cards == 1L) "card" else "cards")))
    }
  }

  ops <- list(list(op = "delete", table = data$table, uid = data$uid))
  if (identical(data$table, "cards")) {
    card_id <- as_text(row$id)
    unique_id <- !is.na(card_id) && nzchar(card_id) && sum(as_text(doc$tables$cards$id) == card_id, na.rm = TRUE) == 1L
    if (unique_id) {
      links <- doc$tables$links
      if (is.data.frame(links) && nrow(links) > 0L) {
        hit <- which(as_text(links$from) == card_id | as_text(links$to) == card_id)
        for (i in hit) {
          ops[[length(ops) + 1L]] <- list(op = "delete", table = "links", uid = links$.studio_uid[[i]])
        }
      }
      changes <- doc$tables$changes
      if (is.data.frame(changes) && nrow(changes) > 0L) {
        hit <- which(as_text(changes$card) == card_id)
        for (i in hit) {
          ops[[length(ops) + 1L]] <- list(op = "delete", table = "changes", uid = changes$.studio_uid[[i]])
        }
      }
      if (identical(as_text(doc$args$target), card_id)) {
        ops[[length(ops) + 1L]] <- list(op = "arg", name = "target", value = NULL)
      }
    }
  }

  list(
    verb = "Remove",
    text = sprintf("Remove %s %s", row_word, studio_row_label(data$table, row)),
    key = NA_character_,
    target = if (identical(data$table, "links")) NULL else list(kind = "none", uid = NULL),
    ops = ops
  )
}

# Checks and resolves a `move` event: `{table, uid, by}`.
studio_check_move <- function(data) {
  checkmate::assert_list(data, names = "unique")
  checkmate::assert_choice(data$table, c("stages", "lanes"))
  checkmate::assert_string(data$uid, min.chars = 1L)
  checkmate::assert_int(data$by)
  checkmate::assert_choice(as.integer(data$by), c(-1L, 1L))
  invisible(data)
}

studio_resolve_move <- function(doc, data) {
  studio_assert_doc(doc)
  studio_check_move(data)
  tbl <- doc$tables[[data$table]]
  idx <- if (is.null(tbl)) NA_integer_ else match(data$uid, tbl$.studio_uid)
  if (is.na(idx)) {
    return(list(refused = "That item is no longer in the map."))
  }
  by <- as.integer(data$by)
  dest <- idx + by
  row_word <- stage_map_table_words[[data$table]]$row
  if (dest < 1L) {
    return(list(refused = sprintf("That %s is already first.", row_word)))
  }
  if (dest > nrow(tbl)) {
    return(list(refused = sprintf("That %s is already last.", row_word)))
  }
  list(
    verb = "Move",
    text = sprintf("Move %s %s %s", row_word, studio_fmt_val(tbl$id[[idx]]), if (by < 0L) "up" else "down"),
    key = NA_character_,
    target = list(kind = row_word, uid = data$uid),
    ops = list(list(op = "move", table = data$table, uid = data$uid, by = by))
  )
}

# Checks and resolves a `link_add` event: `{from, to, kind}` (`from`, `to` are card uids; `kind` is id or NULL).
studio_check_link_add <- function(data) {
  checkmate::assert_list(data, names = "unique")
  checkmate::assert_string(data$from, min.chars = 1L)
  checkmate::assert_string(data$to, min.chars = 1L)
  checkmate::assert_string(data$kind, null.ok = TRUE)
  invisible(data)
}

studio_resolve_link_add <- function(doc, data) {
  studio_assert_doc(doc)
  studio_check_link_add(data)
  from_row <- studio_row(doc, "cards", data$from)
  to_row <- studio_row(doc, "cards", data$to)
  if (is.null(from_row) || is.null(to_row)) {
    return(list(refused = "One of those cards is no longer in the map."))
  }
  if (identical(data$from, data$to)) {
    return(list(refused = "A card cannot link to itself."))
  }
  from_id <- as_text(from_row$id)
  to_id <- as_text(to_row$id)
  if (is.na(from_id) || !nzchar(trimws(from_id)) || is.na(to_id) || !nzchar(trimws(to_id))) {
    return(list(refused = "Give both cards an id before linking them."))
  }
  kind_val <- if (is.null(data$kind) || !nzchar(data$kind)) NA_character_ else data$kind
  if (!is.na(kind_val)) {
    kinds <- doc$tables$kinds
    if (is.null(kinds) || !(kind_val %in% as_text(kinds$id))) {
      return(list(refused = sprintf("No link kind has the id \"%s\".", kind_val)))
    }
  }
  links <- doc$tables$links
  if (is.data.frame(links) && nrow(links) > 0L) {
    lk_kind <- if ("kind" %in% names(links)) as_text(links$kind) else rep(NA_character_, nrow(links))
    same_kind <- (is.na(lk_kind) & is.na(kind_val)) | (!is.na(lk_kind) & !is.na(kind_val) & lk_kind == kind_val)
    if (any(as_text(links$from) == from_id & as_text(links$to) == to_id & same_kind, na.rm = TRUE)) {
      return(list(refused = "That link is already in the map."))
    }
  }
  row <- list(from = from_id, to = to_id, kind = kind_val)
  list(
    verb = "Link",
    text = sprintf("Link %s -> %s", from_id, to_id),
    key = NA_character_,
    target = NULL,
    ops = list(list(op = "insert", table = "links", row = row, after = NULL))
  )
}

# Checks and resolves a `link_reverse` event: `{uid}`.
studio_check_link_reverse <- function(data) {
  checkmate::assert_list(data, names = "unique")
  checkmate::assert_string(data$uid, min.chars = 1L)
  invisible(data)
}

studio_resolve_link_reverse <- function(doc, data) {
  studio_assert_doc(doc)
  studio_check_link_reverse(data)
  row <- studio_row(doc, "links", data$uid)
  if (is.null(row)) {
    return(list(refused = "That link is no longer in the map."))
  }
  list(
    verb = "Reverse",
    text = sprintf("Reverse link %s -> %s", studio_fmt_val(row$from), studio_fmt_val(row$to)),
    key = NA_character_,
    target = NULL,
    ops = list(
      list(op = "set", table = "links", uid = data$uid, field = "from", value = row$to),
      list(op = "set", table = "links", uid = data$uid, field = "to", value = row$from)
    )
  )
}

# Checks and resolves a `fix` event: `{fault, fix}`.
studio_check_fix <- function(data) {
  checkmate::assert_list(data, names = "unique")
  checkmate::assert_string(data$fault, min.chars = 1L)
  checkmate::assert_string(data$fix, min.chars = 1L)
  invisible(data)
}

studio_resolve_fix <- function(doc, data) {
  studio_assert_doc(doc)
  studio_check_fix(data)
  faults <- studio_faults(doc)
  idx <- match(data$fault, faults$id)
  if (is.na(idx)) {
    return(list(refused = "That problem is gone."))
  }
  fixes <- studio_fixes(doc, faults[idx, , drop = FALSE])
  chosen <- fixes[[data$fix]]
  if (is.null(chosen)) {
    return(list(refused = "That problem is gone."))
  }
  list(
    verb = "Fix",
    text = chosen$text,
    key = NA_character_,
    target = chosen$target,
    ops = chosen$ops
  )
}

# Registry of document-changing events.
studio_events <- list(
  edit = list(check = studio_check_edit, resolve = studio_resolve_edit),
  option = list(check = studio_check_option, resolve = studio_resolve_option),
  add = list(check = studio_check_add, resolve = studio_resolve_add),
  remove = list(check = studio_check_remove, resolve = studio_resolve_remove),
  move = list(check = studio_check_move, resolve = studio_resolve_move),
  link_add = list(check = studio_check_link_add, resolve = studio_resolve_link_add),
  link_reverse = list(check = studio_check_link_reverse, resolve = studio_resolve_link_reverse),
  fix = list(check = studio_check_fix, resolve = studio_resolve_fix)
)

# Validates and resolves one document-changing event `event` (`list(type, data, ...)`).
studio_resolve <- function(doc, event) {
  studio_assert_doc(doc)
  checkmate::assert_list(event, names = "unique")
  checkmate::assert_choice(event$type, names(studio_events))
  checkmate::assert_list(event$data)
  spec <- studio_events[[event$type]]
  spec$check(event$data)
  spec$resolve(doc, event$data)
}
