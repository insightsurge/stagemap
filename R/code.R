# The builders of R code text. Callers: code_map() (the code of a map) and code_tokens() (its spans). A piece of code
# is a node: an atom (text that is never cut, such as a string or a number) or a call (a function's name and its
# arguments, each a node, named or not). code_lines() lays a node out in lines of at most `code_width` characters: a
# call on one line when it fits, else one argument per line; a vector that does not fit wraps at its commas. The
# writers of values (code_string(), code_number(), code_vector(), code_frame()) never ask the locale: deparse() and
# encodeString() write strings in a way that depends on it, so neither is used.

# The width a line of code keeps to.
code_width <- 80L

# The reserved words of R, which a name cannot be without backticks (`...` and `..1` are caught by code_name()).
code_reserved <- c(
  "if",
  "else",
  "repeat",
  "while",
  "function",
  "for",
  "in",
  "next",
  "break",
  "TRUE",
  "FALSE",
  "NULL",
  "Inf",
  "NaN",
  "NA",
  "NA_integer_",
  "NA_real_",
  "NA_character_",
  "NA_complex_"
)

# A node that is written as it is.
code_atom <- function(text) {
  checkmate::assert_string(text)
  list(kind = "atom", text = text)
}

# A node that calls `fn` with `args`, a list of nodes; a name gives a named argument, "" (or no names) a positional one.
code_call <- function(fn, args = list()) {
  checkmate::assert_string(fn, min.chars = 1L)
  checkmate::assert_list(args, types = "list")
  if (is.null(names(args))) {
    names(args) <- rep("", length(args))
  }
  list(kind = "call", fn = fn, args = args)
}

# A name as R reads it: bare when it is an ASCII syntactic name that is not reserved, else in backticks. ASCII only, so
# the answer does not depend on the locale's idea of a letter.
code_name <- function(x) {
  checkmate::assert_character(x, any.missing = FALSE)
  bare <- grepl("^(([A-Za-z]|[.][A-Za-z._])[A-Za-z0-9._]*|[.])$", x) &
    !grepl("^[.][.]([.]|[0-9]+)$", x) &
    !x %in% code_reserved
  escaped <- gsub("`", "\\`", gsub("\\", "\\\\", x, fixed = TRUE), fixed = TRUE)
  ifelse(bare, x, paste0("`", escaped, "`"))
}

# The Unicode bidirectional controls and their UTF-8 bytes: the Arabic letter mark, the left-to-right and
# right-to-left marks, the embeddings and overrides (202A to 202E) and the isolates (2066 to 2069).
code_bidi_controls <- c(
  list(list(code = 0x061CL, bytes = as.raw(c(0xD8, 0x9C)))),
  lapply(c(0x200EL, 0x200FL, 0x202AL:0x202EL, 0x2066L:0x2069L), function(code) {
    list(code = code, bytes = as.raw(c(0xE2, 0x80 + (code %/% 64L) %% 64L, 0x80 + code %% 64L)))
  })
)

# Strings as R code, in double quotes: a backslash, a double quote, a newline, a carriage return, a tab and every
# other control character are escaped, and every other character is left as it is, except the Unicode bidirectional
# controls (they change how text reads, and R's parser refuses them raw in a string), which are written as `\u` escapes.
# NA is `NA`. The text is UTF-8 and is worked on byte by byte (no byte of a UTF-8 letter beyond ASCII is an ASCII
# byte), so no locale is asked.
code_string <- function(x) {
  checkmate::assert_character(x)
  missing <- is.na(x)
  x <- enc2utf8(x)
  swap <- function(x, from, to) gsub(from, to, x, fixed = TRUE, useBytes = TRUE)
  x <- swap(x, "\\", "\\\\")
  x <- swap(x, "\"", "\\\"")
  x <- swap(x, "\n", "\\n")
  x <- swap(x, "\r", "\\r")
  x <- swap(x, "\t", "\\t")
  for (code in c(1:8, 11:12, 14:31, 127)) {
    x <- swap(x, rawToChar(as.raw(code)), sprintf("\\x%02x", code))
  }
  for (control in code_bidi_controls) {
    x <- swap(x, rawToChar(control$bytes), sprintf("\\u%04x", control$code))
  }
  out <- paste0("\"", x, "\"")
  Encoding(out) <- "UTF-8"
  out[missing] <- "NA"
  out
}

# Numbers as R code: integers with `L`, doubles in the fewest digits (15 to 17) that read back as the same number, so
# a whole double has no `L` and no decimal point. NA, Inf, -Inf and NaN are written as R writes them.
code_number <- function(x) {
  checkmate::assert_numeric(x)
  if (is.integer(x)) {
    return(ifelse(is.na(x), "NA", paste0(format(x, scientific = FALSE, trim = TRUE), "L")))
  }
  vapply(
    x,
    function(value) {
      if (is.nan(value)) {
        return("NaN")
      }
      if (is.na(value)) {
        return("NA")
      }
      if (is.infinite(value)) {
        return(if (value > 0) "Inf" else "-Inf")
      }
      for (digits in 15:16) {
        text <- sprintf(paste0("%.", digits, "g"), value)
        if (identical(as.numeric(text), value)) {
          return(text)
        }
      }
      sprintf("%.17g", value)
    },
    ""
  )
}

# The typed NA of each kind of vector, written when every value of a vector is NA.
code_typed_na <- function(x) {
  checkmate::assert_atomic(x)
  if (is.character(x)) {
    "NA_character_"
  } else if (is.integer(x)) {
    "NA_integer_"
  } else if (is.double(x)) {
    "NA_real_"
  } else {
    "NA"
  }
}

# The arguments of data.frame() that a column of the same name would be taken for.
code_frame_args <- c("row.names", "check.rows", "check.names", "fix.empty.names", "stringsAsFactors")

# An atomic vector as a node: one value bare, more (or names) in `c()`. Character, double, integer and logical vectors
# are written value by value, a factor as `factor(c(...), levels = c(...))` (with `exclude = NULL` when NA is a level),
# a Date as `as.Date(c(...))`, an `I()` vector inside `I()`, a raw vector by `as.raw()` and a complex one by
# `complex()`. A vector of any other class is written as its values inside `structure()`, with its attributes written
# the same way, so no value goes through deparse(), whose text depends on the locale.
code_vector <- function(x) {
  checkmate::assert_atomic(x)
  if (inherits(x, "AsIs")) {
    inner <- x
    class(inner) <- setdiff(class(x), "AsIs")
    return(code_call("I", list(code_vector(inner))))
  }
  if (is.factor(x)) {
    args <- list(code_vector(as.character(x)), levels = code_vector(levels(x)))
    if (anyNA(levels(x))) {
      args$exclude <- code_atom("NULL")
    }
    if (is.ordered(x)) {
      args$ordered <- code_atom("TRUE")
    }
    return(code_call("factor", args))
  }
  if (identical(class(x), "Date")) {
    return(code_call("as.Date", list(code_vector(format(x)))))
  }
  if (is.object(x)) {
    extra <- attributes(x)
    extra$names <- NULL
    values <- x
    attributes(values) <- if (!is.null(names(x))) list(names = names(x))
    return(code_call("structure", c(list(code_vector(values)), lapply(extra, code_value))))
  }
  if (is.raw(x)) {
    return(code_call("as.raw", list(code_vector(as.integer(x)))))
  }
  if (is.complex(x)) {
    return(code_call("complex", list(real = code_vector(Re(x)), imaginary = code_vector(Im(x)))))
  }
  if (length(x) == 0L) {
    return(code_atom(paste0(if (is.double(x)) "numeric" else typeof(x), "()")))
  }
  texts <- if (all(is.na(x))) {
    rep(code_typed_na(x), length(x))
  } else if (is.character(x)) {
    code_string(x)
  } else if (is.numeric(x)) {
    code_number(x)
  } else {
    ifelse(is.na(x), "NA", ifelse(x, "TRUE", "FALSE"))
  }
  if (length(x) == 1L && is.null(names(x))) {
    return(code_atom(texts))
  }
  args <- lapply(texts, code_atom)
  names(args) <- if (is.null(names(x))) rep("", length(x)) else names(x)
  code_call("c", args)
}

# Any value as a node: NULL, a data frame, an atomic vector, or a list (written item by item in `list()`), with its
# attributes.
code_value <- function(x) {
  checkmate::assert(
    checkmate::check_data_frame(x),
    checkmate::check_list(x, null.ok = TRUE),
    checkmate::check_atomic(x)
  )
  if (is.null(x)) {
    return(code_atom("NULL"))
  }
  if (is.data.frame(x)) {
    return(code_frame(x))
  }
  # An item that is not an object but has attributes (a matrix's `dim`, a list's class) gets them in structure().
  extra <- attributes(x)
  extra$names <- NULL
  if ((is.list(x) || !is.object(x)) && length(extra) > 0L) {
    bare <- x
    attributes(bare) <- if (!is.null(names(x))) list(names = names(x))
    return(code_call("structure", c(list(code_value(bare)), lapply(extra, code_value))))
  }
  if (is.list(x)) {
    args <- lapply(x, code_value)
    names(args) <- names(x) %||% rep("", length(x))
    return(code_call("list", args))
  }
  code_vector(x)
}

# A data frame as a `data.frame()` node. A column that holds only NA is left out (in a table with rows). A column
# with one value in every row is written once when another column gives the number of rows. Columns keep their order;
# a name R cannot read bare gets backticks and the call gets `check.names = FALSE`, so the name comes back as it was.
# A column named like an argument of data.frame() would be taken for that argument, so a table with one is written
# with plain names (`x1`, `x2`, ...) inside `stats::setNames()`, which gives the real names back. A list column is
# written item by item inside `I(list(...))`, so data.frame() keeps it one column.
code_frame <- function(x) {
  checkmate::assert_data_frame(x)
  columns <- as.list(x)
  if (nrow(x) > 0L) {
    empty <- vapply(columns, function(column) is.atomic(column) && all(is.na(column)), logical(1))
    columns <- columns[!empty]
  }
  constant <- vapply(
    columns,
    function(column) is.atomic(column) && nrow(x) > 1L && length(unique(column)) == 1L,
    logical(1)
  )
  if (length(columns) > 0L && all(constant)) {
    constant[[1]] <- FALSE
  }
  args <- lapply(seq_along(columns), function(i) {
    column <- columns[[i]]
    if (is.list(column)) {
      items <- column
      class(items) <- setdiff(class(column), "AsIs")
      return(code_call("I", list(code_value(unclass(items)))))
    }
    # A matrix keeps its `dim`, so data.frame() makes its columns from it.
    if (!is.null(dim(column))) {
      return(code_value(column))
    }
    code_vector(if (constant[[i]]) column[1L] else column)
  })
  # A column with names would give data.frame() its row names: `row.names = NULL` keeps them as numbers.
  named <- any(vapply(columns, function(column) !is.null(names(column)), logical(1)))
  if (any(names(columns) %in% code_frame_args)) {
    names(args) <- paste0("x", seq_along(args))
    if (named) {
      args$row.names <- code_atom("NULL")
    }
    return(code_call("stats::setNames", list(code_call("data.frame", args), code_vector(names(columns)))))
  }
  names(args) <- names(columns)
  if (any(code_name(names(columns)) != names(columns))) {
    args$check.names <- code_atom("FALSE")
  }
  if (named) {
    args$row.names <- code_atom("NULL")
  }
  code_call("data.frame", args)
}

# A node on one line, however long.
code_flat <- function(node) {
  checkmate::assert_list(node)
  if (identical(node$kind, "atom")) {
    return(node$text)
  }
  args <- vapply(
    seq_along(node$args),
    function(i) {
      name <- names(node$args)[[i]]
      text <- code_flat(node$args[[i]])
      if (nzchar(name)) paste0(code_name(name), " = ", text) else text
    },
    ""
  )
  paste0(node$fn, "(", paste(args, collapse = ", "), ")")
}

# A node laid out as lines, starting `indent` spaces in, after `prefix` (such as "cards <- " or "id = ") and followed
# by `suffix` (such as "," or " |>"). It is one line when that fits in `code_width` (or cannot be cut: an atom, a call
# with no arguments); a `c()` of atoms wraps at its commas; any other call has one argument per line.
code_lines <- function(node, indent = 0L, prefix = "", suffix = "") {
  checkmate::assert_list(node)
  checkmate::assert_count(indent)
  checkmate::assert_string(prefix)
  checkmate::assert_string(suffix)
  pad <- strrep(" ", indent)
  one <- paste0(pad, prefix, code_flat(node), suffix)
  if (identical(node$kind, "atom") || nchar(one) <= code_width || length(node$args) == 0L) {
    return(one)
  }
  inner <- strrep(" ", indent + 2L)
  open <- paste0(pad, prefix, node$fn, "(")
  close <- paste0(pad, ")", suffix)
  n <- length(node$args)
  ends <- c(rep(",", n - 1L), "")
  plain <- all(vapply(node$args, function(arg) identical(arg$kind, "atom"), logical(1)))
  if (identical(node$fn, "c") && plain) {
    names <- names(node$args)
    texts <- vapply(node$args, function(arg) arg$text, "")
    items <- paste0(ifelse(nzchar(names), paste0(code_name(names), " = "), ""), texts, ends)
    return(c(open, code_pack(items, inner), close))
  }
  body <- unlist(lapply(seq_len(n), function(i) {
    name <- names(node$args)[[i]]
    code_lines(
      node$args[[i]],
      indent + 2L,
      prefix = if (nzchar(name)) paste0(code_name(name), " = ") else "",
      suffix = ends[[i]]
    )
  }))
  c(open, body, close)
}

# Items (each with its comma) packed into lines after `pad`, as many on a line as fit in `code_width`.
code_pack <- function(items, pad) {
  checkmate::assert_character(items, any.missing = FALSE)
  checkmate::assert_string(pad)
  lines <- character()
  current <- ""
  for (item in items) {
    joined <- if (nzchar(current)) paste(current, item) else item
    if (nzchar(current) && nchar(pad) + nchar(joined) > code_width) {
      lines <- c(lines, paste0(pad, current))
      current <- item
    } else {
      current <- joined
    }
  }
  c(lines, paste0(pad, current))
}

# The class of each token of R's parser, as the page colours it.
code_token_classes <- c(
  STR_CONST = "str",
  NUM_CONST = "num",
  NULL_CONST = "num",
  SYMBOL_FUNCTION_CALL = "fn",
  SYMBOL_SUB = "arg",
  SYMBOL_FORMALS = "arg",
  COMMENT = "com",
  SYMBOL = "name",
  SYMBOL_PACKAGE = "name"
)

# Each line of `lines` (one R text, as code_map() writes it) cut into spans, each `list(text, class)`, whose texts
# paste back to the line. The class is one of "str", "num", "fn", "arg", "op", "com" and "name"; the spaces before a
# token go into its span. The text is parsed once as a whole (a line of a call cut over several lines does not parse
# alone); text that does not parse, or a line whose tokens cannot be found in it, is one span of class "name".
code_tokens <- function(lines) {
  checkmate::assert_character(lines, any.missing = FALSE)
  parsed <- tryCatch(parse(text = lines, keep.source = TRUE, encoding = "UTF-8"), error = function(error) NULL)
  data <- if (!is.null(parsed)) utils::getParseData(parsed, includeText = TRUE)
  if (!is.null(data)) {
    data <- data[data$terminal, , drop = FALSE]
    data <- data[order(data$line1, data$col1), , drop = FALSE]
    data$full <- utils::getParseText(data, data$id)
  }
  lapply(seq_along(lines), function(i) {
    line <- lines[[i]]
    whole <- list(list(text = line, class = "name"))
    if (!nzchar(line)) {
      return(list())
    }
    if (is.null(data)) {
      return(whole)
    }
    tokens <- data[data$line1 == i, , drop = FALSE]
    spans <- list()
    rest <- line
    for (k in seq_len(nrow(tokens))) {
      text <- tokens$full[[k]]
      lead <- regmatches(rest, regexpr("^ *", rest))
      if (!startsWith(substring(rest, nchar(lead) + 1L), text)) {
        return(whole)
      }
      class <- code_token_classes[tokens$token[[k]]]
      spans[[length(spans) + 1L]] <- list(
        text = paste0(lead, text),
        class = if (is.na(class)) "op" else unname(class)
      )
      rest <- substring(rest, nchar(lead) + nchar(text) + 1L)
    }
    if (nzchar(rest) || length(spans) == 0L) {
      return(whole)
    }
    spans
  })
}
