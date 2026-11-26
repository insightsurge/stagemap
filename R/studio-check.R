# Building and checking a studio document: studio_try() runs R expressions and captures errors and warnings;
# studio_build() runs stage_map() and its layers; studio_faults() locates blank, duplicate and broken-join cells;
# studio_fixes() offers fixes as changes.

# Evaluates `expr` once, muffling warnings and capturing any error into `list(ok, value, error, warnings)`.
studio_try <- function(expr) {
  acc <- new.env(parent = emptyenv())
  acc$warnings <- character()
  acc$err <- NULL
  value <- withCallingHandlers(
    tryCatch(
      expr,
      error = function(e) {
        acc$err <- e
        NULL
      }
    ),
    warning = function(w) {
      msg <- cli::ansi_strip(conditionMessage(w))
      acc$warnings <- c(acc$warnings, sub("\n$", "", msg))
      invokeRestart("muffleWarning")
    }
  )
  if (is.null(acc$err)) {
    return(list(ok = TRUE, value = value, error = NULL, warnings = acc$warnings))
  }
  err <- acc$err
  full <- cli::ansi_strip(conditionMessage(err))
  head <- if (nzchar(full)) strsplit(full, "\n", fixed = TRUE)[[1L]][[1L]] else ""
  lines <- if (length(err$problems) > 0L) {
    lapply(err$problems, function(p) list(mark = "x", text = cli::ansi_strip(p)))
  } else if (length(err$body) > 0L) {
    marks <- names(err$body)
    if (is.null(marks)) {
      marks <- rep("x", length(err$body))
    }
    lapply(seq_along(err$body), function(i) {
      mark <- if (nzchar(marks[[i]])) marks[[i]] else "x"
      list(mark = mark, text = cli::ansi_strip(unname(err$body[[i]])))
    })
  } else {
    list()
  }
  list(
    ok = FALSE,
    value = NULL,
    error = list(class = class(err), head = head, lines = lines),
    warnings = acc$warnings
  )
}

# Builds `doc` through stage_map() and the package's layer functions inside studio_try().
studio_build <- function(doc) {
  studio_assert_doc(doc)
  parts <- studio_doc_parts(doc)
  tables <- parts$tables
  args <- parts$args
  has <- function(name) is.data.frame(tables[[name]]) && nrow(tables[[name]]) > 0L

  map_formals <- setdiff(names(formals(stage_map)), c("cards", "stages", "lanes", "..."))
  opt_args <- drop_nulls(args[intersect(map_formals, names(args))])
  if (has("statuses")) {
    opt_args$statuses <- tables$statuses
  }
  map_args <- c(
    list(cards = tables$cards),
    if (!is.null(tables$stages)) list(stages = tables$stages),
    if (!is.null(tables$lanes)) list(lanes = tables$lanes),
    opt_args
  )

  studio_try({
    map <- do.call(stage_map, map_args)
    if (has("links")) {
      links_args <- drop_nulls(list(map, links = tables$links, kinds = if (has("kinds")) tables$kinds))
      map <- do.call(add_links, links_args)
    }
    if (has("zones")) {
      map <- do.call(add_zones, list(map, zones = tables$zones))
    }
    if (has("steps")) {
      steps_args <- drop_nulls(list(
        map,
        steps = tables$steps,
        changes = if (has("changes")) tables$changes,
        intro = args$intro
      ))
      map <- do.call(add_steps, steps_args)
    }
    if (has("variants")) {
      map <- do.call(add_variants, list(map, variants = tables$variants))
    }
    if (!is.null(args$highlight) && length(args$highlight$ids) > 0L) {
      hl_args <- drop_nulls(list(map, ids = args$highlight$ids, links = args$highlight$links))
      map <- do.call(stage_map_highlight, hl_args)
    }
    map
  })
}

# Constructs a zero-row or populated faults data frame with fixed column types.
studio_faults_df <- function(rows = list()) {
  checkmate::assert_list(rows)
  if (length(rows) == 0L) {
    return(data.frame(
      id = character(),
      table = character(),
      uid = character(),
      field = character(),
      type = character(),
      value = character(),
      to = character(),
      text = character(),
      stringsAsFactors = FALSE
    ))
  }
  out <- do.call(rbind, lapply(rows, as.data.frame, stringsAsFactors = FALSE))
  rownames(out) <- NULL
  out
}

# Locates cells at fault in `doc`: `blank` (missing/blank required `id` or `label`), `duplicate` (repeated `id` in
# a table of `stage_map_table_words`), and `join` (unmatched id along `stage_map_joins`, treating `kinds` as the
# package checks it).
studio_faults <- function(doc) {
  studio_assert_doc(doc)
  tables <- doc$tables
  spec_fields <- sm_spec()$fields
  acc <- new.env(parent = emptyenv())
  acc$rows <- list()

  add_fault <- function(table, uid, field, type, value, to, text) {
    n <- length(acc$rows) + 1L
    acc$rows[[n]] <- list(
      id = paste(table, uid, field, type, sep = ":"),
      table = table,
      uid = uid,
      field = field,
      type = type,
      value = if (is.null(value) || is.na(value)) NA_character_ else as.character(value),
      to = if (is.null(to) || is.na(to)) NA_character_ else as.character(to),
      text = text
    )
  }

  for (name in names(tables)) {
    tbl <- tables[[name]]
    tbl_spec <- spec_fields[[name]]$fields
    if (!is.data.frame(tbl) || nrow(tbl) == 0L || is.null(tbl_spec)) {
      next
    }
    row_word <- if (!is.null(stage_map_table_words[[name]])) stage_map_table_words[[name]]$row else name
    for (field in intersect(c("id", "label"), names(tbl_spec))) {
      if (!isTRUE(tbl_spec[[field]]$required) || !(field %in% names(tbl))) {
        next
      }
      vals <- as_text(tbl[[field]])
      bad <- is.na(vals) | !nzchar(trimws(vals))
      for (i in which(bad)) {
        article <- if (identical(field, "id")) "an" else "a"
        add_fault(
          name,
          tbl$.studio_uid[[i]],
          field,
          "blank",
          vals[[i]],
          NA_character_,
          sprintf(
            "This %s needs %s %s.",
            row_word,
            article,
            field
          )
        )
      }
    }
  }

  for (name in intersect(names(stage_map_table_words), names(tables))) {
    tbl <- tables[[name]]
    if (!is.data.frame(tbl) || nrow(tbl) == 0L || !("id" %in% names(tbl))) {
      next
    }
    ids <- as_text(tbl$id)
    non_blank <- !is.na(ids) & nzchar(trimws(ids))
    counts <- table(ids[non_blank])
    dups <- names(counts)[counts > 1L]
    if (length(dups) > 0L) {
      row_word <- stage_map_table_words[[name]]$row
      for (i in which(non_blank & ids %in% dups)) {
        add_fault(
          name,
          tbl$.studio_uid[[i]],
          "id",
          "duplicate",
          ids[[i]],
          NA_character_,
          sprintf(
            "Another %s also has the id \"%s\".",
            row_word,
            ids[[i]]
          )
        )
      }
    }
  }

  for (join in stage_map_joins) {
    tbl <- tables[[join$table]]
    if (!is.data.frame(tbl) || nrow(tbl) == 0L || !(join$column %in% names(tbl))) {
      next
    }
    to <- join$to
    target_tbl <- tables[[to]]
    if (!is.data.frame(target_tbl)) {
      if (!identical(to, "kinds")) {
        next
      }
      target_ids <- character()
    } else {
      target_ids <- as_text(target_tbl$id)
    }
    to_word <- stage_map_table_words[[to]]$row
    vals <- as_text(tbl[[join$column]])
    for (i in seq_len(nrow(tbl))) {
      v <- vals[[i]]
      if (is.na(v)) {
        next
      }
      if (isTRUE(join$split)) {
        parts <- trimws(strsplit(v, ",", fixed = TRUE)[[1L]])
        parts <- parts[nzchar(parts)]
        bad <- setdiff(parts, target_ids)
        if (length(bad) > 0L) {
          add_fault(
            join$table,
            tbl$.studio_uid[[i]],
            join$column,
            "join",
            bad[[1L]],
            to,
            sprintf(
              "No %s has the id \"%s\".",
              to_word,
              bad[[1L]]
            )
          )
        }
      } else if (!(v %in% target_ids)) {
        add_fault(
          join$table,
          tbl$.studio_uid[[i]],
          join$column,
          "join",
          v,
          to,
          sprintf(
            "No %s has the id \"%s\".",
            to_word,
            v
          )
        )
      }
    }
  }

  studio_faults_df(acc$rows)
}

# Offers fixes (`free`, `use`, `add`, `remove`) for a single fault (1-row data frame or named list), each as a change
# with a `label`.
studio_fixes <- function(doc, fault) {
  studio_assert_doc(doc)
  checkmate::assert(
    checkmate::check_data_frame(fault, nrows = 1L),
    checkmate::check_list(fault, names = "unique"),
    .var.name = "fault"
  )
  if (is.data.frame(fault)) {
    fault <- as.list(fault[1L, , drop = FALSE])
  }
  checkmate::assert_names(names(fault), must.include = c("table", "uid", "field", "type", "value", "to"))

  fixes <- list()
  if (
    fault$type %in%
      c("blank", "duplicate") &&
      identical(fault$field, "id") &&
      (fault$table %in% names(stage_map_table_words))
  ) {
    new_id <- studio_free_id(doc, fault$table)
    row_word <- stage_map_table_words[[fault$table]]$row
    fixes$free <- list(
      label = sprintf("Use \"%s\"", new_id),
      verb = "Fix",
      text = sprintf("Set %s id to %s", row_word, new_id),
      key = NA_character_,
      target = NULL,
      ops = list(list(op = "set", table = fault$table, uid = fault$uid, field = "id", value = new_id))
    )
  }

  if (identical(fault$type, "join") && !is.na(fault$to)) {
    target_tbl <- doc$tables[[fault$to]]
    to_word <- stage_map_table_words[[fault$to]]$row
    if (is.data.frame(target_tbl) && nrow(target_tbl) > 0L && !is.na(fault$value)) {
      candidates <- unique(as_text(target_tbl$id))
      candidates <- candidates[!is.na(candidates) & nzchar(trimws(candidates))]
      if (length(candidates) > 0L) {
        dists <- as.numeric(utils::adist(fault$value, candidates)[1L, ])
        best_idx <- which.min(dists)
        if (dists[[best_idx]] <= 2) {
          best <- candidates[[best_idx]]
          tbl <- doc$tables[[fault$table]]
          idx <- match(fault$uid, tbl$.studio_uid)
          new_val <- best
          if (identical(fault$field, "variants") && !is.na(idx)) {
            parts <- trimws(strsplit(as_text(tbl[[fault$field]][[idx]]), ",", fixed = TRUE)[[1L]])
            parts[parts == fault$value] <- best
            new_val <- paste(parts, collapse = ", ")
          }
          fixes$use <- list(
            label = sprintf("Use \"%s\"", best),
            verb = "Fix",
            text = sprintf("Use %s \"%s\"", to_word, best),
            key = NA_character_,
            target = NULL,
            ops = list(list(op = "set", table = fault$table, uid = fault$uid, field = fault$field, value = new_val))
          )
        }
      }
    }

    if (fault$to %in% c("stages", "lanes") && !is.na(fault$value) && nzchar(trimws(fault$value))) {
      lbl <- sprintf("Add %s \"%s\"", to_word, fault$value)
      fixes$add <- list(
        label = lbl,
        verb = "Fix",
        text = lbl,
        key = NA_character_,
        target = NULL,
        ops = list(list(
          op = "insert",
          table = fault$to,
          row = list(id = fault$value, label = fault$value),
          after = NULL
        ))
      )
    }

    if (identical(fault$table, "links")) {
      fixes$remove <- list(
        label = "Remove link",
        verb = "Fix",
        text = "Remove broken link",
        key = NA_character_,
        target = NULL,
        ops = list(list(op = "delete", table = "links", uid = fault$uid))
      )
    }
  }

  fixes
}
