# Snapshots of the messages a person reads when the stage map's statuses or an add_steps() change are wrong.
describe("stage_map() statuses", {
  it("names the tone it does not know and the ones it knows", {
    expect_snapshot(
      stage_map(
        nodes = data.frame(id = "a", label = "A", stage = "s", lane = "l", status = "blocked"),
        stages = data.frame(id = "s", label = "S"),
        lanes = data.frame(id = "l", label = "L"),
        statuses = data.frame(id = "blocked", label = "Blocked", tone = "purple")
      ),
      error = TRUE
    )
  })

  it("names the status a card uses that the map does not know, and the fix", {
    expect_snapshot(
      stage_map(
        nodes = data.frame(id = "a", label = "A", stage = "s", lane = "l", status = "blocked"),
        stages = data.frame(id = "s", label = "S"),
        lanes = data.frame(id = "l", label = "L")
      ),
      error = TRUE
    )
  })
})

describe("stage_map() arguments", {
  it("names a mistyped argument and lists the valid ones", {
    expect_snapshot(
      stage_map(
        data.frame(id = "a", label = "A", stage = "s", lane = "l"),
        data.frame(id = "s", label = "S"),
        data.frame(id = "l", label = "L"),
        highligth = list(ids = "a")
      ),
      error = TRUE
    )
  })
})

describe("add_steps() changes", {
  it("names the step and the card the data lacks, and the fix", {
    map <- stage_map(
      nodes = data.frame(id = "a", label = "A", stage = "s", lane = "l"),
      stages = data.frame(id = "s", label = "S"),
      lanes = data.frame(id = "l", label = "L")
    )
    expect_snapshot(
      add_steps(
        map,
        data.frame(id = c("one", "two"), label = c("One", "Two")),
        changes = data.frame(step = c("one", "three"), card = c("a", "ghost"), status = "done")
      ),
      error = TRUE
    )
  })
})
