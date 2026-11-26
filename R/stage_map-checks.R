# The checks that look across the stage map's tables: an id given twice in a table, and an id that names a row of
# another table which is not there. They refuse only what the engine refuses when it draws the map (each case was tried
# in a browser first), and say so in R, with the ids and the fix, instead of in the widget. Callers: stage_map() and
# the layer functions, with the map's R data (the converter has already accepted it, so the columns that are required
# exist). A join to a table the map does not hold yet (zones, steps or variants that a later call may add) is left
# alone until that table arrives, and is the engine's to report if it never does.

# The tables of the map: the name of each, and the singular of a row (for a message) and the function that gives it.
stage_map_table_words <- list(
  cards = list(row = "card", given = "`cards` of `stage_map()`"),
  stages = list(row = "stage", given = "`stages` of `stage_map()`"),
  lanes = list(row = "lane", given = "`lanes` of `stage_map()`"),
  kinds = list(row = "kind", given = "`kinds` of `add_links()`"),
  zones = list(row = "zone", given = "`zones` of `add_zones()`"),
  steps = list(row = "step", given = "`steps` of `add_steps()`"),
  variants = list(row = "variant", given = "`variants` of `add_variants()`")
)

# The joins: a column of one table that holds ids of another table. `split` is for a column of ids separated by commas.
# `changes` is checked by stage_map_check_changes(), with the steps it needs.
stage_map_joins <- list(
  list(table = "cards", column = "stage", to = "stages"),
  list(table = "cards", column = "lane", to = "lanes"),
  list(table = "cards", column = "zone", to = "zones"),
  list(table = "cards", column = "variants", to = "variants", split = TRUE),
  list(table = "links", column = "from", to = "cards"),
  list(table = "links", column = "to", to = "cards"),
  list(table = "links", column = "kind", to = "kinds"),
  list(table = "links", column = "step", to = "steps"),
  list(table = "links", column = "variants", to = "variants", split = TRUE),
  list(table = "steps", column = "stage", to = "stages")
)

# The ids a column holds, as text, with NA left out. The cells of a `split` column (ids separated by commas) are cut at
# commas and trimmed, and empty pieces are dropped ("v1," holds one id). In any other column an empty string is an id,
# and the join check reports it.
column_ids <- function(column, split) {
  checkmate::assert_flag(split)
  ids <- as_text(column)
  if (split) {
    ids <- trimws(unlist(strsplit(ids[!is.na(ids)], ",", fixed = TRUE)))
    ids <- ids[nzchar(ids)]
  }
  unique(ids[!is.na(ids)])
}

# One error line pair (the fault, the fix) as a cli message part, with the values escaped.
check_lines <- function(fault, fix) {
  checkmate::assert_string(fault)
  checkmate::assert_string(fix)
  c("x" = cli_escape(fault), "i" = cli_escape(fix))
}

# A column or table name as cli writes a field: `x` is a path such as "links$from".
format_field <- function(x) {
  checkmate::assert_string(x)
  cli::format_inline("{.field {x}}")
}

# The problems with ids that are given twice in a table, as cli message lines; NULL when there are none.
stage_map_duplicate_problems <- function(data) {
  checkmate::assert_list(data, names = "named")
  lines <- lapply(names(stage_map_table_words), function(name) {
    ids <- if (is.data.frame(data[[name]])) as_text(data[[name]]$id)
    twice <- unique(ids[!is.na(ids) & duplicated(ids)])
    if (length(twice) == 0L) {
      return(NULL)
    }
    check_lines(
      paste0(
        format_field(paste0(name, "$id")),
        cli::format_inline(" has ids given more than once: {.val {twice}}.")
      ),
      paste0("Give each ", stage_map_table_words[[name]]$row, " one row.")
    )
  })
  unlist(lines)
}

# The problems with joins, as cli message lines; NULL when there are none. A table that is not in `data` is skipped,
# except `kinds`: a link's kind needs the kinds that come with the links, and none can be added afterwards.
stage_map_join_problems <- function(data) {
  checkmate::assert_list(data, names = "named")
  lines <- lapply(stage_map_joins, function(join) {
    column <- if (is.data.frame(data[[join$table]])) data[[join$table]][[join$column]]
    if (is.null(column)) {
      return(NULL)
    }
    found <- column_ids(column, isTRUE(join$split))
    to <- join$to
    field <- format_field(paste0(join$table, "$", join$column))
    target_ids <- format_field(paste0(to, "$id"))
    if (!is.data.frame(data[[to]])) {
      if (identical(to, "kinds") && length(found) > 0L) {
        return(check_lines(
          paste0(field, cli::format_inline(" names kinds ({.val {found}}), but no {.arg kinds} were given.")),
          paste0("Give the kinds in ", stage_map_table_words$kinds$given, ", or leave ", field, " out.")
        ))
      }
      return(NULL)
    }
    bad <- setdiff(found, as_text(data[[to]]$id))
    if (length(bad) == 0L) {
      return(NULL)
    }
    check_lines(
      paste0(field, " has ids that ", target_ids, cli::format_inline(" lacks: {.val {bad}}.")),
      paste0(
        "Use an id from ",
        target_ids,
        ", or add that ",
        stage_map_table_words[[to]]$row,
        " to ",
        stage_map_table_words[[to]]$given,
        "."
      )
    )
  })
  c(unlist(lines), stage_map_option_problems(data))
}

# The problems with the options that name a row: `target` must be a card, and `variant` a variant (when the map has
# variants; if a later call adds them, the check runs then). NULL when there are none.
stage_map_option_problems <- function(data) {
  checkmate::assert_list(data, names = "named")
  one <- function(option, to) {
    value <- as_text(data$options[[option]])
    if (length(value) != 1L || !is.data.frame(data[[to]]) || value %in% as_text(data[[to]]$id)) {
      return(NULL)
    }
    check_lines(
      cli::format_inline("{.arg {option}} is not a {stage_map_table_words[[to]]$row} of the map: {.val {value}}."),
      paste0("Use an id from ", format_field(paste0(to, "$id")), ".")
    )
  }
  c(one("target", "cards"), one("variant", "variants"))
}

# Refuses a map whose tables give an id twice or whose ids do not join, in one error of class `stagemap_error_data`
# that lists every problem. `data` is the map's R data. Callers: stage_map() and every layer function, with `call`
# the function the user called.
stage_map_check_data <- function(data, call) {
  checkmate::assert_list(data, names = "named")
  checkmate::assert_environment(call)
  problems <- c(stage_map_duplicate_problems(data), stage_map_join_problems(data))
  if (length(problems) > 0L) {
    sm_abort(
      c("The tables of the map do not agree.", problems),
      class = "stagemap_error_data",
      call = call
    )
  }
  invisible(NULL)
}
