# Map room view: stage_map() layout and display options form, each field sending `option`.
studio_room_map_view <- function(state) {
  checkmate::assert_list(state, names = "unique")
  doc <- state$doc
  args <- doc$args
  layout <- args$layout %||% "grid"
  layout_labels <- c(
    grid = "Grid",
    levels = "Levels (experimental)",
    dates = "Dates (experimental)"
  )
  layout_values <- sm_spec()$fields$options$fields$layout$values
  layout_choices <- lapply(layout_values, function(val) {
    lbl <- if (val %in% names(layout_labels)) unname(layout_labels[[val]]) else studio_cap(val)
    studio_choice(val, lbl)
  })
  stages <- doc$tables$stages
  has_stage_dates <- is.data.frame(stages) && "date" %in% names(stages) && any(!is.na(stages$date))
  layout_hint <- if (identical(layout, "dates") && !has_stage_dates) {
    "No stage has a date yet. Give one in a stage's form."
  } else {
    NULL
  }

  opt_ev <- function(name) list(type = "option", data = list(name = name))
  offered <- function(name) identical(studio_arg_where("arg", name), "map")

  target_val <- if (is.null(args$target) || is.na(args$target)) "" else as_text(args$target)
  cols_val <- if (is.null(args$cell_columns)) "1" else as.character(args$cell_columns)
  col_choices <- c(
    lapply(1:6, function(k) studio_choice(as.character(k), as.character(k))),
    list(studio_choice("auto", "Auto"))
  )
  bundle_val <- isTRUE(args$bundle_links)
  legend_val <- if (is.null(args$legend)) TRUE else isTRUE(args$legend)
  faults <- state$check$faults %||% studio_faults(doc)

  fields <- drop_nulls(list(
    if (offered("layout")) {
      studio_field(
        "layout",
        "Layout",
        "radio",
        layout,
        opt_ev("layout"),
        choices = layout_choices,
        hint = layout_hint
      )
    },
    if (offered("target") && identical(layout, "levels")) {
      studio_field(
        "target",
        "Target",
        "select",
        target_val,
        opt_ev("target"),
        choices = studio_ensure_choice(studio_table_choices(doc, "cards", include_none = TRUE), target_val, "card"),
        problem = studio_field_problem(doc, faults, "args", "target", "target")
      )
    },
    if (offered("cell_columns") && identical(layout, "grid")) {
      studio_field(
        "cell_columns",
        "Cards per cell",
        "select",
        cols_val,
        opt_ev("cell_columns"),
        choices = col_choices
      )
    },
    if (offered("bundle_links") && identical(layout, "grid")) {
      studio_field("bundle_links", "Bundle links", "toggle", bundle_val, opt_ev("bundle_links"))
    },
    if (offered("legend")) {
      studio_field("legend", "Legend", "toggle", legend_val, opt_ev("legend"))
    }
  ))

  list(fields = fields)
}
