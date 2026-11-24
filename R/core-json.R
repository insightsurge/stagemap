# The data converter, second half: the JSON. Callers: sm_widget() (the map's data) and sm_send() (the data of a
# command). convert_json() writes the JSON the engine reads, and it is the only place that does: rows for data frames,
# ids as text, NA as null, scalars unboxed because the spec says they are scalars (never because they have length
# one), objects and lists inside rows shaped the same way at any depth, an object that is already `json` embedded as
# it is, and every "<" escaped. Call it after convert_problems() found nothing.

# The helpers below run once per column, row or value and are reached only from convert_prepare(), which asserts its
# own inputs, so they do not repeat the assertions.

# Returns the names of a container to keep: those the spec has a field for. An unknown column of a data frame is left
# out of what is sent, quietly: it stays in the R data (`sm_widget_data()`), for the functions that read the map in R
# and for Shiny events, so a table with many columns draws without a warning. An unknown name inside an object or a
# record (a misspelt option) is noted in `dropped`, an environment filled while converting, for one warning; the row
# number is left out of the path so that every row of a column adds to one entry. `what` is "column" for a data frame
# and "name" for an object.
drop_unknown <- function(found, spec_fields, label, dropped, what = "name") {
  unknown <- setdiff(found, names(spec_fields))
  if (length(unknown) == 0L) {
    return(found)
  }
  if (!identical(what, "column")) {
    key <- gsub("\\[[0-9]+\\]", "", label)
    if (!nzchar(key)) {
      key <- "."
    }
    seen <- dropped$items[[key]]
    dropped$items[[key]] <- list(names = union(seen$names, unknown), valid = names(spec_fields), what = what)
  }
  intersect(found, names(spec_fields))
}

# Data with no spec (a command's data, or a column the spec lacks). Length-one atomic values become scalars unless
# wrapped in I(); a named vector is an object; a `json` object is kept as it is.
prepare_any <- function(x) {
  if (inherits(x, "json")) {
    x
  } else if (is.data.frame(x)) {
    x[] <- lapply(x, function(column) if (is.list(column)) lapply(column, prepare_any) else column)
    x
  } else if (is.list(x)) {
    lapply(x, prepare_any)
  } else if (is.atomic(x) && !is.null(names(x)) && !inherits(x, "AsIs")) {
    lapply(as.list(x), prepare_any)
  } else if (inherits(x, "scalar")) {
    x
  } else if (is.atomic(x) && length(x) == 1L && !inherits(x, "AsIs")) {
    jsonlite::unbox(if (is.factor(x)) as.character(x) else unname(x))
  } else {
    x
  }
}

# One cell of an object, list or words column as it will be written: NULL (null) when the cell is empty.
prepare_cell <- function(cell, spec, label, dropped) {
  if (empty_cell(cell)) NULL else prepare_field(cell, spec, label, dropped)
}

prepare_frame <- function(x, spec, label, dropped) {
  frame <- as.data.frame(x, stringsAsFactors = FALSE)
  keep <- drop_unknown(names(frame), spec$fields, label, dropped, what = "column")
  frame <- frame[keep]
  for (name in keep) {
    field <- spec$fields[[name]]
    label_name <- join_path(label, name)
    if (identical(field$type, "any")) {
      next
    }
    if (field$type %in% c("object", "list", vector_types)) {
      cells <- column_cells(frame[[name]])
      frame[[name]] <- lapply(seq_along(cells), function(i) {
        prepare_cell(cells[[i]], field, sprintf("%s[%d]", label_name, i), dropped)
      })
    } else {
      frame[[name]] <- type_rules[[field$type]]$to(frame[[name]])
    }
  }
  frame
}

prepare_field <- function(x, spec, label, dropped) {
  switch(
    spec$type,
    any = prepare_any(x),
    object = {
      written <- prepare_object(as.list(x), spec$fields, label, dropped)
      # An object with nothing in it is {}: R writes an empty list as [].
      if (length(written) == 0L) structure("{}", class = "json") else written
    },
    list = if (is_records(x)) {
      lapply(seq_along(x), function(i) {
        prepare_object(as.list(x[[i]]), spec$fields, sprintf("%s[%d]", label, i), dropped)
      })
    } else {
      prepare_frame(x, spec, label, dropped)
    },
    words = ,
    ids = type_rules[[spec$type]]$to(x),
    jsonlite::unbox(unname(type_rules[[spec$type]]$to(x)))
  )
}

prepare_object <- function(value, fields, label, dropped) {
  keep <- drop_unknown(names(value), fields, label, dropped)
  out <- lapply(keep, function(name) {
    if (is.null(value[[name]])) {
      return(NULL)
    }
    prepare_field(value[[name]], fields[[name]], join_path(label, name), dropped)
  })
  names(out) <- keep
  out[!vapply(out, is.null, logical(1))]
}

# `value` prepared for writing: it follows the spec and drops what the spec lacks (a name inside an object, with one
# warning; a column of a data frame, quietly); with NULL for `fields` it takes any value as it is (a command's data).
# Not yet text, so a caller can put it inside a larger tree.
convert_prepare <- function(value, fields = NULL, path = "", call = rlang::caller_env()) {
  checkmate::assert_list(fields, names = "named", null.ok = TRUE)
  checkmate::assert_string(path)
  checkmate::assert_environment(call)
  dropped <- new.env(parent = emptyenv())
  dropped$items <- list()
  prepared <- if (is.null(fields)) {
    prepare_any(value)
  } else {
    prepare_object(as.list(value), fields, path, dropped)
  }
  if (length(dropped$items) > 0L) {
    warn_dropped(dropped, call)
  }
  prepared
}

# Prepared data as JSON text (class "json").
write_json <- function(prepared) {
  json <- jsonlite::toJSON(
    prepared,
    dataframe = "rows",
    auto_unbox = FALSE,
    na = "null",
    null = "null",
    digits = NA,
    rownames = FALSE,
    keep_vec_names = FALSE,
    json_verbatim = TRUE
  )
  structure(gsub("<", "\\u003c", as.character(json), fixed = TRUE), class = "json")
}

# `value` as JSON text (class "json"), by convert_prepare() and write_json().
convert_json <- function(value, fields = NULL, path = "", call = rlang::caller_env()) {
  write_json(convert_prepare(value, fields, path, call))
}
