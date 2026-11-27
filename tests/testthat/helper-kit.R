# What the package relies on in the bundled stage-map engine (inst/kit/), in one place: test-kit.R checks each name
# against the engine's own contract (inst/kit/stage-map.json). A later change that uses another command, event or
# file of the engine adds it here, so a new copy of the engine that drops it fails a test, not a user's page.
kit_relied_on <- list(
  # The calls the page makes to the engine, by the names the contract gives them.
  commands = c("select", "highlight", "size", "history", "show", "hide", "disable", "enable", "state"),
  # What the engine announces, with the package's prefix.
  events = c("stagemap:select", "stagemap:size", "stagemap:hover", "stagemap:link"),
  # The options the package sends or checks, by their names in the contract's `options`.
  options = c(
    "layout",
    "title",
    "intro",
    "motion",
    "target",
    "variant",
    "statuses",
    "legend",
    "cell_columns",
    "bundle_links",
    "highlight",
    "dismiss",
    "hosted"
  ),
  # The fields of an event the page hands to R, as the contract names them: the seven of `input$<id>_pick`, the three
  # that the browser tests check are empty on a lone map (`via`, `at` and `seq`), and the two of a hover that
  # `input$<id>_hovered` reads.
  event_fields = list(
    select = c("kind", "id", "ids", "from", "label", "still", "by", "via", "at", "seq"),
    hover = c("kind", "id")
  ),
  # The fields of the state that hold ids, and the others R reads (`selected_ids`, `stage`, `step`, `highlighted`,
  # `hidden`, `disabled`): the contract says "lists of ids" in the words of the `state` command.
  state_id_lists = c("selected_ids", "hidden", "disabled", "highlighted"),
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
