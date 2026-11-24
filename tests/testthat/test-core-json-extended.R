skip_unless_extended() # reaches into a Shiny function that is not exported, so it runs only with the extended tests

describe("convert_json()", {
  it("is embedded as it is by Shiny's own serialiser", {
    skip_if_not_installed("shiny")
    to_json <- get("toJSON", envir = asNamespace("shiny"))
    sent <- to_json(list(data = convert_json(list(rows = rows()), made_up)))
    expect_identical(unclass(sent), "{\"data\":{\"rows\":[{\"id\":\"x\"},{\"id\":\"y\"}]}}")
  })
})
