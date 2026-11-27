# Which stage_map() arguments and contract columns the studio offers where, or why they are kept untouched.
# Callers: studio_events (to limit edit and option to offered fields) and later the form views.

# Builds the coverage table from `formals(stage_map)` and `sm_spec()$fields` so every new formal or column
# appears until a release places it or explains why it is kept.
studio_args_table <- function() {
  arg_where <- c(
    title = "header",
    layout = "map",
    target = "map",
    legend = "map",
    cell_columns = "map",
    bundle_links = "map"
  )
  arg_why <- c(
    variant = "Variants are carried and written to code, not edited in this release.",
    statuses = "Custom statuses are carried and written to code; built-in statuses are used in the inspector.",
    motion = "Motion follows the map and the reader's reduced-motion setting; it is carried and written to code.",
    dismiss = "The studio keeps the pick on clicks outside the map.",
    player = "The studio controls the step player; the setting is carried and written to code.",
    panels = "The studio hosts the panels itself; the setting is carried and written to code.",
    width = "The studio sizes the map to the drawing sheet; the setting is carried and written to code.",
    height = "The studio sizes the map to the drawing sheet; the setting is carried and written to code.",
    element_id = "The studio assigns the widget id itself; the setting is carried and written to code."
  )
  arg_names <- setdiff(names(formals(stage_map)), c("cards", "stages", "lanes", "..."))

  offered_cols <- list(
    cards = c("id", "label", "stage", "lane", "sub", "status", "tone", "text", "zone", "milestone"),
    stages = c("id", "label", "kicker", "text", "date", "flag", "tone"),
    lanes = c("id", "label", "tone", "text"),
    links = c("from", "to", "kind", "label")
  )
  col_why <- list(
    cards = c(
      variants = "Variants are carried and written to code, not edited in this release.",
      hidden = "Card visibility is carried and written to code, not edited in this release.",
      disabled = "Card disabled state is carried and written to code, not edited in this release.",
      reason = "The disabled reason is carried and written to code, not edited in this release."
    ),
    stages = c(
      file = "Stage code files are carried and written to code, not edited in the inspector.",
      code = "Stage code snippets are carried and written to code, not edited in the inspector.",
      code_lines = "Marked code lines are carried and written to code, not edited in the inspector."
    ),
    lanes = character(),
    links = c(
      step = "Step associations are carried and written to code, not edited in this release.",
      variants = "Variants are carried and written to code, not edited in this release."
    )
  )

  spec_fields <- sm_spec()$fields
  rows <- list(data.frame(
    what = "arg",
    name = arg_names,
    where = ifelse(arg_names %in% names(arg_where), unname(arg_where[arg_names]), "kept"),
    why = ifelse(arg_names %in% names(arg_where), NA_character_, unname(arg_why[arg_names])),
    stringsAsFactors = FALSE
  ))

  for (tbl in names(offered_cols)) {
    cols <- names(spec_fields[[tbl]]$fields)
    where <- ifelse(cols %in% offered_cols[[tbl]], "inspector", "kept")
    why <- ifelse(where == "kept", unname(col_why[[tbl]][cols]), NA_character_)
    rows[[length(rows) + 1L]] <- data.frame(
      what = tbl,
      name = cols,
      where = where,
      why = why,
      stringsAsFactors = FALSE
    )
  }

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

args_cache <- new.env(parent = emptyenv())

# The coverage table of stage_map() arguments and contract columns, built lazily on first use.
studio_args <- function() {
  if (is.null(args_cache$table)) {
    args_cache$table <- studio_args_table()
  }
  args_cache$table
}

# The placement of `name` under `what` ("arg", "cards", "stages", "lanes", "links"), or NULL if absent.
studio_arg_where <- function(what, name) {
  checkmate::assert_string(what, min.chars = 1L)
  checkmate::assert_string(name, min.chars = 1L)
  args <- studio_args()
  hit <- args$where[args$what == what & args$name == name]
  if (length(hit) == 0L) NULL else hit[[1L]]
}
