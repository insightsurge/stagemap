# The spec reader. Callers: sm_widget(), the layers, the converters' checks and the Shiny plumbing. The spec is the
# stage-map engine's own contract, inst/kit/stage-map.json, copied unedited and read when it is first needed, so the
# engine is the only place that says what the map's data, options, commands and events hold. This file holds no list
# of names.

# The cache: filled once per file, read afterwards. Nothing else in the package keeps process state.
spec_cache <- new.env(parent = emptyenv())

# Reads a JSON file under inst/kit/ once and keeps the result.
sm_read <- function(file) {
  checkmate::assert_string(file, min.chars = 1L)
  if (is.null(spec_cache[[file]])) {
    path <- system.file("kit", file, package = "stagemap")
    if (!nzchar(path)) {
      cli::cli_abort("The file {.file {file}} is missing from the installed package.")
    }
    spec_cache[[file]] <- jsonlite::read_json(path, simplifyVector = FALSE)
  }
  spec_cache[[file]]
}

# The engine version the contract records. The dependency carries it, so a page that loads two copies can tell them
# apart.
sm_kit_version <- function() {
  sm_read("stage-map.json")$version
}

# The fields of the contract that this package reads: every one except an old name. The contract marks an old name with
# `old_name_of` and still lists it, because the engine reads it for a time; R takes and sends only the new name, so a
# list of old names is not kept here.
current_fields <- function(fields) {
  checkmate::assert_list(fields, null.ok = TRUE)
  fields[!vapply(fields, function(field) !is.null(field$old_name_of), logical(1))]
}

# Normalises one field of a data description: its type, whether it is required, the allowed values and nested fields.
# The contract's `json` (any JSON) becomes `any`. A field the contract marks as an old name is left out (see
# current_fields()).
normalise_field <- function(field) {
  checkmate::assert_list(field)
  type <- field$type
  if (identical(type, "json")) {
    type <- "any"
  }
  list(
    type = type,
    required = isTRUE(field$required),
    values = unlist(field$values),
    default = field$default,
    fields = if (!is.null(field$fields)) lapply(current_fields(field$fields), normalise_field)
  )
}

# The fields a widget's data holds. The contract lists the map's `options` beside its `data`, but the engine reads
# them as the data's `options` object, so the options are one more field, named `options`.
entry_fields <- function(contract) {
  checkmate::assert_list(contract)
  fields <- lapply(current_fields(contract$data), normalise_field)
  if (!is.null(contract$options)) {
    fields$options <- normalise_field(contract$options)
  }
  fields
}

# The contract as the one spec of the package: the engine's names, the fields, the commands, the events and what each
# command and event carries.
build_spec <- function() {
  contract <- sm_read("stage-map.json")
  list(
    name = contract$visual,
    global = contract$global,
    prefix = contract$prefix,
    version = contract$version,
    fields = entry_fields(contract),
    commands = as.character(unlist(contract$commands)),
    events = as.character(unlist(contract$events)),
    command_data = contract$command_data,
    event_data = contract$event_data,
    files = as.character(unlist(contract$files))
  )
}

# The spec, built once.
sm_spec <- function() {
  if (is.null(spec_cache$spec)) {
    spec_cache$spec <- build_spec()
  }
  spec_cache$spec
}
