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

    # Step 5: trace downstream (simulated in state$ask until PR 7)
    s$ask <- list(question = "trace", error = NULL)
    s <- studio_tour_tick(s)
    expect_identical(s$tour$done, c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE))

    # Step 6: fix the broken link
    fault_id <- s$check$faults$id[[1L]]
    s <- studio_step(s, event("fix", list(fault = fault_id, fix = "use"), seq = 4L))$state
    expect_identical(s$tour$done, rep(TRUE, 6L))

    # Undo does not untick an already ticked step
    s <- studio_step(s, event("undo", seq = 5L))$state
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
