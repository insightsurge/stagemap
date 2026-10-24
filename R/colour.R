#' Normalise one colour to hex, retaining transparency
#' @noRd
as_colour <- function(x, arg, call) {
  checkmate::assert_string(x, min.chars = 1)
  checkmate::assert_string(arg, min.chars = 1)
  checkmate::assert_environment(call)
  # Expand short hex before passing it to col2rgb().
  colour <- if (grepl("^#[[:xdigit:]]{3}$", x)) {
    paste0("#", paste(rep(strsplit(substring(x, 2L), "")[[1L]], each = 2L), collapse = ""))
  } else {
    x
  }
  # Only hex and named colours: col2rgb() reads digit strings as palette() positions, which depend on the session.
  known <- grepl("^#([[:xdigit:]]{6}|[[:xdigit:]]{8})$", colour) || colour %in% c(grDevices::colours(), "transparent")
  rgb <- if (known) grDevices::col2rgb(colour, alpha = TRUE)
  if (is.null(rgb)) {
    cli::cli_abort("Invalid {.arg {arg}} colour: {.val {x}}.", class = "stagemap_error", call = call)
  }
  paste0("#", paste(sprintf("%02X", rgb[seq_len(if (rgb[4L, 1L] == 255L) 3L else 4L), 1L]), collapse = ""))
}

#' Check the keys of a named settings vector or list
#' @noRd
check_setting_names <- function(x, arg, call) {
  checkmate::assert_vector(x, null.ok = TRUE)
  checkmate::assert_string(arg, min.chars = 1)
  checkmate::assert_environment(call)
  if (!length(x)) {
    return(invisible(NULL))
  }
  check_arg(checkmate::check_names(names(x), type = "unique"), arg, call)
  check_arg(checkmate::check_true(length(names(x)) == length(x) && all(nzchar(trimws(names(x))))), arg, call)
  invisible(NULL)
}

#' Warn about settings not used by this map
#' @noRd
warn_unused_settings <- function(keys, used, arg, call) {
  checkmate::assert_character(keys, any.missing = FALSE, null.ok = TRUE)
  checkmate::assert_character(used, any.missing = FALSE)
  checkmate::assert_string(arg, min.chars = 1)
  checkmate::assert_environment(call)
  unused <- setdiff(keys, used)
  if (length(unused)) {
    cli::cli_warn(
      "Unused {.arg {arg}} names in this map: {.val {unused}}.",
      class = c("stagemap_warning_unused", "stagemap_warning"),
      call = call
    )
  }
  invisible(NULL)
}
