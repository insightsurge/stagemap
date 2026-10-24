#' Add stagemap's error class to checkmate assertion failures
#' @noRd
with_stagemap_asserts <- function(code, call = parent.frame()) {
  checkmate::assert_environment(call)
  # code is a promise: evaluating it for validation would run the assertions twice.
  withCallingHandlers(
    code,
    error = function(error) {
      checkmate::assert_class(error, "error")
      # Checkmate has no assertion class; unrelated promise errors must pass through.
      message <- conditionMessage(error)
      # checkmate 2.3.4 uses "Assertion failed." for union assertions.
      assertion <- any(startsWith(
        message,
        c(
          "Assertion on '",
          "One of the following assertions failed:",
          "Assertion failed."
        )
      ))
      if (!inherits(error, "simpleError") || !assertion) {
        return(invisible(NULL))
      }
      # Escape braces and keep union checks on separate lines, without a repeated parent message.
      lines <- strsplit(message, "\n", fixed = TRUE)[[1]]
      lines <- gsub("}", "}}", gsub("{", "{{", lines, fixed = TRUE), fixed = TRUE)
      names(lines) <- c("", rep(" ", length(lines) - 1L))
      cli::cli_abort(lines, class = "stagemap_error", call = call)
    }
  )
}

#' Check an argument with the public call attached
#' @noRd
check_arg <- function(check, arg, call) {
  checkmate::assert(checkmate::check_true(check), checkmate::check_string(check))
  checkmate::assert_string(arg, min.chars = 1)
  checkmate::assert_environment(call)
  if (isTRUE(check)) {
    return(invisible(NULL))
  }
  cli::cli_abort("Invalid {.arg {arg}}: {check}", class = "stagemap_error", call = call)
}

#' Stop when dots caught unexpected arguments
#' @noRd
abort_dots <- function(extras, n, valid, call, fn, positional) {
  checkmate::assert_character(extras, any.missing = FALSE, null.ok = TRUE)
  checkmate::assert_count(n, positive = TRUE)
  checkmate::assert_character(valid, min.chars = 1, any.missing = FALSE)
  checkmate::assert_environment(call)
  checkmate::assert_string(fn, min.chars = 1)
  checkmate::assert_character(positional, min.chars = 1, any.missing = FALSE, min.len = 1)
  # Unnamed values have no name; positional values after dots are the usual slip.
  extras <- if (is.null(extras)) rep("", n) else extras
  unnamed <- sum(!nzchar(extras))
  labels <- c(
    if (unnamed == 1L) {
      "an unnamed argument"
    } else if (unnamed > 1L) {
      paste(unnamed, "unnamed arguments")
    },
    encodeString(extras[nzchar(extras)], quote = '"')
  )
  message <- paste0("Unexpected arguments: ", paste(labels, collapse = ", "), ".")
  message <- gsub("}", "}}", gsub("{", "{{", message, fixed = TRUE), fixed = TRUE)
  hint <- if (length(valid)) {
    "Name the optional arguments: {.arg {valid}}."
  } else {
    "{.fn {fn}} takes only {.and {.arg {positional}}}."
  }
  cli::cli_abort(
    c(message, "i" = hint),
    call = call,
    class = c("stagemap_error_dots", "stagemap_error"),
    names = extras
  )
}

#' Describe the first five rows with singular or plural wording
#' @noRd
row_text <- function(rows) {
  checkmate::assert_integerish(rows, lower = 1, any.missing = FALSE, min.len = 1)
  shown <- as.character(rows[seq_len(min(length(rows), 5L))])
  if (length(rows) > 5L) {
    shown <- c(shown, paste(length(rows) - 5L, "more"))
  }
  text <- if (length(shown) == 1L) {
    shown
  } else {
    paste0(paste(shown[-length(shown)], collapse = ", "), " and ", shown[length(shown)])
  }
  paste(if (length(rows) == 1L) "Row" else "Rows", text)
}

#' Report bad rows and, when useful, their values
#' @noRd
abort_rows <- function(
  rows,
  arg,
  column,
  problem,
  values = NULL,
  call = parent.frame(),
  value_label = "Values",
  verb = c("has", "have")
) {
  checkmate::assert_integerish(rows, lower = 1, any.missing = FALSE, min.len = 1)
  checkmate::assert_string(arg, min.chars = 1)
  checkmate::assert_string(column, min.chars = 1, null.ok = TRUE)
  checkmate::assert_string(problem, min.chars = 1)
  checkmate::assert_character(values, null.ok = TRUE)
  checkmate::assert_environment(call)
  checkmate::assert_string(value_label, min.chars = 1)
  checkmate::assert_character(verb, min.chars = 1, any.missing = FALSE, len = 2)
  # Computed inside the cli braces: lintr cannot see local variables used only there.
  message <- paste0(
    "{row_text(rows)} of {.arg {arg}} {verb[1L + (length(rows) > 1L)]} {problem}",
    if (!is.null(column)) " {.field {column}}",
    "."
  )
  cli::cli_abort(
    c(message, if (!is.null(values)) c("i" = "{value_label}: {.val {values[seq_len(min(length(values), 5L))]}}.")),
    class = c("stagemap_error_data", "stagemap_error"),
    call = call
  )
}
