# The data converter, first half: what is wrong with the data. Callers: sm_widget() (the map's data) and sm_add_data()
# (a layer's data). It sees only types: the spec's `fields` say what a list, an object, a list of words or a value may
# hold. convert_problems() lists what is wrong, with paths like nodes$status[3] or nodes$about[2]$who, and never
# throws. The second half, which writes the JSON, is in core-json.R; call it after this finds nothing.

# The checks below run once per column, row or value, and are reached only from convert_problems(), which asserts its
# own inputs, so the helpers do not repeat the assertions.

# A list of records: an unnamed list whose items are all named lists. It is the other way to give a `list` field,
# beside a data frame, and the one that keeps a key a record leaves out left out (a data frame has a cell for every
# key of every row, and writes the empty ones as null).
is_records <- function(x) {
  is.list(x) &&
    !is.data.frame(x) &&
    is.null(names(x)) &&
    all(vapply(x, function(record) is.list(record) && !is.data.frame(record) && !is.null(names(record)), logical(1)))
}

# A path such as nodes$status: the name alone at the top.
join_path <- function(path, name) {
  if (nzchar(path)) paste0(path, "$", name) else name
}

rows_text <- function(index) {
  shown <- paste(index[seq_len(min(5L, length(index)))], collapse = ", ")
  if (length(index) > 5L) paste0("[", shown, ", ...]") else paste0("[", shown, "]")
}

# Problems of one column (scalar = FALSE) or one value (scalar = TRUE), judged by its field's type. A vector that is
# only NA counts as left out, whatever type R gave it (readr types an empty column as logical).
vector_problems <- function(x, spec, label, scalar) {
  rule <- type_rules[[spec$type]]
  if (is.null(rule)) {
    return(sprintf("`%s` has a type stagemap cannot check (%s).", label, spec$type))
  }
  if (scalar && length(x) != 1L) {
    return(sprintf("`%s` must have one value, not %d.", label, length(x)))
  }
  blank <- is.logical(x) && all(is.na(x))
  if (!blank && !rule$ok(x, spec)) {
    return(sprintf("`%s` must be %s, not %s.", label, rule$want(spec), class(x)[[1]]))
  }
  missing <- is.na(x)
  out <- character()
  at <- function(index) if (scalar) label else paste0(label, rows_text(index))
  if (spec$required && any(missing)) {
    out <- c(out, sprintf("`%s` is required but has NA.", at(which(missing))))
  }
  bad <- !missing
  bad[bad] <- rule$bad(x[bad], spec)
  if (any(bad)) {
    got <- encodeString(as.character(x[bad][[1]]), quote = "\"")
    out <- c(out, sprintf("`%s` must be %s, not %s.", at(which(bad)), rule$want(spec), got))
  }
  out
}

# The cells of a column that holds objects, lists or words (or ids): one per row, whether the column is a list column,
# a packed data frame or a plain vector (one word per row).
column_cells <- function(column) {
  if (is.data.frame(column)) {
    # A list column of data frames, cut to one row, is a list of one data frame: the cell is that data frame.
    lapply(seq_len(nrow(column)), function(i) {
      lapply(as.list(column[i, , drop = FALSE]), function(cell) {
        if (is.list(cell) && !is.data.frame(cell) && length(cell) == 1L && is.data.frame(cell[[1]])) cell[[1]] else cell
      })
    })
  } else if (is.list(column)) {
    column
  } else {
    as.list(column)
  }
}

empty_cell <- function(cell) {
  is.null(cell) || (is.atomic(cell) && length(cell) == 1L && is.na(cell))
}

column_problems <- function(column, spec, label) {
  if (identical(spec$type, "any")) {
    return(character())
  }
  if (!spec$type %in% c("object", "list", vector_types)) {
    return(vector_problems(column, spec, label, scalar = FALSE))
  }
  cells <- column_cells(column)
  out <- lapply(seq_along(cells), function(i) {
    if (empty_cell(cells[[i]])) {
      return(if (spec$required) sprintf("`%s[%d]` is required.", label, i) else character())
    }
    field_problems(cells[[i]], spec, sprintf("%s[%d]", label, i))
  })
  as.character(unlist(out))
}

field_problems <- function(x, spec, label) {
  if (is.null(x)) {
    return(if (spec$required) sprintf("`%s` is required.", label) else character())
  }
  switch(
    spec$type,
    any = character(),
    words = ,
    ids = vector_problems(x, spec, label, scalar = FALSE),
    list = {
      if (is_records(x)) {
        return(as.character(unlist(lapply(seq_along(x), function(i) {
          repeated <- unique(names(x[[i]])[duplicated(names(x[[i]]))])
          if (length(repeated) > 0L) {
            return(sprintf(
              "`%s[%d]` has the name %s more than once.",
              label,
              i,
              paste0("`", repeated, "`", collapse = ", ")
            ))
          }
          convert_problems(x[[i]], spec$fields, sprintf("%s[%d]", label, i))
        }))))
      }
      if (!is.data.frame(x)) {
        return(sprintf("`%s` must be a data frame or a list of named lists, not %s.", label, class(x)[[1]]))
      }
      repeated <- unique(names(x)[duplicated(names(x))])
      if (length(repeated) > 0L) {
        return(sprintf("`%s` has the column %s more than once.", label, paste0("`", repeated, "`", collapse = ", ")))
      }
      unlist(lapply(names(spec$fields), function(name) {
        column <- x[[name]]
        if (is.null(column)) {
          if (spec$fields[[name]]$required) sprintf("`%s` needs a column `%s`.", label, name) else character()
        } else {
          column_problems(column, spec$fields[[name]], join_path(label, name))
        }
      }))
    },
    object = {
      # A list needs names (an empty one is an object with nothing in it); so does a vector.
      named <- (is.list(x) && !is.data.frame(x) && (length(x) == 0L || !is.null(names(x)))) ||
        (is.atomic(x) && !is.null(names(x)))
      if (!named) {
        return(sprintf("`%s` must be a named list or a named vector, not %s.", label, class(x)[[1]]))
      }
      repeated <- unique(names(x)[duplicated(names(x))])
      if (length(repeated) > 0L) {
        return(sprintf("`%s` has the name %s more than once.", label, paste0("`", repeated, "`", collapse = ", ")))
      }
      convert_problems(as.list(x), spec$fields, label)
    },
    vector_problems(x, spec, label, scalar = TRUE)
  )
}

convert_problems <- function(value, fields, path = "") {
  checkmate::assert_list(fields, names = "named")
  checkmate::assert_string(path)
  if (!is.list(value) || is.data.frame(value)) {
    return(sprintf("`%s` must be a named list, not %s.", if (nzchar(path)) path else "the data", class(value)[[1]]))
  }
  out <- lapply(names(fields), function(name) {
    field_problems(value[[name]], fields[[name]], join_path(path, name))
  })
  as.character(unlist(out))
}
