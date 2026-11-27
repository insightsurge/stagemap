# The studio journal: records changes, joins consecutive edits of one cell (dropping the entry when the cell
# returns to its first value), marks undo, and replays done entries from `base`.

# Identifier for an operation's target cell or option, used when merging consecutive edits with the same key.
studio_op_target <- function(op) {
  checkmate::assert_list(op, names = "unique")
  if (identical(op$op, "arg")) {
    paste("arg", op$name, sep = ":")
  } else {
    paste(op$op, op$table, op$uid, op$field, sep = ":")
  }
}

# Merges `old_ops` and `new_ops`: for any target present in `new_ops`, the new operation replaces the old one.
studio_merge_ops <- function(old_ops, new_ops) {
  checkmate::assert_list(old_ops)
  checkmate::assert_list(new_ops)
  new_keys <- vapply(new_ops, studio_op_target, "")
  old_keys <- vapply(old_ops, studio_op_target, "")
  c(old_ops[!(old_keys %in% new_keys)], new_ops)
}

# Index of the last `"done"` entry in `journal` whose non-NA key equals `key`, or NULL when none matches.
studio_journal_match <- function(journal, key) {
  checkmate::assert_list(journal)
  checkmate::assert_string(key, na.ok = TRUE)
  if (is.na(key) || length(journal) == 0L) {
    return(NULL)
  }
  states <- vapply(journal, function(entry) entry$state, "")
  done_idx <- which(states == "done")
  if (length(done_idx) == 0L) {
    return(NULL)
  }
  last_idx <- done_idx[[length(done_idx)]]
  last <- journal[[last_idx]]
  if (!is.na(last$key) && identical(last$key, key)) last_idx else NULL
}

# Appends `change` to `journal`, or joins it with the last done entry when their keys match and are not NA.
# Drops that entry when a joined cell edit returns to its first value.
studio_journal_add <- function(journal, change) {
  checkmate::assert_list(journal)
  checkmate::assert_list(change, names = "unique")
  checkmate::assert_names(names(change), must.include = c("verb", "text", "key", "ops"))
  if (length(change$ops) == 0L) {
    return(journal)
  }

  last_idx <- studio_journal_match(journal, change$key)
  if (!is.null(last_idx)) {
    last <- journal[[last_idx]]
    if (!is.null(last$join) && !is.null(change$join)) {
      a <- change$join$new_val
      b <- last$join$first_val
      same_num <- is.numeric(a) && is.numeric(b) && length(a) == 1L && length(b) == 1L && isTRUE(a == b)
      both_na <- length(a) == 1L && length(b) == 1L && is.na(a) && is.na(b)
      if (identical(a, b) || same_num || both_na) {
        return(journal[-last_idx])
      }
      last$text <- paste0(last$join$prefix, last$join$first_text, " > ", change$join$new_text)
      last$ops <- change$ops
      last$target <- change$target
      journal[[last_idx]] <- last
      return(journal)
    }
    last$text <- change$text
    last$ops <- studio_merge_ops(last$ops, change$ops)
    last$target <- change$target
    journal[[last_idx]] <- last
    return(journal)
  }

  next_n <- if (length(journal) == 0L) 1L else journal[[length(journal)]]$n + 1L
  entry <- list(
    n = next_n,
    verb = change$verb,
    text = change$text,
    key = change$key,
    ops = change$ops,
    target = change$target,
    state = "done"
  )
  if (!is.null(change$join)) {
    entry$join <- change$join
  }
  journal[[length(journal) + 1L]] <- entry
  journal
}

# Whether `journal` has at least one entry in state `"done"`.
studio_journal_can_undo <- function(journal) {
  checkmate::assert_list(journal)
  any(vapply(journal, function(entry) identical(entry$state, "done"), logical(1)))
}

# Marks the last `"done"` entry in `journal` as `"undone"`.
studio_journal_undo <- function(journal) {
  checkmate::assert_list(journal)
  done_idx <- which(vapply(journal, function(entry) identical(entry$state, "done"), logical(1)))
  if (length(done_idx) == 0L) {
    return(journal)
  }
  idx <- done_idx[[length(done_idx)]]
  journal[[idx]]$state <- "undone"
  journal
}

# Replays every `"done"` entry in `journal` onto `base` and returns the resulting document.
studio_journal_replay <- function(base, journal) {
  studio_assert_doc(base, name = "base")
  checkmate::assert_list(journal)
  doc <- base
  for (entry in journal) {
    if (identical(entry$state, "done")) {
      doc <- studio_doc_apply(doc, entry$ops)
    }
  }
  doc
}
