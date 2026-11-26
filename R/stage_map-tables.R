# The one reader of a map: map_parts() gives back the tables a stage_map() widget was built from and the arguments
# that build it again. Callers: stage_map_tables() and stage_map_code().

# The tables a map can hold, in the order they are given back.
map_table_names <- c("cards", "stages", "lanes", "statuses", "links", "kinds", "zones", "steps", "changes", "variants")

#' The tables a stage map was built from
#'
#' Gives back the data frames a [stage_map()] widget holds, as they were given to [stage_map()] and the `add_*()`
#' functions, with every column (also the columns the engine does not read). Use it to look at a map's data in R, or to
#' change a table and build the map again.
#'
#' The list holds only the tables the map has, in the order `cards`, `stages`, `lanes`, `statuses`, `links`, `kinds`,
#' `zones`, `steps`, `changes` and `variants`. `stages` and `lanes` are always there: when [stage_map()] was not given
#' them, they are the tables it took from the cards. `statuses` is there only when it was given as a data frame; given
#' as a named character vector, it is an argument, not a table. [stage_map_code()] gives the code that builds the map
#' again.
#'
#' @param map A [stage_map()] widget, with any layers added.
#' @returns A named list of data frames. A `map` that is not a [stage_map()] widget, or a map whose `hosted` option no
#'   argument of [stage_map()] gives, is an error of class `stagemap_error_widget`.
#' @family stage map
#' @examples
#' map <- stage_map(
#'   data.frame(id = c("a", "b"), label = c("Draft", "Review"), stage = c("w", "c"), lane = "docs")
#' ) |>
#'   add_links(data.frame(from = "a", to = "b"))
#' tables <- stage_map_tables(map)
#' names(tables)
#' tables$stages
#' @export
stage_map_tables <- function(map) {
  map_parts(map, call = rlang::current_env())$tables
}

# The parts of the map `map` (a stage_map() widget): `tables`, the data frames it holds (see stage_map_tables()), and
# `args`, every argument of stage_map() but `cards`, `stages`, `lanes` and `...`, with the value that builds this map,
# plus `intro` (of add_steps()) and `highlight` (`list(ids, links)` of stage_map_highlight(), or NULL). An entry may be
# NULL. `call` is the function the user called, for the errors: a `map` that is not a widget, and a `hosted` option no
# argument can give.
map_parts <- function(map, call = rlang::caller_env()) {
  checkmate::assert_environment(call)
  if (!inherits(map, "stagemap_widget")) {
    sm_abort(
      c("{.arg map} must be a widget made by a stagemap function.", "x" = "It is {.cls {class(map)}}."),
      class = "stagemap_error_widget",
      call = call
    )
  }
  data <- sm_widget_data(map)
  options <- as.list(data$options)
  tables <- data[intersect(map_table_names, names(data))]
  tables <- tables[vapply(tables, is.data.frame, logical(1))]
  player <- map$stagemap$keep$player
  hosted <- as.character(options[["hosted"]])
  panels <- !all(stage_map_panel_regions %in% hosted)
  map_check_hosted(hosted, panels, player, !is.null(tables$steps), call)
  highlight <- options[["highlight"]]
  cell_columns <- options[["cell_columns"]]
  args <- list(
    title = options[["title"]],
    layout = options[["layout"]],
    target = options[["target"]],
    variant = options[["variant"]],
    statuses = if (is.character(options[["statuses"]])) options[["statuses"]],
    motion = options[["motion"]],
    legend = options[["legend"]],
    cell_columns = if (is.numeric(cell_columns)) as.numeric(cell_columns) else cell_columns,
    bundle_links = options[["bundle_links"]],
    dismiss = options[["dismiss"]],
    player = player,
    panels = panels,
    width = map$width,
    height = map$height,
    element_id = map$elementId,
    intro = options[["intro"]],
    highlight = if (!is.null(highlight)) {
      list(ids = as.character(unclass(highlight$ids)), links = highlight$links)
    }
  )
  list(tables = tables, args = args)
}

# Refuses a `hosted` option that stage_map() and add_steps() would not give with `panels` and `player`: the three
# panel regions all or none (`panels`), and "steps" when the player is off (`player` FALSE, or NULL with no steps).
map_check_hosted <- function(hosted, panels, player, has_steps, call) {
  checkmate::assert_character(hosted, any.missing = FALSE)
  checkmate::assert_flag(panels)
  checkmate::assert_flag(player, null.ok = TRUE)
  checkmate::assert_flag(has_steps)
  checkmate::assert_environment(call)
  regions <- intersect(stage_map_panel_regions, hosted)
  steps_off <- isFALSE(player) || (is.null(player) && !has_steps)
  good <- all(hosted %in% c(stage_map_panel_regions, "steps")) &&
    length(regions) %in% c(0L, length(stage_map_panel_regions)) &&
    identical("steps" %in% hosted, steps_off)
  if (!good) {
    sm_abort(
      c(
        "The map's {.field options$hosted} cannot be given by the arguments of {.fn stage_map}.",
        "x" = "It holds {.val {hosted}}."
      ),
      class = "stagemap_error_widget",
      call = call
    )
  }
  invisible(NULL)
}
