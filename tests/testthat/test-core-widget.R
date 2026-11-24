describe("sm_widget()", {
  it("makes an htmlwidget whose first class is the binding's name", {
    widget <- sm_widget(map_data())
    expect_identical(class(widget), c("stage_map", "stagemap_widget", "htmlwidget"))
  })

  it("sends a versioned shape: the version, the engine's names, the data as JSON and no look", {
    widget <- sm_widget(map_data())
    expect_identical(names(widget$x), c("v", "engine", "data", "look"))
    expect_identical(widget$x$v, 1L)
    expect_s3_class(widget$x$data, "json")
    expect_null(widget$x$look)
  })

  it("names the engine as the contract does, so the page reads no name from the package's own code", {
    contract <- kit_contract()
    expect_identical(
      sm_widget(map_data())$x$engine,
      list(global = contract$global, prefix = contract$prefix, visual = contract$visual)
    )
  })

  it("writes the data as the engine reads it", {
    parsed <- as_list(sm_widget(map_data())$x$data)
    expect_identical(parsed$options, list(title = "T"))
    expect_identical(parsed$nodes, list(list(id = "a", label = "A", stage = "s", lane = "l")))
  })

  it("sizes by content: full width, and a height of auto", {
    widget <- sm_widget(map_data())
    expect_identical(widget$sizingPolicy$defaultWidth, "100%")
    expect_identical(widget$sizingPolicy$defaultHeight, "auto")
    expect_false(widget$sizingPolicy$viewer$fill)
    expect_false(widget$sizingPolicy$browser$fill)
    expect_false(widget$sizingPolicy$fill)
  })

  it("takes the user's width, height and element id", {
    widget <- sm_widget(map_data(), width = 400, height = "300px", element_id = "map")
    expect_identical(widget$width, 400)
    expect_identical(widget$height, "300px")
    expect_identical(widget$elementId, "map")
  })

  it("keeps the R data and the caller's choices on the widget, out of what the page receives", {
    widget <- sm_widget(map_data(), keep = list(choice = TRUE))
    expect_identical(widget$stagemap$data, map_data())
    expect_identical(widget$stagemap$keep, list(choice = TRUE))
    expect_false(grepl("choice", as.character(htmltools::renderTags(widget)$html), fixed = TRUE))
  })

  it("turns every problem into one classed error that holds them all", {
    bad <- map_data()
    bad$nodes$tone <- "bogus"
    bad$stages$id <- NA
    error <- expect_error(sm_widget(bad), class = "stagemap_error_data")
    expect_length(error$problems, 2L)
  })

  it("lists up to ten problems and counts the rest", {
    bad <- map_data()
    bad$nodes <- data.frame(id = NA_character_, label = NA_character_, stage = NA_character_, lane = NA_character_)
    bad$stages <- data.frame(id = NA_character_, label = NA_character_)
    bad$lanes <- data.frame(id = NA_character_, label = NA_character_)
    bad$options <- list(layout = "bogus", legend = "x", motion = "x", summary = "x")
    bad$links <- data.frame(x = 1)
    bad$kinds <- data.frame(x = 1)
    error <- expect_error(sm_widget(bad), class = "stagemap_error_data")
    expect_gt(length(error$problems), 10L)
    expect_match(conditionMessage(error), sprintf("and %d more", length(error$problems) - 10L))
  })

  it("checks its own arguments", {
    expect_error(sm_widget(1), "data")
    expect_error(sm_widget(map_data(), width = TRUE), "width")
    expect_error(sm_widget(map_data(), keep = 1), "keep")
  })
})

describe("sm_output_tag()", {
  it("makes the markup a render function fills, with the widget's class and id", {
    skip_if_not_installed("shiny")
    html <- as.character(sm_output_tag("map", "100%", "auto"))
    expect_match(html, "id=\"map\"", fixed = TRUE)
    expect_match(html, "stage_map", fixed = TRUE)
    expect_match(html, "html-widget-output", fixed = TRUE)
    expect_no_match(html, "overflow: auto", fixed = TRUE)
  })

  it("takes full width and the height of its content when called with the id alone", {
    skip_if_not_installed("shiny")
    html <- as.character(sm_output_tag("map"))
    expect_match(html, "width:100%", fixed = TRUE)
    expect_match(html, "height:auto", fixed = TRUE)
    expect_no_match(html, "overflow: auto", fixed = TRUE)
  })

  it("makes a fixed height a box that scrolls inside", {
    skip_if_not_installed("shiny")
    expect_match(as.character(sm_output_tag("map", "100%", "300px")), "overflow: auto", fixed = TRUE)
  })

  it("checks its arguments", {
    skip_if_not_installed("shiny")
    expect_error(sm_output_tag(1, "100%", "auto"), "output_id")
    expect_error(sm_output_tag("map", TRUE, "auto"), "width")
  })
})

describe("sm_checked_widget()", {
  it("passes NULL through, so an output can show nothing", {
    skip_if_not_installed("shiny")
    expect_null(sm_checked_widget(NULL))
  })

  it("refuses anything that is not this package's widget", {
    skip_if_not_installed("shiny")
    expect_error(sm_checked_widget(list()), class = "stagemap_error_widget")
    expect_error(sm_checked_widget(htmlwidgets::createWidget("stage_map", list())), "stagemap function")
  })

  it("leaves the widget as it is outside a Shiny session", {
    skip_if_not_installed("shiny")
    widget <- sm_widget(map_data())
    expect_identical(sm_checked_widget(widget), widget)
  })
})

describe("sm_render_widget()", {
  it("makes a render function that takes a quoted expression", {
    skip_if_not_installed("shiny")
    render <- sm_render_widget(quote(sm_widget(map_data())), environment())
    expect_s3_class(render, "shiny.render.function")
  })

  it("lets an output show nothing for NULL", {
    skip_if_not_installed("shiny")
    shiny::testServer(
      function(input, output, session) {
        output$map <- sm_render_widget(quote(NULL), environment())
      },
      {
        expect_no_error(output$map)
      }
    )
  })

  it("counts renders in the session and writes the number into the widget", {
    skip_if_not_installed("shiny")
    shiny::testServer(
      function(input, output, session) {
        again <- shiny::reactiveVal(0)
        output$map <- sm_render_widget(
          quote({
            again()
            sm_widget(map_data())
          }),
          environment()
        )
      },
      {
        stamp <- function() jsonlite::fromJSON(output$map, simplifyVector = FALSE)$x$stamp
        expect_identical(stamp(), 1L)
        again(1)
        session$flushReact()
        expect_identical(stamp(), 2L)
      }
    )
  })

  it("asks the engine to follow the colours of the page in Shiny, unless the widget has a look of its own", {
    skip_if_not_installed("shiny")
    shiny::testServer(
      function(input, output, session) {
        output$plain <- sm_render_widget(quote(sm_widget(map_data())), environment())
        output$dark <- sm_render_widget(
          quote({
            widget <- sm_widget(map_data())
            widget$x$look <- list(mode = "dark")
            widget
          }),
          environment()
        )
      },
      {
        look <- function(id) jsonlite::fromJSON(output[[id]], simplifyVector = FALSE)$x$look
        expect_identical(look("plain"), list(mode = "host"))
        expect_identical(look("dark"), list(mode = "dark"))
      }
    )
  })
})
