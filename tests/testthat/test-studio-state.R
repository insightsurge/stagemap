# The studio's state and its reducer, studio_step(): one event in, the new state and its effects out.

delayedAssign("small", full_map(title = "A map"))

event <- function(type, data = list(), seq = 1L, rev = 0L) list(seq = seq, type = type, data = data, rev = rev)
title_event <- function(value, seq = 2L) event("option", list(name = "title", value = value), seq = seq)

describe("studio_state_new()", {
  it("opens on the given map, with its title, at revision 0 and nothing acknowledged", {
    state <- studio_state_new(small)
    expect_identical(state$map, small)
    expect_identical(state$title, "A map")
    expect_identical(state[c("rev", "ack", "closed")], list(rev = 0L, ack = 0L, closed = FALSE))
    expect_true("notice" %in% names(state))
    expect_null(state$notice)
  })

  it("opens on a map of one card, with no title, when it is given none", {
    state <- studio_state_new()
    expect_s3_class(state$map, "stagemap_widget")
    expect_identical(nrow(sm_widget_data(state$map)$cards), 1L)
    expect_identical(state$title, "")
  })

  it("refuses what is not a stagemap widget", {
    expect_error(studio_state_new(list()), "map")
  })
})

describe("studio_step()", {
  it("acknowledges ready and changes nothing else", {
    state <- studio_state_new(small)
    result <- studio_step(state, event("ready", seq = 4L))
    expect_identical(result$state$ack, 4L)
    expect_identical(result$state[names(state) != "ack"], state[names(state) != "ack"])
    expect_identical(result$effects, list())
  })

  it("takes a title, raises the revision, and keeps it when the same title comes again", {
    first <- studio_step(studio_state_new(small), title_event("Plan B"))$state
    expect_identical(first[c("title", "rev", "ack")], list(title = "Plan B", rev = 1L, ack = 2L))
    again <- studio_step(first, title_event("Plan B", seq = 3L))$state
    expect_identical(again[c("title", "rev", "ack")], list(title = "Plan B", rev = 1L, ack = 3L))
  })

  it("refuses a blank title or one that is not text with a notice, and counts the notices", {
    state <- studio_step(studio_state_new(small), title_event("  "))$state
    expect_identical(state[c("title", "rev", "ack")], list(title = "A map", rev = 0L, ack = 2L))
    expect_identical(state$notice$n, 1L)
    expect_match(state$notice$text, "cannot be blank")
    expect_identical(state$notice$tone, "problem")
    state <- studio_step(state, title_event(NULL, seq = 3L))$state
    expect_identical(state$notice$n, 2L)
    expect_identical(state$title, "A map")
  })

  it("refuses an option other than the title", {
    state <- studio_step(studio_state_new(small), event("option", list(name = "layout", value = "dates")))$state
    expect_match(state$notice$text, "does not change that option")
    expect_identical(state$rev, 0L)
  })

  it("closes on done and hands over the map with the title the studio has", {
    state <- studio_step(studio_state_new(small), title_event("Plan B"))$state
    result <- studio_step(state, event("done", seq = 3L))
    expect_true(result$state$closed)
    expect_length(result$effects, 1L)
    expect_identical(result$effects[[1]]$type, "done")
    expect_s3_class(result$effects[[1]]$map, "stagemap_widget")
    expect_identical(sm_widget_data(result$effects[[1]]$map)$options$title, "Plan B")
  })

  it("hands over the map as it was given when the title has not changed", {
    result <- studio_step(studio_state_new(small), event("done"))
    expect_identical(result$effects[[1]]$map, small)
  })

  it("refuses changes once closed, but still answers ready", {
    closed <- studio_step(studio_state_new(small), event("done"))$state
    refused <- studio_step(closed, title_event("Late"))$state
    expect_identical(refused$title, "A map")
    expect_match(refused$notice$text, "gone back to R")
    expect_null(studio_step(closed, event("ready", seq = 5L))$state$notice)
  })

  it("acknowledges an event it cannot read with a notice that says why, and changes nothing else", {
    state <- studio_state_new(small)
    result <- studio_step(state, list(seq = 6L, type = "ready", data = list()))
    expect_identical(result$state$ack, 6L)
    expect_match(result$state$notice$text, "has no rev")
    expect_identical(result$effects, list())
    # With no seq to read, the acknowledged event stays as it was
    expect_identical(studio_step(state, "nonsense")$state$ack, 0L)
  })

  it("refuses with a notice an event this studio does not take", {
    state <- studio_step(studio_state_new(small), event("undo"))$state
    expect_match(state$notice$text, "does not take a `undo` event", fixed = TRUE)
    expect_identical(state$ack, 1L)
  })

  it("checks the state", {
    expect_error(studio_step(list(1), event("ready")), "state")
  })
})

describe("the step helpers", {
  it("check their arguments", {
    state <- studio_state_new(small)
    expect_error(studio_refuse(state, ""), "text")
    expect_error(studio_step_option(state, list(1)), "data")
    expect_error(studio_step_done(list(1)), "state")
    expect_error(studio_done_map(list(1)), "state")
    expect_error(studio_map_title("map"), "map")
  })
})
