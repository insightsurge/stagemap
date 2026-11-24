# Data layers: a layer function puts more of the map's own data into a widget, and the widget is built again.
# Callers: the layer functions (sm_add_data()). Nothing here knows a field: the spec says which fields the map takes.

# The R data a widget was built from, before conversion, so that it can be built again.
sm_widget_data <- function(x) {
  checkmate::assert_class(x, "stagemap_widget")
  checkmate::assert_list(x$stagemap$data, names = "named")
  x$stagemap$data
}

# Builds the widget `x` again from new R data. Its size, element id and kept choices stay unless given. A name the
# engine lacks was warned about when its data came in (sm_widget() or sm_add_data()), so a rebuild gives that warning
# no more: a pipe of three layer calls warns about a misspelt option once, not four times.
sm_rebuild <- function(
  x,
  data,
  width = x$width,
  height = x$height,
  element_id = x$elementId,
  call = rlang::caller_env(),
  keep = x$stagemap$keep
) {
  checkmate::assert_class(x, "stagemap_widget")
  checkmate::assert_list(data, names = "named")
  checkmate::assert_environment(call)
  checkmate::assert_list(keep, names = "unique")
  withCallingHandlers(
    sm_widget(data, width, height, element_id, call = call, keep = keep),
    stagemap_warning_unused_columns = function(warning) invokeRestart("muffleWarning")
  )
}

# Adds `fields` (fields of the map's data, such as a list of rows) and `options` (fields of its `options` object) to
# the widget `x`, then builds it again, so the converter checks the new data as it checks the rest. A value that is
# NULL adds nothing. A field the map does not take, or one the widget already has, is a `stagemap_error_layer`.
sm_add_data <- function(x, fields, options = list(), call = rlang::caller_env()) {
  checkmate::assert_list(fields, names = "unique")
  checkmate::assert_list(options, names = "unique")
  checkmate::assert_environment(call)
  if (!inherits(x, "stagemap_widget")) {
    sm_abort(
      c("{.arg x} must be a widget made by a stagemap function.", "x" = "It is {.cls {class(x)}}."),
      class = "stagemap_error_widget",
      call = call
    )
  }
  spec <- sm_spec()
  data <- sm_widget_data(x)
  # Options given as a named vector (c(title = "T")) are a list from here on, so more can be added to them.
  if (!is.null(data$options)) {
    data$options <- as.list(data$options)
  }
  fields <- fields[!vapply(fields, is.null, logical(1))]
  options <- options[!vapply(options, is.null, logical(1))]
  layer_check(as.character(names(fields)), spec$fields, data, "", call)
  if (length(options) > 0L) {
    layer_check("options", spec$fields, list(), "", call)
    layer_check(as.character(names(options)), spec$fields$options$fields, data$options, "options$", call)
  }
  # The new data's own warnings, once: the names the engine lacks in what this call adds. Data with problems is left
  # to the rebuild, which stops with them all.
  added <- spec$fields[names(fields)]
  if (length(fields) > 0L && length(convert_problems(fields, added)) == 0L) {
    convert_json(fields, added, call = call)
  }
  added_options <- spec$fields$options$fields
  if (length(options) > 0L && length(convert_problems(options, added_options, "options")) == 0L) {
    convert_json(options, added_options, path = "options", call = call)
  }
  data[names(fields)] <- fields
  if (length(options) > 0L) {
    data$options[names(options)] <- options
  }
  sm_rebuild(x, data, call = call)
}

# Refuses a name the spec lacks, or one the data already holds. `prefix` is the path shown before the name.
layer_check <- function(names, spec_fields, data, prefix, call) {
  checkmate::assert_character(names, any.missing = FALSE)
  checkmate::assert_list(spec_fields, null.ok = TRUE)
  checkmate::assert_list(data, null.ok = TRUE)
  checkmate::assert_string(prefix)
  checkmate::assert_environment(call)
  for (field in names) {
    if (!field %in% names(spec_fields)) {
      sm_abort(
        "The stage-map engine has no field {.field {prefix}{field}}, so it cannot be added.",
        class = "stagemap_error_layer",
        call = call
      )
    }
    if (!is.null(data[[field]])) {
      sm_abort(
        c(
          "The widget already has {.field {prefix}{field}}.",
          "i" = "Give it once: add it in one call, with all its rows."
        ),
        class = "stagemap_error_layer",
        call = call
      )
    }
  }
  invisible(NULL)
}
