# Made-up specs for the converter's tests (test-core-convert.R, test-core-json.R and test-core-types.R). They name no
# field of the stage map: the converter sees only types.
field <- function(type, required = FALSE, values = NULL, fields = NULL) {
  list(type = type, required = required, values = values, default = NULL, fields = fields)
}
made_up <- list(
  rows = field(
    "list",
    TRUE,
    fields = list(
      id = field("string", TRUE),
      n = field("boolean"),
      kind = field("enum", values = c("a", "b")),
      day = field("date"),
      meta = field("object", fields = list(who = field("string", TRUE), flag = field("boolean"))),
      tags = field("words", values = c("x", "y")),
      anything = field("any"),
      parts = field("list", fields = list(k = field("string", TRUE)))
    )
  ),
  opts = field("object", fields = list(title = field("string", TRUE), flag = field("boolean"))),
  extra = field("any")
)
rows <- function(...) data.frame(id = c("x", "y"), ..., stringsAsFactors = FALSE)
as_list <- function(json) jsonlite::fromJSON(unclass(json), simplifyVector = FALSE)

# Data the stage map's contract accepts: one stage, one lane and one card, with a title in the options.
map_data <- function() {
  list(
    options = list(title = "T"),
    stages = data.frame(id = "s", label = "S"),
    lanes = data.frame(id = "l", label = "L"),
    cards = data.frame(id = "a", label = "A", stage = "s", lane = "l")
  )
}

# Changes the cached spec for the calling test, as if the contract said so; the spec comes back when the test ends.
local_spec <- function(changes, env = parent.frame()) {
  sm_spec()
  before <- spec_cache$spec
  spec <- before
  spec[names(changes)] <- changes
  spec_cache$spec <- spec
  withr::defer(spec_cache$spec <- before, envir = env)
  invisible(NULL)
}
