# What the package relies on in the bundled stage-map engine (inst/kit/), in one place: test-kit.R checks each name
# against the engine's own contract (inst/kit/stage-map.json). A later change that uses another command, event or
# file of the engine adds it here, so a new copy of the engine that drops it fails a test, not a user's page.
kit_relied_on <- list(
  # The calls the page makes to the engine, by the names the contract gives them.
  commands = c("select", "highlight", "size", "history", "show", "hide", "disable", "enable", "state"),
  # What the engine announces, with the package's prefix.
  events = c("stagemap:select", "stagemap:size", "stagemap:hover", "stagemap:link"),
  # How the build is named: the global, the prefix of its attributes, tokens and events, the CSS class prefix and the
  # attribute on the element a map is drawn in.
  names = list(
    global = "stagemap",
    prefix = "stagemap",
    css = "sm",
    root_attribute = "data-stagemap-visual"
  ),
  # The files a page loads, in the order it loads them.
  page_files = c("d3.min.js", "stage-map.css", "stage-map.js")
)

# The path of a file in the bundled engine; "" when the file is not there.
kit_path <- function(...) {
  system.file("kit", ..., package = "stagemap")
}

# The engine's contract (inst/kit/stage-map.json), as a list.
kit_contract <- function() {
  jsonlite::read_json(kit_path("stage-map.json"))
}

# The record of the copy (inst/kit/kit.json), as a list.
kit_record <- function() {
  jsonlite::read_json(kit_path("kit.json"))
}
