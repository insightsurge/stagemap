# The stage map's test data, made up for the tests. Callers: the tests of stage_map() and its layers (plain, snapshot
# and browser files).

# The smallest valid map: one card, one stage, one lane. `...` replace or add arguments of stage_map().
slim <- function(...) {
  args <- list(
    nodes = data.frame(id = "a", label = "A", stage = "s", lane = "l"),
    stages = data.frame(id = "s", label = "S"),
    lanes = data.frame(id = "l", label = "L")
  )
  changes <- list(...)
  args[names(changes)] <- changes
  do.call(stage_map, args)
}

# Two cards in one stage and lane, to join with links.
small <- function() {
  slim(nodes = data.frame(id = c("a", "b"), label = c("A", "B"), stage = "s", lane = "l"))
}

# The data the page receives, as a list.
data_of <- function(widget) jsonlite::fromJSON(unclass(widget$x$data), simplifyVector = FALSE)

# `x` without its NULL items at any depth: a data frame's NA is written as null, which fromJSON() reads as NULL, so a
# row that left a cell out compares equal to a list that never had it.
canonical <- function(x) {
  if (!is.list(x)) {
    return(x)
  }
  lapply(x[!vapply(x, is.null, logical(1))], canonical)
}

# The regions the map hands to its host, as a character vector.
hosted_of <- function(widget) unlist(data_of(widget)$options$hosted)

# A map with every kind of data in it, for the browser tests: four cards in two stages and two lanes, a stage with a
# text (so the side panel has something to show), a zone with a note, links with a kind, steps and variants.
full_map <- function(...) {
  args <- list(
    nodes = data.frame(
      id = c("a", "b", "c", "d"),
      label = c("Draft", "Review", "Publish", "Archive"),
      stage = c("write", "check", "check", "ship"),
      lane = c("docs", "docs", "code", "code"),
      status = c("done", "running", "waiting", "waiting"),
      zone = c(NA, "sign", "sign", NA),
      owner = c("Ann", "Bo", "Cy", "Di")
    ),
    stages = data.frame(
      id = c("write", "check", "ship"),
      label = c("Write", "Check", "Ship"),
      text = c("Where the words are made.", NA, NA)
    ),
    lanes = data.frame(id = c("docs", "code"), label = c("Docs", "Code"))
  )
  changes <- list(...)
  args[names(changes)] <- changes
  map <- do.call(stage_map, args)
  map |>
    add_links(
      data.frame(from = c("a", "b", "c"), to = c("b", "c", "d"), kind = c("hand", "hand", NA)),
      kinds = data.frame(id = "hand", label = "Handed over", line = "dashed")
    ) |>
    add_zones(data.frame(id = "sign", label = "Needs sign-off", note = "Two people read it."))
}
