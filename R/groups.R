#' Set group colours and legend labels
#'
#' Set group meaning on a [stagemap()] with a group column. Later calls replace
#' settings per name and keep the others. Unused names warn and are kept.
#' Unset colours use a colour-blind-friendly palette of eight colours, cycling
#' when needed.
#'
#' @inheritParams sm_stages
#' @param colours A named character vector of R colour names or hex colours
#'   (`#RGB`, `#RRGGBB` or `#RRGGBBAA`), keyed by unique, non-empty group names.
#'   Colours are stored as upper-case hex. `NULL` leaves colours unchanged.
#' @param labels A named character vector of non-missing legend strings that
#'   are non-empty after trimming whitespace, keyed by unique, non-empty group
#'   names. `NULL` leaves labels unchanged.
#' @returns The changed `stagemap` object, visibly, for use in a pipe.
#' @family meaning
#' @export
#' @examples
#' nodes <- data.frame(
#'   id = c("REQ-1", "REQ-2", "TST-1", "RES-1"),
#'   stage = c("Requirement", "Requirement", "Test", "Result"),
#'   group = c("Safety", "Usability", "Safety", "Safety")
#' )
#' sm_groups(stagemap(nodes), colours = c(Safety = "orange"), labels = c(Safety = "Safety checks"))
sm_groups <- function(map, colours = NULL, labels = NULL) {
  with_stagemap_asserts({
    checkmate::assert_class(map, "stagemap")
    checkmate::assert_character(colours, any.missing = FALSE, min.chars = 1, null.ok = TRUE)
    checkmate::assert_character(labels, any.missing = FALSE, null.ok = TRUE)
  })
  check_arg(checkmate::check_true(all(nzchar(trimws(labels)))), "labels", environment())
  check_setting_names(colours, "colours", environment())
  check_setting_names(labels, "labels", environment())
  if (!"group" %in% names(map$nodes)) {
    cli::cli_abort("{.arg map} has no {.field group} column.", class = "stagemap_error")
  }
  if (is.null(map$groups)) {
    map$groups <- list(colours = character(), labels = character())
  }
  for (group in names(colours)) {
    colours[group] <- as_colour(colours[[group]], "colours", environment())
  }
  warn_unused_settings(
    union(names(colours), names(labels)),
    unique(map$nodes$group[!is.na(map$nodes$group)]),
    "groups",
    environment()
  )
  if (length(colours)) {
    map$groups$colours[names(colours)] <- colours
  }
  if (length(labels)) {
    map$groups$labels[names(labels)] <- labels
  }
  map
}

#' Resolve used groups to a plain legend table
#' @noRd
resolve_groups <- function(map) {
  checkmate::assert_class(map, "stagemap")
  groups <- as.character(unique(map$nodes$group[!is.na(map$nodes$group)]))
  result <- data.frame(group = groups, colour = rep(NA_character_, length(groups)), label = groups)
  palette <- c("#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7", "#999999")
  automatic <- 0L
  for (i in seq_along(groups)) {
    group <- groups[i]
    if (group %in% names(map$groups$colours)) {
      result$colour[i] <- map$groups$colours[[group]]
    } else {
      automatic <- automatic + 1L
      result$colour[i] <- palette[(automatic - 1L) %% length(palette) + 1L]
    }
    if (group %in% names(map$groups$labels)) result$label[i] <- map$groups$labels[[group]]
  }
  result
}
