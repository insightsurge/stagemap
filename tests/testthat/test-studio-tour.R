# Guided tour proofs and sticky ticking.

event <- function(type, data = structure(list(), names = character()), seq = 1L, rev = 0L) {
  list(seq = seq, type = type, data = data, rev = rev)
}

describe("studio_tours and studio_tour_tick()", {
  it("ticks the six example steps in order and none early, and keeps ticked steps ticked", {
    s <- studio_state_new()
    expect_identical(s$tour$id, "example")
    expect_identical(s$tour$done, c(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE))

    # Step 2: round_dose() status to done
    uid_round <- studio_uid_of(s$doc, "cards", "round_dose")
    s <- studio_step(
      s,
      event("edit", list(table = "cards", uid = uid_round, field = "status", value = "done"), seq = 1L)
    )$state
    expect_identical(s$tour$done, c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE))

    # Step 3: connect Log every call to calc_dose()
    uid_log <- studio_uid_of(s$doc, "cards", "log_calls")
    uid_calc <- studio_uid_of(s$doc, "cards", "calc_dose")
    s <- studio_step(s, event("link_add", list(from = uid_log, to = uid_calc, kind = NULL), seq = 2L))$state
    expect_identical(s$tour$done, c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE))

    # Step 4: open R code
    s <- studio_step(s, event("seen", list(what = "code"), seq = 3L))$state
    expect_identical(s$tour$done, c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE))

    # Step 5: fix the broken link (questions refuse a map that does not build, so this comes before the trace)
    fault_id <- s$check$faults$id[[1L]]
    s <- studio_step(s, event("fix", list(fault = fault_id, fix = "use"), seq = 4L))$state
    expect_identical(s$tour$done, c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE))

    # Step 6: trace downstream of Doses scale with weight, through the Ask event. A trace from another card, or one
    # upstream, does not tick it.
    uid_log <- studio_uid_of(s$doc, "cards", "log_calls")
    other <- studio_step(s, event("ask", list(question = "trace", ids = list(uid_log)), seq = 5L))$state
    expect_false(other$tour$done[[6L]])
    uid_scale <- studio_uid_of(s$doc, "cards", "scale_weight")
    upstream <- studio_step(
      s,
      event("ask", list(question = "trace", ids = list(uid_scale), direction = "upstream"), seq = 5L)
    )$state
    expect_false(upstream$tour$done[[6L]])
    s <- studio_step(s, event("ask", list(question = "trace", ids = list(uid_scale)), seq = 5L))$state
    expect_identical(s$tour$done, rep(TRUE, 6L))

    # Undo does not untick an already ticked step
    s <- studio_step(s, event("undo", seq = 6L))$state
    expect_identical(s$tour$done, rep(TRUE, 6L))
  })

  it("does nothing when there is no tour or the tour id is unknown, and checks its argument", {
    s <- studio_state_new(full_map())
    expect_null(s$tour)
    expect_identical(studio_tour_tick(s), s)

    s$tour <- list(id = "missing", done = logical())
    expect_identical(studio_tour_tick(s), s)

    expect_error(studio_tour_tick("state"), "state")
  })
})

describe("studio_tour_view()", {
  it("is NULL without a guide or with an unknown one", {
    s <- studio_state_new(full_map())
    expect_null(studio_tour_view(s))
    s$tour <- list(id = "missing", done = logical())
    expect_null(studio_tour_view(s))
    expect_error(studio_tour_view("state"), "state")
  })

  it("lists the steps with their state and the first one not done", {
    s <- studio_state_new()
    view <- studio_tour_view(s)
    expect_named(view, c("title", "steps", "next"))
    expect_identical(view$title, "Try the studio")
    expect_length(view$steps, 6L)
    expect_named(view$steps[[1L]], c("text", "done"))
    expect_identical(vapply(view$steps, function(step) step$done, logical(1)), c(TRUE, rep(FALSE, 5L)))
    expect_identical(view$steps[[1L]]$text, "Open the example map.")
    expect_identical(view$`next`, 2L)

    s$tour$done <- c(TRUE, TRUE, FALSE, TRUE, TRUE, TRUE)
    expect_identical(studio_tour_view(s)$`next`, 3L)
  })

  it("has no next step once every step is done, and is a section of the view", {
    s <- studio_state_new()
    s$tour$done <- rep(TRUE, 6L)
    view <- studio_tour_view(s)
    expect_null(view$`next`)
    expect_true("next" %in% names(view))
    expect_true(all(vapply(view$steps, function(step) step$done, logical(1))))
    expect_identical(studio_view(s)$tour, view)
    expect_true("tour" %in% names(studio_view(studio_state_new(full_map()))))
    expect_null(studio_view(studio_state_new(full_map()))$tour)
  })
})
