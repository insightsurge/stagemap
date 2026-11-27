# What each field type of the engine's contract accepts and how it is written. Callers: convert_problems() and
# convert_json(). The types are the contract's own (string, id, markdown, scalar, boolean, enum, words, ids, date and
# icon); object, list and any (the contract's `json`) are handled by the converter itself. A rule has four parts, each
# a function of the values `x` and the field's `spec`:
#   ok(x, spec)    does x have an accepted class?
#   bad(x, spec)   which non-missing values are not accepted? (a logical vector the length of x)
#   want(spec)     the accepted values in words, for a message
#   to(x)          x as the vector that goes into the JSON

# Numbers become text without exponents or padding: as.character(1e5) is "1e+05", which would break an id.
as_text <- function(x) {
  if (is.numeric(x)) {
    out <- vapply(
      as.numeric(x),
      function(v) if (is.na(v)) NA_character_ else format(v, scientific = FALSE, trim = TRUE, digits = 15),
      ""
    )
    return(out)
  }
  as.character(x)
}

# The one rule for an id, in a table and in an argument: text that is not blank, or a whole number of any size (the
# check on a number is not capped at the largest integer, as checkmate's integerish checks are). A factor is its text.
# `id_bad()` says which non-missing values of a column are not ids; `check_id_values()` and `assert_id_values()` judge
# an argument.
id_bad <- function(x) {
  if (is.numeric(x)) {
    return(!is.finite(x) | x != round(x))
  }
  grepl("^[[:space:]]*$", as.character(x))
}

# `TRUE` when `x` is a vector of ids, none missing (`len` is the length it must have, `NULL` for any, zero included);
# else why not, in checkmate's wording.
check_id_values <- function(x, len = NULL) {
  if (is.factor(x)) {
    x <- as.character(x)
  }
  if (!is.character(x) && !is.numeric(x)) {
    return(sprintf("Must be text or whole numbers, not '%s'", class(x)[[1]]))
  }
  if (!is.null(len) && length(x) != len) {
    return(sprintf("Must have length %d, but has length %d", len, length(x)))
  }
  if (anyNA(x)) {
    return(sprintf("Contains missing values (element %d)", which(is.na(x))[[1]]))
  }
  bad <- which(id_bad(x))
  if (length(bad) > 0L) {
    return(sprintf("Element %d is not an id: an id is text that is not blank, or a whole number", bad[[1]]))
  }
  TRUE
}

# Stops, with checkmate's own error, unless `x` is ids (see check_id_values()); `null_ok` lets `NULL` pass. `label`
# names the argument; `call`, when given, is the function the user called, named in the error in place of this helper.
assert_id_values <- function(x, label, len = NULL, null_ok = FALSE, call = NULL) {
  checkmate::assert_string(label, min.chars = 1L)
  checkmate::assert_count(len, null.ok = TRUE)
  checkmate::assert_flag(null_ok)
  checkmate::assert_environment(call, null.ok = TRUE)
  found <- if (null_ok && is.null(x)) TRUE else check_id_values(x, len)
  if (is.null(call)) {
    return(checkmate::makeAssertion(x, found, label, NULL))
  }
  with_caller_call(checkmate::makeAssertion(x, found, label, NULL), call)
}

date_pattern <- "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"

# The field types that hold a vector, always written as a JSON array, even with one item.
vector_types <- c("words", "ids")

type_rules <- list(
  string = list(
    ok = function(x, spec) is.character(x) || is.factor(x) || is.numeric(x),
    bad = function(x, spec) rep(FALSE, length(x)),
    want = function(spec) "text (a character vector, a factor or numbers)",
    to = function(x) as_text(x)
  ),
  # A reference to a row (a card, a stage, a kind): text that is not blank. A number is accepted too, when it is whole,
  # and written as text, so that 7 and "7" are the same id and a join on it holds.
  id = list(
    ok = function(x, spec) is.character(x) || is.factor(x) || is.numeric(x),
    bad = function(x, spec) id_bad(x),
    want = function(spec) "an id (text that is not blank, or a whole number)",
    to = function(x) as_text(x)
  ),
  # Text the engine reads as inline or block Markdown: a string, never a number.
  markdown = list(
    ok = function(x, spec) is.character(x) || is.factor(x),
    bad = function(x, spec) rep(FALSE, length(x)),
    want = function(spec) "text (a character vector or a factor)",
    to = function(x) as.character(x)
  ),
  # A word or a number that is shown as it is (a label can be a year); written as text, so that joins on it hold.
  scalar = list(
    ok = function(x, spec) is.character(x) || is.factor(x) || is.numeric(x),
    bad = function(x, spec) if (is.numeric(x)) !is.finite(x) else rep(FALSE, length(x)),
    want = function(spec) "text or a finite number",
    to = function(x) as_text(x)
  ),
  boolean = list(
    ok = function(x, spec) is.logical(x),
    bad = function(x, spec) rep(FALSE, length(x)),
    want = function(spec) "TRUE or FALSE",
    to = function(x) as.logical(x)
  ),
  enum = list(
    ok = function(x, spec) is.character(x) || is.factor(x),
    bad = function(x, spec) !(as.character(x) %in% spec$values),
    want = function(spec) paste0("one of ", paste0("\"", spec$values, "\"", collapse = ", ")),
    to = function(x) as.character(x)
  ),
  # Plain words, always written as a JSON array, even with one word. `values` limit them, when the spec has them.
  words = list(
    ok = function(x, spec) is.character(x) || is.factor(x),
    bad = function(x, spec) {
      if (is.null(spec$values)) rep(FALSE, length(x)) else !(as.character(x) %in% spec$values)
    },
    want = function(spec) {
      if (is.null(spec$values)) {
        "words (text)"
      } else {
        paste0("words from ", paste0("\"", spec$values, "\"", collapse = ", "))
      }
    },
    to = function(x) as.character(x)
  ),
  date = list(
    ok = function(x, spec) inherits(x, "Date") || is.character(x),
    bad = function(x, spec) !inherits(x, "Date") & !grepl(date_pattern, as.character(x)),
    want = function(spec) "a Date, or text like \"2026-03-02\"",
    to = function(x) if (inherits(x, "Date")) format(x, "%Y-%m-%d") else as.character(x)
  ),
  # The name of one of the engine's icons; the engine knows the names, so R accepts any text.
  icon = list(
    ok = function(x, spec) is.character(x) || is.factor(x),
    bad = function(x, spec) rep(FALSE, length(x)),
    want = function(spec) "the name of an icon (text)",
    to = function(x) as.character(x)
  ),
  # Ids, always a JSON array. An id is text or a whole number, written as text.
  ids = list(
    ok = function(x, spec) is.character(x) || is.factor(x) || is.numeric(x),
    bad = function(x, spec) id_bad(x),
    want = function(spec) "ids (text that is not blank, or whole numbers)",
    to = function(x) as_text(x)
  )
)
