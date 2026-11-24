# Snapshots of the messages a person reads when a command goes wrong. They skip on CRAN by themselves.
describe("the dots error", {
  it("names a typo and an unnamed value, and lists the valid arguments", {
    skip_if_not_installed("shiny")
    expect_snapshot(sm_send(sm_proxy("map", session = fake_session()), "select", dat = "x", 3), error = TRUE)
  })
})

describe("the unknown-command warning", {
  it("lists the commands the contract has", {
    skip_if_not_installed("shiny")
    expect_snapshot(sm_send(sm_proxy("map", session = fake_session()), "selct"))
  })
})
