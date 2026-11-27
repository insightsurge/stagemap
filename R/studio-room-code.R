# R code room: generates the `code` section view, the code lines (with the last Ask call when current), the `.R`
# download text, and per-table CSV text without `.studio_uid`.

studio_code_problem_text <- "stage_map() stops on this map: see Check."

# The code lines for `state$doc` (`doc`), and the lines shown (`lines`): `doc` plus, when an active non-error question
# exists for the current revision, `map <-` before the `stage_map(` line and the `# The last question` block with
# `state$ask$call`. The question lines come after the document's own lines, so `lines[seq_along(doc)]` lines up
# with `doc`.
studio_code_parts <- function(state) {
  checkmate::assert_list(state, names = "unique")
  studio_assert_doc(state$doc, "state$doc")
  doc <- code_map(studio_doc_parts(state$doc))
  lines <- doc
  ask <- state$ask
  has_call <- !is.null(ask) &&
    is.null(ask$error) &&
    !isTRUE(ask$stale) &&
    (is.null(ask$rev) || identical(ask$rev, state$rev)) &&
    is.character(ask$call) &&
    length(ask$call) >= 1L
  call_lines <- if (has_call) unlist(strsplit(ask$call, "\n", fixed = TRUE), use.names = FALSE) else character()
  if (length(call_lines) > 0L && any(nzchar(trimws(call_lines)))) {
    idx <- which(startsWith(lines, "stage_map("))
    if (length(idx) > 0L) {
      lines[[idx[[1L]]]] <- paste0("map <- ", lines[[idx[[1L]]]])
    }
    lines <- c(lines, "", "# The last question", call_lines)
  }
  list(doc = doc, lines = lines)
}

# Returns the R code lines for `state$doc`, plus `map <-` and `# The last question` with `state$ask$call` when an
# active non-error question exists for the current revision.
studio_code_lines <- function(state) {
  studio_code_parts(state)$lines
}

# Builds the code lines for copying or downloading, prepending the problem comment when `state$check$ok` is not TRUE.
studio_code_export_lines <- function(state) {
  lines <- studio_code_lines(state)
  if (isTRUE(state$check$ok)) {
    return(lines)
  }
  c(paste0("# ", studio_code_problem_text), lines)
}

# The text of the `.R` download for `state`, ending with a newline.
studio_code_file <- function(state) {
  checkmate::assert_list(state, names = "unique")
  studio_assert_doc(state$doc, "state$doc")
  paste0(paste(studio_code_export_lines(state), collapse = "\n"), "\n")
}

# The text of one table `table` in `state$doc` as CSV (no `.studio_uid` column); a table the document lacks gives a
# header line only.
studio_csv <- function(state, table) {
  checkmate::assert_list(state, names = "unique")
  studio_assert_doc(state$doc, "state$doc")
  checkmate::assert_choice(table, map_table_names)
  tbl <- studio_doc_tables(state$doc)[[table]]
  if (is.null(tbl)) {
    cols <- names(sm_spec()$fields[[table]]$fields)
    tbl <- stats::setNames(
      as.data.frame(rep(list(character()), length(cols)), stringsAsFactors = FALSE),
      cols
    )
  } else {
    for (col in names(tbl)) {
      if (is.list(tbl[[col]])) {
        tbl[[col]] <- vapply(tbl[[col]], function(el) paste(as.character(el), collapse = ", "), "")
      }
    }
  }
  studio_csv_text(tbl)
}

# `tbl` as CSV text, built by hand in UTF-8 so that non-ASCII text survives in any locale (write.csv() would turn it
# into `<U+00E9>` escapes in a C locale). Text and the header are quoted with doubled quotes, numbers and logicals are
# bare, and NA is bare.
studio_csv_text <- function(tbl) {
  swap <- function(x) gsub("\"", "\"\"", x, fixed = TRUE, useBytes = TRUE)
  field <- function(x) {
    missing <- is.na(x)
    if (is.character(x) || is.factor(x)) {
      out <- paste0("\"", swap(enc2utf8(as.character(x))), "\"")
    } else {
      out <- as.character(x)
    }
    out[missing] <- "NA"
    out
  }
  cols <- lapply(tbl, field)
  header <- paste0("\"", swap(enc2utf8(names(tbl))), "\"")
  rows <- if (nrow(tbl) > 0L) do.call(paste, c(unname(cols), sep = ",")) else character()
  out <- paste0(paste(c(paste(header, collapse = ","), rows), collapse = "\n"), "\n")
  Encoding(out) <- "UTF-8"
  out
}

# The last view built by studio_room_code_view() and the inputs it was built from.
studio_code_view_last <- new.env(parent = emptyenv())

# The `code` section of the studio view: tokenised lines marked against `state$base`, copy text, problem note, and
# download descriptors for the `.R` script and each table the document has.
studio_room_code_view <- function(state) {
  checkmate::assert_list(state, names = "unique")
  studio_assert_doc(state$doc, "state$doc")
  studio_assert_doc(state$base, "state$base")
  # The view is built on every store change, such as a pick of a card, and a large map takes long to tokenise: the
  # last view is kept and reused while nothing it reads has changed.
  key <- list(state$doc, state$base, state$base_code, state$ask, state$rev, isTRUE(state$check$ok))
  if (identical(studio_code_view_last$key, key)) {
    return(studio_code_view_last$view)
  }
  view <- studio_room_code_view_build(state)
  studio_code_view_last$key <- key
  studio_code_view_last$view <- view
  view
}

# The `code` section of `state`, built from scratch.
studio_room_code_view_build <- function(state) {
  parts <- studio_code_parts(state)
  lines <- parts$lines
  base_lines <- state$base_code
  # Only the document's own lines can be changed: the question lines and the `map <-` prefix were not edited.
  changed <- c(!(parts$doc %in% base_lines), rep(FALSE, length(lines) - length(parts$doc)))
  tokens <- code_tokens(lines)
  line_items <- lapply(seq_along(lines), function(i) {
    spans <- lapply(tokens[[i]], function(tok) list(tok$text, tok$class))
    list(spans = spans, changed = changed[[i]])
  })
  problem <- if (isTRUE(state$check$ok)) NULL else studio_code_problem_text
  export_lines <- if (is.null(problem)) lines else c(paste0("# ", problem), lines)
  tbl_names <- intersect(map_table_names, names(state$doc$tables))
  downloads <- c(
    list(list(id = "download_r", label = "map.R")),
    lapply(tbl_names, function(tbl) {
      list(id = paste0("download_csv_", tbl), label = paste0(tbl, ".csv"))
    })
  )
  list(
    lines = line_items,
    text = paste(export_lines, collapse = "\n"),
    problem = problem,
    downloads = downloads
  )
}
