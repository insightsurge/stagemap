#' Set the text of status badges
#'
#' Set badge text on a [stagemap()]. Built-in words are `pass`, `fail`, `missing`,
#' `warn` and `skip`; changing their text keeps their icon and tone. Other words
#' have no icon and a neutral tone, with the word itself as the default text.
#' Later calls replace text per word and keep the others. Unused words are kept
#' without a warning, so a vocabulary can be shared across maps.
#'
#' @inheritParams sm_stages
#' @param ... Named, non-missing, non-empty character strings, such as
#'   `skip = "not planned"`. Names must be unique and non-empty. Empty dots leave
#'   the settings unchanged.
#' @returns The changed `stagemap` object, visibly, for use in a pipe.
#' @family meaning
#' @export
#' @examples
#' nodes <- data.frame(
#'   id = c("REQ-1", "REQ-2", "TST-1", "RES-1"),
#'   stage = c("Requirement", "Requirement", "Test", "Result"),
#'   status = c("pass", "missing", "pass", "fail")
#' )
#' sm_status(stagemap(nodes), skip = "not planned")
sm_status <- function(map, ...) {
  with_stagemap_asserts({
    checkmate::assert_class(map, "stagemap")
    checkmate::assert_list(list(...))
  })
  settings <- list(...)
  check_setting_names(settings, "...", environment())
  for (word in names(settings)) {
    check_arg(checkmate::check_string(settings[[word]], min.chars = 1), word, environment())
    check_arg(checkmate::check_true(nzchar(trimws(settings[[word]]))), word, environment())
  }
  if (length(settings)) {
    map$status[names(settings)] <- unlist(settings, use.names = FALSE)
  }
  map
}

#' Resolve the badge vocabulary and whether each word is used
#' @noRd
resolve_status <- function(map) {
  checkmate::assert_class(map, "stagemap")
  builtins <- c("pass", "fail", "missing", "warn", "skip")
  used <- unique(map$nodes$status[!is.na(map$nodes$status)])
  words <- unique(c(builtins, names(map$status), used))
  result <- data.frame(
    word = words,
    text = words,
    icon = rep(NA_character_, length(words)),
    tone = rep("neutral", length(words)),
    used = words %in% used
  )
  result$text[seq_along(builtins)] <- c("Pass", "Fail", "Missing", "Warning", "Skipped")
  result$icon[seq_along(builtins)] <- c("check", "cross", "dash", "warning", "skip")
  result$tone[seq_along(builtins)] <- c("good", "bad", "bad", "warn", "neutral")
  if (length(map$status)) {
    result$text[match(names(map$status), words)] <- map$status
  }
  result
}
