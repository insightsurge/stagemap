# The core's data layers, with made-up fields: the spec's fields are invented, so nothing here depends on what the
# stage map takes.
made_up_fields <- list(
  rows = field("list", TRUE, fields = list(id = field("string", TRUE))),
  extra = field("list", fields = list(id = field("string", TRUE))),
  options = field("object", fields = list(note = field("string"), flag = field("boolean")))
)

describe("sm_add_data()", {
  local_spec(list(fields = made_up_fields))
  widget <- function() sm_widget(list(rows = data.frame(id = "a")))
  data_of <- function(x) jsonlite::fromJSON(unclass(x$x$data), simplifyVector = FALSE)

  it("adds a field and an option, and builds the widget again", {
    added <- sm_add_data(widget(), list(extra = data.frame(id = "b")), options = list(note = "N"))
    expect_identical(data_of(added)$extra, list(list(id = "b")))
    expect_identical(data_of(added)$options, list(note = "N"))
    expect_identical(sm_widget_data(added)$extra, data.frame(id = "b"))
  })

  it("adds nothing for a NULL value", {
    added <- sm_add_data(widget(), list(extra = NULL), options = list(note = NULL))
    expect_identical(added$x$data, widget()$x$data)
  })

  it("refuses a field or an option the engine does not take", {
    expect_error(sm_add_data(widget(), list(other = data.frame(id = "b"))), class = "stagemap_error_layer")
    expect_error(sm_add_data(widget(), list(), options = list(colour = "red")), class = "stagemap_error_layer")
  })

  it("refuses a field the widget already has", {
    once <- sm_add_data(widget(), list(extra = data.frame(id = "b")))
    error <- expect_error(sm_add_data(once, list(extra = data.frame(id = "c"))), class = "stagemap_error_layer")
    expect_match(conditionMessage(error), "already has", fixed = TRUE)
    expect_error(sm_add_data(widget(), list(rows = data.frame(id = "c"))), class = "stagemap_error_layer")
  })

  it("carries the caller's kept choices over to the widget it builds again", {
    kept <- sm_widget(list(rows = data.frame(id = "a")), keep = list(choice = TRUE))
    added <- sm_add_data(kept, list(extra = data.frame(id = "b")))
    expect_identical(added$stagemap$keep, list(choice = TRUE))
    expect_identical(widget()$stagemap$keep, list())
  })

  it("refuses something that is not a stagemap widget", {
    expect_error(sm_add_data(list(), list(extra = data.frame(id = "b"))), class = "stagemap_error_widget")
  })

  it("keeps the size and element id when it builds the widget again", {
    sized <- sm_widget(list(rows = data.frame(id = "a")), width = "50%", height = 300, element_id = "w")
    added <- sm_add_data(sized, list(extra = data.frame(id = "b")))
    expect_identical(c(added$width, added$elementId), c("50%", "w"))
    expect_identical(added$height, 300)
  })

  it("warns once about a column the engine lacks, when the data comes in", {
    expect_warning(
      sm_add_data(widget(), list(extra = data.frame(id = "b", n = 1))),
      class = "stagemap_warning_unused_columns"
    )
  })
})

describe("sm_rebuild()", {
  it("does not repeat a warning about columns the first build already gave", {
    local_spec(list(fields = made_up_fields))
    expect_warning(
      widget <- sm_widget(list(rows = data.frame(id = "a", n = 1))),
      class = "stagemap_warning_unused_columns"
    )
    expect_no_warning(sm_rebuild(widget, sm_widget_data(widget)))
  })
})

describe("sm_add_data() with the stage map's own fields", {
  it("adds links and an option to a real map, and the page receives them", {
    added <- sm_add_data(
      sm_widget(map_data()),
      list(links = data.frame(from = "a", to = "a")),
      options = list(dismiss = "no_outside")
    )
    parsed <- as_list(added$x$data)
    expect_identical(parsed$links, list(list(from = "a", to = "a")))
    expect_identical(parsed$options$dismiss, "no_outside")
    expect_identical(parsed$options$title, "T")
  })
})

describe("sm_add_data() and the options", {
  it("warns once about a name the engine lacks inside the options it adds", {
    warning <- expect_warning(
      sm_add_data(sm_widget(map_data()), list(), options = list(statuses = list(done = "P", bogus = "x"))),
      class = "stagemap_warning_unused_columns"
    )
    expect_identical(warning$dropped, list("options$statuses" = "bogus"))
    expect_match(conditionMessage(warning), "Dropped `bogus` from `options$statuses`", fixed = TRUE)
  })

  it("adds to a widget whose options were given as a named vector, and keeps both", {
    widget <- map_data()
    widget$options <- c(title = "T")
    added <- sm_add_data(sm_widget(widget), list(), options = list(sub = "S"))
    expect_identical(as_list(added$x$data)$options, list(title = "T", sub = "S"))
    expect_identical(sm_widget_data(added)$options, list(title = "T", sub = "S"))
  })

  it("refuses an option the widget already has, also when it was given as a named vector", {
    widget <- map_data()
    widget$options <- c(title = "T")
    expect_error(
      sm_add_data(sm_widget(widget), list(), options = list(title = "U")),
      class = "stagemap_error_layer"
    )
  })
})
