# stage_map() statuses / names the tone it does not know and the ones it knows

    Code
      stage_map(nodes = data.frame(id = "a", label = "A", stage = "s", lane = "l",
        status = "blocked"), stages = data.frame(id = "s", label = "S"), lanes = data.frame(
        id = "l", label = "L"), statuses = data.frame(id = "blocked", label = "Blocked",
        tone = "purple"))
    Condition
      Error in `stage_map()`:
      ! The data cannot be turned into what the stage-map engine reads.
      x `statuses$tone[1]` must be one of "teal", "good", "warn", "bad", "muted", "orange", "blue", "violet", "pink", "gold", "grey", not "purple".

# stage_map() statuses / names the status a card uses that the map does not know, and the fix

    Code
      stage_map(nodes = data.frame(id = "a", label = "A", stage = "s", lane = "l",
        status = "blocked"), stages = data.frame(id = "s", label = "S"), lanes = data.frame(
        id = "l", label = "L"))
    Condition
      Error in `stage_map()`:
      ! The statuses do not match the cards.
      x nodes$status has statuses that are not known: "blocked".
      i Known statuses: "done", "running", "waiting", "failed", and "skipped". To use another one, add it to `statuses` of `stage_map()`, as a data frame with an id column.

# stage_map() arguments / names a mistyped argument and lists the valid ones

    Code
      stage_map(data.frame(id = "a", label = "A", stage = "s", lane = "l"),
      data.frame(id = "s", label = "S"), data.frame(id = "l", label = "L"),
      highligth = list(ids = "a"))
    Condition
      Error in `stage_map()`:
      ! Arguments after `...` must be named, and these are not arguments of this function: `highligth`.
      i Valid arguments: `nodes`, `stages`, `lanes`, `title`, `layout`, `target`, `variant`, `statuses`, `motion`, `legend`, `cell_columns`, `bundle_links`, `highlight`, `dismiss`, `player`, `panels`, `width`, `height`, and `element_id`.

# add_steps() changes / names the step and the card the data lacks, and the fix

    Code
      add_steps(map, data.frame(id = c("one", "two"), label = c("One", "Two")),
      changes = data.frame(step = c("one", "three"), card = c("a", "ghost"), status = "done"))
    Condition
      Error in `add_steps()`:
      ! `changes` does not match the steps and cards.
      x changes$step has ids that steps$id lacks: "three".
      i Use an id from steps$id, or add that step to `steps`.
      x changes$card has ids that are not cards of the map: "ghost".
      i Use an id from the map's nodes$id.

