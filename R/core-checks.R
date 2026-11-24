# Shared checks and conditions. Callers: every function that takes arguments (check_dots, assert_widget_args) and the
# core files (sm_abort, sm_warn, cli_escape, bullets, warn_dropped).

# Makes text safe to put inside a cli message: cli reads braces as code.
cli_escape <- function(x) {
  checkmate::assert_character(x)
  gsub("}", "}}", gsub("{", "{{", x, fixed = TRUE), fixed = TRUE)
}

# Stops with a classed error. `class` is the subclass; "stagemap_error" is always added. `call` is the function the
# user called, so the message names it. `...` becomes fields of the condition.
sm_abort <- function(message, class, ..., call = rlang::caller_env(), .envir = parent.frame()) {
  checkmate::assert_character(message, min.len = 1L, any.missing = FALSE)
  checkmate::assert_string(class, min.chars = 1L)
  checkmate::assert_environment(call, null.ok = TRUE)
  checkmate::assert_environment(.envir)
  cli::cli_abort(message, class = c(class, "stagemap_error"), ..., call = call, .envir = .envir)
}

# The same for a warning: classes `class` and "stagemap_warning".
sm_warn <- function(message, class, ..., call = rlang::caller_env(), .envir = parent.frame()) {
  checkmate::assert_character(message, min.len = 1L, any.missing = FALSE)
  checkmate::assert_string(class, min.chars = 1L)
  checkmate::assert_environment(call, null.ok = TRUE)
  checkmate::assert_environment(.envir)
  cli::cli_warn(message, class = c(class, "stagemap_warning"), ..., call = call, .envir = .envir)
}

# One warning for everything the converter left out because the engine has no field for it (see drop_unknown()).
warn_dropped <- function(dropped, call) {
  checkmate::assert_environment(dropped)
  checkmate::assert_environment(call)
  items <- dropped$items
  lines <- vapply(
    names(items),
    function(path) {
      where <- if (identical(path, ".")) "the data" else paste0("`", path, "`")
      cli_escape(sprintf(
        "Dropped %s from %s. Valid %s: %s.",
        paste0("`", items[[path]]$names, "`", collapse = ", "),
        where,
        paste0(items[[path]]$what, "s"),
        paste(items[[path]]$valid, collapse = ", ")
      ))
    },
    ""
  )
  words <- unique(vapply(items, function(item) paste0(item$what, "s"), ""))
  what <- if (length(words) == 1L) words else "columns or names"
  sm_warn(
    c(sprintf("Some %s have no field in the stage-map engine, so they were left out.", what), bullets(lines, "i")),
    class = "stagemap_warning_unused_columns",
    dropped = lapply(items, function(item) item$names),
    call = call
  )
}

# A character vector as a cli message vector: every line gets the bullet `bullet`.
bullets <- function(lines, bullet) {
  checkmate::assert_character(lines)
  checkmate::assert_string(bullet, min.chars = 1L)
  names(lines) <- rep(bullet, length(lines))
  lines
}

# Call as `check_dots(...)` right after the argument checks of a function whose `...` must stay empty. It names every
# value that landed there (a typo, or a value passed by position after the dots) and lists the valid argument names,
# read from the calling function's own formals, so no list of names is kept anywhere.
check_dots <- function(..., call = rlang::caller_env()) {
  checkmate::assert_environment(call)
  count <- ...length()
  if (count == 0L) {
    return(invisible(NULL))
  }
  names_given <- ...names()
  if (is.null(names_given)) {
    names_given <- rep("", count)
  }
  fn <- sys.function(sys.parent())
  valid <- cli::cli_vec(setdiff(names(formals(fn)), "..."), list("vec-trunc" = 100L))
  unnamed <- sum(!nzchar(names_given))
  named <- names_given[nzchar(names_given)]
  stray <- paste(
    c(
      if (unnamed > 0L) sprintf("%d unnamed value%s", unnamed, if (unnamed > 1L) "s" else ""),
      if (length(named) > 0L) sprintf("`%s`", named)
    ),
    collapse = " and "
  )
  sm_abort(
    c(
      sprintf(
        "Arguments after {.code ...} must be named, and these are not arguments of this function: %s.",
        cli_escape(stray)
      ),
      "i" = "Valid arguments: {.arg {valid}}."
    ),
    class = "stagemap_error_dots",
    names = names_given,
    valid = as.character(valid),
    call = call
  )
}

# Checks `dismiss` against the values the engine's contract lists for that option, so no function retypes them.
assert_dismiss <- function(dismiss) {
  checkmate::assert_choice(dismiss, sm_spec()$fields$options$fields$dismiss$values)
}

# Checks the arguments every widget function ends with: the two sizes and the HTML id.
assert_widget_args <- function(width, height, element_id) {
  checkmate::assert(
    checkmate::check_string(width, min.chars = 1L, null.ok = TRUE),
    checkmate::check_number(width, lower = 0, finite = TRUE),
    .var.name = "width"
  )
  checkmate::assert(
    checkmate::check_string(height, min.chars = 1L, null.ok = TRUE),
    checkmate::check_number(height, lower = 0, finite = TRUE),
    .var.name = "height"
  )
  checkmate::assert_string(element_id, min.chars = 1L, null.ok = TRUE)
  invisible(NULL)
}
