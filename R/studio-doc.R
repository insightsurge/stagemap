# The studio document: tables keyed by `.studio_uid` ("u1", "u2", ...), stage_map() arguments, and the five
# primitive operations. Operations do no cascading: resolve produces every operation a change needs, and replay
# applies them deterministically from base.

# Columns whose values are compared as text ids in the package.
studio_id_columns <- c("id", "stage", "lane", "zone", "status", "from", "to", "kind", "step", "card")

# Checks that `doc` has the structure of a studio document.
studio_assert_doc <- function(doc, name = "doc") {
  checkmate::assert_string(name, min.chars = 1L)
  checkmate::assert_list(doc, names = "unique", .var.name = name)
  checkmate::assert_names(
    names(doc),
    must.include = c("tables", "args", "next_uid"),
    .var.name = paste0("names(", name, ")")
  )
  checkmate::assert_list(doc$tables, types = "data.frame", names = "unique", .var.name = paste0(name, "$tables"))
  checkmate::assert_list(doc$args, names = "unique", .var.name = paste0(name, "$args"))
  checkmate::assert_count(doc$next_uid, positive = TRUE, .var.name = paste0(name, "$next_uid"))
  invisible(doc)
}

# Builds a studio document from `parts` (`list(tables, args)` as map_parts() returns it): assigns `.studio_uid`
# in `map_table_names` order starting from `next_uid`, converts id columns with `as_text()` and `stages$date` to `Date`.
studio_doc <- function(parts, next_uid = 1L) {
  checkmate::assert_list(parts, names = "unique")
  checkmate::assert_names(names(parts), must.include = c("tables", "args"))
  checkmate::assert_list(parts$tables, types = "data.frame", names = "unique")
  checkmate::assert_subset(names(parts$tables), map_table_names)
  checkmate::assert_list(parts$args, names = "unique")
  checkmate::assert_count(next_uid, positive = TRUE)

  tables <- list()
  for (name in intersect(map_table_names, names(parts$tables))) {
    tbl <- parts$tables[[name]]
    if (".studio_uid" %in% names(tbl)) {
      sm_abort(
        "Table {.field {name}} already has a {.field .studio_uid} column.",
        class = "stagemap_error_studio"
      )
    }
    n <- nrow(tbl)
    uids <- if (n == 0L) character() else paste0("u", seq.int(next_uid, length.out = n))
    next_uid <- next_uid + n
    for (col in intersect(studio_id_columns, names(tbl))) {
      tbl[[col]] <- as_text(tbl[[col]])
    }
    if (identical(name, "stages") && "date" %in% names(tbl)) {
      tbl$date <- if (inherits(tbl$date, "Date")) tbl$date else as.Date(as_text(tbl$date))
    }
    tbl$.studio_uid <- uids
    rownames(tbl) <- NULL
    tables[[name]] <- tbl
  }

  list(tables = tables, args = parts$args, next_uid = next_uid)
}

# The document's tables without the internal `.studio_uid` column.
studio_doc_tables <- function(doc) {
  studio_assert_doc(doc)
  lapply(doc$tables, function(tbl) {
    out <- tbl[names(tbl) != ".studio_uid"]
    rownames(out) <- NULL
    out
  })
}

# The document as `list(tables, args)`, the shape map_parts() returns and code_map() takes.
studio_doc_parts <- function(doc) {
  studio_assert_doc(doc)
  list(tables = studio_doc_tables(doc), args = doc$args)
}

# The row with `.studio_uid == uid` in `table`, as a 1-row data frame, or NULL when absent.
studio_row <- function(doc, table, uid) {
  studio_assert_doc(doc)
  checkmate::assert_string(table, min.chars = 1L)
  checkmate::assert_string(uid, min.chars = 1L)
  tbl <- doc$tables[[table]]
  if (is.null(tbl)) {
    return(NULL)
  }
  idx <- match(uid, tbl$.studio_uid)
  if (is.na(idx)) {
    return(NULL)
  }
  tbl[idx, , drop = FALSE]
}

# The `.studio_uid` of the first row in `table` whose `id` equals `id`, or NULL when absent.
studio_uid_of <- function(doc, table, id) {
  studio_assert_doc(doc)
  checkmate::assert_string(table, min.chars = 1L)
  checkmate::assert_string(id, min.chars = 1L)
  tbl <- doc$tables[[table]]
  if (is.null(tbl) || !("id" %in% names(tbl))) {
    return(NULL)
  }
  idx <- match(id, as_text(tbl$id))
  if (is.na(idx)) NULL else tbl$.studio_uid[[idx]]
}

# A free id for `table` (`card`, `card-2`, ...; `stage`, `lane` likewise).
studio_free_id <- function(doc, table) {
  studio_assert_doc(doc)
  checkmate::assert_choice(table, names(stage_map_table_words))
  base <- stage_map_table_words[[table]]$row
  tbl <- doc$tables[[table]]
  used <- if (is.null(tbl) || !("id" %in% names(tbl))) character() else as_text(tbl$id)
  used <- used[!is.na(used)]
  if (!(base %in% used)) {
    return(base)
  }
  k <- 2L
  repeat {
    candidate <- paste0(base, "-", k)
    if (!(candidate %in% used)) {
      return(candidate)
    }
    k <- k + 1L
  }
}

# The contract type of column `field` in `table`, or NULL if not in the contract.
studio_field_spec <- function(table, field) {
  checkmate::assert_string(table, min.chars = 1L)
  checkmate::assert_string(field, min.chars = 1L)
  tbl_spec <- sm_spec()$fields[[table]]
  if (is.null(tbl_spec)) NULL else tbl_spec$fields[[field]]
}

# Typed NA of length `n` for contract type `type`.
studio_typed_na <- function(type, n = 1L) {
  checkmate::assert_string(type, null.ok = TRUE)
  checkmate::assert_count(n)
  if (identical(type, "boolean")) {
    return(rep(NA, n))
  }
  if (identical(type, "date")) {
    return(as.Date(rep(NA_character_, n)))
  }
  rep(NA_character_, n)
}

# Coerces `value` to match the contract type of `table$field`; NULL or "" becomes typed NA.
studio_coerce_cell <- function(table, field, value) {
  checkmate::assert_string(table, min.chars = 1L)
  checkmate::assert_string(field, min.chars = 1L)
  spec <- studio_field_spec(table, field)
  type <- if (is.null(spec)) NULL else spec$type
  is_empty <- is.null(value) ||
    (is.character(value) && length(value) == 1L && !nzchar(value)) ||
    (is.atomic(value) && length(value) == 1L && is.na(value))
  if (is_empty) {
    return(studio_typed_na(type, 1L))
  }
  if (is.null(type)) {
    return(value)
  }
  switch(
    type,
    id = ,
    string = ,
    markdown = ,
    scalar = ,
    icon = {
      if (!is.character(value) && !is.factor(value) && !is.numeric(value)) {
        sm_abort("Field {.field {table}${field}} needs text.", class = "stagemap_error_studio")
      }
      as_text(value)[[1L]]
    },
    enum = {
      text <- as.character(value)[[1L]]
      if (!(text %in% spec$values)) {
        sm_abort(
          "Value {.val {text}} is not allowed for {.field {table}${field}}.",
          class = "stagemap_error_studio"
        )
      }
      text
    },
    boolean = {
      if (!checkmate::test_flag(value)) {
        sm_abort("Field {.field {table}${field}} needs TRUE or FALSE.", class = "stagemap_error_studio")
      }
      as.logical(value)
    },
    date = {
      if (inherits(value, "Date") && length(value) == 1L) {
        return(value)
      }
      if (!is.character(value) || length(value) != 1L || !grepl(date_pattern, value)) {
        sm_abort("Field {.field {table}${field}} needs a date like YYYY-MM-DD.", class = "stagemap_error_studio")
      }
      parsed <- as.Date(value, format = "%Y-%m-%d")
      if (is.na(parsed)) {
        sm_abort("Field {.field {table}${field}} is not a valid calendar date.", class = "stagemap_error_studio")
      }
      parsed
    },
    as_text(value)[[1L]]
  )
}

# Sets cell `[idx, field]` of `tbl` (in `table`) to coerced `value`, adding or widening the column if needed.
studio_set_cell <- function(tbl, table, idx, field, value) {
  checkmate::assert_data_frame(tbl)
  checkmate::assert_string(table, min.chars = 1L)
  checkmate::assert_count(idx, positive = TRUE)
  checkmate::assert_string(field, min.chars = 1L)
  if (identical(field, ".studio_uid")) {
    sm_abort("Cannot overwrite {.field .studio_uid}.", class = "stagemap_error_studio")
  }
  coerced <- studio_coerce_cell(table, field, value)
  spec <- studio_field_spec(table, field)
  if (!(field %in% names(tbl))) {
    tbl[[field]] <- studio_typed_na(if (is.null(spec)) NULL else spec$type, nrow(tbl))
  } else if (is.factor(tbl[[field]])) {
    tbl[[field]] <- as.character(tbl[[field]])
  } else if (is.numeric(tbl[[field]]) && is.character(coerced)) {
    tbl[[field]] <- as_text(tbl[[field]])
  } else if (identical(spec$type, "date") && !inherits(tbl[[field]], "Date")) {
    tbl[[field]] <- as.Date(as_text(tbl[[field]]))
  }
  tbl[[field]][[idx]] <- coerced
  tbl
}

# Applies a list of primitive operations (`set`, `insert`, `delete`, `move`, `arg`) to `doc`.
studio_doc_apply <- function(doc, ops) {
  studio_assert_doc(doc)
  checkmate::assert_list(ops)
  for (op in ops) {
    checkmate::assert_list(op, names = "unique")
    kind <- op$op
    checkmate::assert_choice(kind, c("set", "insert", "delete", "move", "arg"))
    doc <- switch(
      kind,
      set = studio_op_set(doc, op),
      insert = studio_op_insert(doc, op),
      delete = studio_op_delete(doc, op),
      move = studio_op_move(doc, op),
      arg = studio_op_arg(doc, op)
    )
  }
  doc
}

# Applies a `set` operation (`table`, `uid`, `field`, `value`).
studio_op_set <- function(doc, op) {
  studio_assert_doc(doc)
  checkmate::assert_list(op, names = "unique")
  checkmate::assert_string(op$table, min.chars = 1L)
  checkmate::assert_string(op$uid, min.chars = 1L)
  checkmate::assert_string(op$field, min.chars = 1L)
  tbl <- doc$tables[[op$table]]
  if (is.null(tbl)) {
    sm_abort("Table {.field {op$table}} is not in the document.", class = "stagemap_error_studio")
  }
  idx <- match(op$uid, tbl$.studio_uid)
  if (is.na(idx)) {
    sm_abort("Row {.val {op$uid}} is gone from {.field {op$table}}.", class = "stagemap_error_studio")
  }
  doc$tables[[op$table]] <- studio_set_cell(tbl, op$table, idx, op$field, op$value)
  doc
}

# Applies an `insert` operation (`table`, `row`, `after`, optional `uid`).
studio_op_insert <- function(doc, op) {
  studio_assert_doc(doc)
  checkmate::assert_list(op, names = "unique")
  checkmate::assert_choice(op$table, map_table_names)
  checkmate::assert_list(op$row, names = "unique")
  checkmate::assert_string(op$after, min.chars = 1L, null.ok = TRUE)
  checkmate::assert_string(op$uid, min.chars = 1L, null.ok = TRUE)

  if (!is.null(op$uid)) {
    uid <- op$uid
    num <- suppressWarnings(as.integer(sub("^u", "", uid)))
    if (!is.na(num) && num >= doc$next_uid) {
      doc$next_uid <- num + 1L
    }
  } else {
    uid <- paste0("u", doc$next_uid)
    doc$next_uid <- doc$next_uid + 1L
  }
  row_fields <- setdiff(names(op$row), ".studio_uid")
  tbl <- doc$tables[[op$table]]

  if (is.null(tbl)) {
    if (!is.null(op$after)) {
      sm_abort("Row {.val {op$after}} is gone from {.field {op$table}}.", class = "stagemap_error_studio")
    }
    cols <- list()
    for (col in row_fields) {
      cols[[col]] <- studio_coerce_cell(op$table, col, op$row[[col]])
    }
    cols$.studio_uid <- uid
    tbl <- as.data.frame(cols, stringsAsFactors = FALSE, check.names = FALSE)
    rownames(tbl) <- NULL
    doc$tables[[op$table]] <- tbl
    doc$tables <- doc$tables[intersect(map_table_names, names(doc$tables))]
    return(doc)
  }

  at <- if (is.null(op$after)) nrow(tbl) else match(op$after, tbl$.studio_uid)
  if (is.na(at)) {
    sm_abort("Row {.val {op$after}} is gone from {.field {op$table}}.", class = "stagemap_error_studio")
  }

  for (col in row_fields) {
    if (!(col %in% names(tbl))) {
      spec <- studio_field_spec(op$table, col)
      tbl[[col]] <- studio_typed_na(if (is.null(spec)) NULL else spec$type, nrow(tbl))
    }
  }
  new_row <- list()
  for (col in names(tbl)) {
    if (identical(col, ".studio_uid")) {
      new_row[[col]] <- uid
    } else if (col %in% row_fields) {
      new_row[[col]] <- studio_coerce_cell(op$table, col, op$row[[col]])
      if (is.factor(tbl[[col]])) {
        tbl[[col]] <- as.character(tbl[[col]])
      } else if (is.numeric(tbl[[col]]) && is.character(new_row[[col]])) {
        tbl[[col]] <- as_text(tbl[[col]])
      } else if (inherits(new_row[[col]], "Date") && !inherits(tbl[[col]], "Date")) {
        tbl[[col]] <- as.Date(as_text(tbl[[col]]))
      }
    } else {
      spec <- studio_field_spec(op$table, col)
      if (is.factor(tbl[[col]])) {
        tbl[[col]] <- as.character(tbl[[col]])
      }
      new_row[[col]] <- if (inherits(tbl[[col]], "Date")) {
        as.Date(NA_character_)
      } else if (is.logical(tbl[[col]])) {
        NA
      } else if (is.integer(tbl[[col]])) {
        NA_integer_
      } else if (is.numeric(tbl[[col]])) {
        NA_real_
      } else {
        studio_typed_na(if (is.null(spec)) NULL else spec$type, 1L)
      }
    }
  }
  new_df <- as.data.frame(new_row, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(tbl) == 0L) {
    tbl <- new_df
  } else if (at == nrow(tbl)) {
    tbl <- rbind(tbl, new_df)
  } else {
    tbl <- rbind(tbl[seq_len(at), , drop = FALSE], new_df, tbl[seq(at + 1L, nrow(tbl)), , drop = FALSE])
  }
  rownames(tbl) <- NULL
  doc$tables[[op$table]] <- tbl
  doc
}

# Applies a `delete` operation (`table`, `uid`).
studio_op_delete <- function(doc, op) {
  studio_assert_doc(doc)
  checkmate::assert_list(op, names = "unique")
  checkmate::assert_string(op$table, min.chars = 1L)
  checkmate::assert_string(op$uid, min.chars = 1L)
  tbl <- doc$tables[[op$table]]
  if (is.null(tbl)) {
    sm_abort("Table {.field {op$table}} is not in the document.", class = "stagemap_error_studio")
  }
  idx <- match(op$uid, tbl$.studio_uid)
  if (is.na(idx)) {
    sm_abort("Row {.val {op$uid}} is gone from {.field {op$table}}.", class = "stagemap_error_studio")
  }
  tbl <- tbl[-idx, , drop = FALSE]
  rownames(tbl) <- NULL
  doc$tables[[op$table]] <- tbl
  doc
}

# Applies a `move` operation (`table`, `uid`, `by` in `c(-1, 1)`).
studio_op_move <- function(doc, op) {
  studio_assert_doc(doc)
  checkmate::assert_list(op, names = "unique")
  checkmate::assert_string(op$table, min.chars = 1L)
  checkmate::assert_string(op$uid, min.chars = 1L)
  checkmate::assert_int(op$by)
  checkmate::assert_choice(as.integer(op$by), c(-1L, 1L))
  tbl <- doc$tables[[op$table]]
  if (is.null(tbl)) {
    sm_abort("Table {.field {op$table}} is not in the document.", class = "stagemap_error_studio")
  }
  idx <- match(op$uid, tbl$.studio_uid)
  if (is.na(idx)) {
    sm_abort("Row {.val {op$uid}} is gone from {.field {op$table}}.", class = "stagemap_error_studio")
  }
  dest <- idx + as.integer(op$by)
  if (dest < 1L || dest > nrow(tbl)) {
    sm_abort("Cannot move row {.val {op$uid}} past the end of {.field {op$table}}.", class = "stagemap_error_studio")
  }
  order_idx <- seq_len(nrow(tbl))
  order_idx[c(idx, dest)] <- c(dest, idx)
  tbl <- tbl[order_idx, , drop = FALSE]
  rownames(tbl) <- NULL
  doc$tables[[op$table]] <- tbl
  doc
}

# Applies an `arg` operation (`name`, `value`).
studio_op_arg <- function(doc, op) {
  studio_assert_doc(doc)
  checkmate::assert_list(op, names = "unique")
  checkmate::assert_choice(op$name, names(doc$args))
  doc$args[op$name] <- list(op$value)
  doc
}
