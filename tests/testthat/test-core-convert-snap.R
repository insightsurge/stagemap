# Snapshots of the messages a person reads when their data is wrong. They skip on CRAN by themselves.
describe("the data error", {
  it("lists problems with their paths", {
    data <- map_data()
    data$nodes <- data.frame(id = c("a", NA), label = "A", stage = "s", lane = "l", tone = c("good", "bogus"))
    data$stages <- data.frame(id = "s")
    expect_snapshot(sm_widget(data), error = TRUE)
  })

  it("counts the problems beyond the first ten", {
    missing_all <- data.frame(id = NA_character_, label = NA_character_)
    data <- map_data()
    data$nodes <- data.frame(
      id = NA_character_,
      label = NA_character_,
      stage = NA_character_,
      lane = NA_character_,
      tone = "bogus",
      milestone = "x",
      disabled = "x"
    )
    data$stages <- missing_all
    data$lanes <- missing_all
    expect_snapshot(sm_widget(data), error = TRUE)
  })
})

describe("the warning about names the engine lacks", {
  it("names the dropped name and the valid ones", {
    data <- map_data()
    data$options$statuses <- c(done = "Pass", bogus = "x")
    expect_snapshot(invisible(sm_widget(data)))
  })

  it("names a misspelt option and says nothing of an extra column beside it", {
    data <- map_data()
    data$nodes$n <- 1
    data$options$statuses <- c(done = "Pass", bogus = "x")
    expect_snapshot(invisible(sm_widget(data)))
  })
})
