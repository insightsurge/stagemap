skip_if_not_installed("shiny")

# The commands a session sent, one per message: the command name, and its data as a list (NULL for no data).
commands <- function(session) {
  session$flush()
  lapply(session$sent, function(sent) {
    list(command = sent$message$command, data = as_list(sent$message$data))
  })
}

# A proxy on a recording session, and the session.
fake_proxy <- function() {
  session <- fake_session()
  list(proxy = sm_proxy("map", session = session), session = session)
}

cards3 <- data.frame(id = c("a", "b", "c"), label = c("A", "B", "C"), stage = "s", lane = "l")

describe("stage_map_output()", {
  it("makes the markup a render function fills, with the widget's class and id", {
    html <- as.character(stage_map_output("map", "100%", "auto"))
    expect_match(html, "id=\"map\"", fixed = TRUE)
    expect_match(html, "stage_map", fixed = TRUE)
    expect_match(html, "html-widget-output", fixed = TRUE)
    expect_no_match(html, "overflow: auto", fixed = TRUE)
  })

  it("takes full width and the height of its content when called with the id alone", {
    html <- as.character(stage_map_output("map"))
    expect_match(html, "width:100%", fixed = TRUE)
    expect_match(html, "height:auto", fixed = TRUE)
    expect_no_match(html, "overflow: auto", fixed = TRUE)
  })

  it("takes the width and the height by position, as DT, plotly and leaflet do", {
    html <- as.character(stage_map_output("map", "50%", "480px"))
    expect_match(html, "width:50%", fixed = TRUE)
    expect_match(html, "height:480px", fixed = TRUE)
  })

  it("makes a fixed height a box that scrolls inside", {
    expect_match(as.character(stage_map_output("map", "100%", "300px")), "overflow: auto", fixed = TRUE)
  })

  it("loads the widget's files with the page", {
    deps <- htmltools::findDependencies(stage_map_output("map"))
    expect_true("stage_map-binding" %in% vapply(deps, function(dep) dep$name, ""))
  })

  it("checks its arguments", {
    expect_error(stage_map_output(1, "100%", "auto"), "output_id")
    expect_error(stage_map_output(""), "output_id")
    expect_error(stage_map_output("map", TRUE, "auto"), "width")
    expect_error(stage_map_output("map", height = TRUE), "height")
  })
})

describe("render_stage_map()", {
  it("makes a render function from an expression, or from a quoted one", {
    expect_s3_class(render_stage_map(stage_map(cards3)), "shiny.render.function")
    expect_s3_class(render_stage_map(quote(stage_map(cards3)), quoted = TRUE), "shiny.render.function")
  })

  it("lets an output show nothing for NULL", {
    shiny::testServer(
      function(input, output, session) {
        output$map <- render_stage_map(NULL)
      },
      {
        expect_no_error(output$map)
      }
    )
  })

  it("draws the map the expression gives, in the environment given", {
    shiny::testServer(
      function(input, output, session) {
        scope <- new.env()
        scope$cards <- cards3
        output$map <- render_stage_map(stage_map(cards), env = scope)
      },
      {
        x <- jsonlite::fromJSON(output$map, simplifyVector = FALSE)$x
        expect_length(x$data$cards, 3L)
      }
    )
  })

  it("counts renders in the session and writes the number into the widget", {
    shiny::testServer(
      function(input, output, session) {
        again <- shiny::reactiveVal(0)
        output$map <- render_stage_map({
          again()
          stage_map(cards3)
        })
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
    shiny::testServer(
      function(input, output, session) {
        output$plain <- render_stage_map(stage_map(cards3))
        output$dark <- render_stage_map({
          widget <- stage_map(cards3)
          widget$x$look <- list(mode = "dark")
          widget
        })
      },
      {
        look <- function(id) jsonlite::fromJSON(output[[id]], simplifyVector = FALSE)$x$look
        expect_identical(look("plain"), list(mode = "host"))
        expect_identical(look("dark"), list(mode = "dark"))
      }
    )
  })

  it("refuses anything but this package's widget, with the class stagemap_error_widget", {
    shiny::testServer(
      function(input, output, session) {
        output$map <- render_stage_map(data.frame(a = 1))
      },
      {
        expect_error(output$map, class = "stagemap_error_widget")
      }
    )
  })

  it("draws a map that arrives as a promise, stamped in the session, and refuses a promise of something else", {
    skip_if_not_installed("promises")
    shiny::testServer(
      function(input, output, session) {
        output$late <- render_stage_map(promises::promise_resolve(stage_map(cards3)))
        output$wrong <- render_stage_map(promises::promise_resolve(data.frame(a = 1)))
      },
      {
        expect_identical(jsonlite::fromJSON(output$late, simplifyVector = FALSE)$x$stamp, 1L)
        expect_identical(
          jsonlite::fromJSON(output$late, simplifyVector = FALSE)$x$look,
          list(mode = "host")
        )
        expect_error(output$wrong, class = "stagemap_error_widget")
      }
    )
  })

  it("checks its arguments", {
    expect_error(render_stage_map(NULL, env = 1), "env")
    expect_error(render_stage_map(NULL, quoted = "yes"), "quoted")
  })
})

describe("stage_map_proxy()", {
  it("makes a proxy from the id and the session, as positional calls", {
    session <- fake_session()
    proxy <- stage_map_proxy("map", session)
    expect_s3_class(proxy, "stagemap_proxy")
    expect_identical(proxy$id, "mod-map")
    expect_identical(proxy$session, session)
    expect_true(proxy$defer)
  })

  it("takes defer_until_flush by name only", {
    expect_false(stage_map_proxy("map", fake_session(), defer_until_flush = FALSE)$defer)
    expect_error(stage_map_proxy("map", fake_session(), FALSE), class = "stagemap_error_dots")
  })

  it("takes the current session by default, and the plain or the namespaced id in a module", {
    shiny::testServer(
      function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          session$userData$ids <- c(stage_map_proxy("map")$id, stage_map_proxy(session$ns("map"))$id)
          session$userData$prefix <- session$ns("")
        })
      },
      {
        expect_identical(session$userData$ids, paste0(session$userData$prefix, c("map", "map")))
      },
      args = list(id = "inner")
    )
  })

  it("checks its arguments, and says it needs a session outside the server", {
    expect_error(stage_map_proxy(1, fake_session()), "output_id")
    expect_error(stage_map_proxy("", fake_session()), "output_id")
    expect_error(stage_map_proxy("map", NULL), "session")
    expect_error(stage_map_proxy("map"), "session")
    expect_error(stage_map_proxy("map", fake_session(), defer_until_flush = NA), "defer_until_flush")
  })
})

describe("stage_map_select()", {
  it("sends the cards as one command, the last as the lead, and returns the proxy invisibly", {
    p <- fake_proxy()
    expect_invisible(result <- stage_map_select(p$proxy, c("a", "b")))
    expect_identical(result, p$proxy)
    expect_identical(
      commands(p$session),
      list(list(command = "select", data = list(kind = "card", ids = list("a", "b"))))
    )
  })

  it("sends one id as a list of one", {
    p <- fake_proxy()
    stage_map_select(p$proxy, "a")
    expect_identical(commands(p$session)[[1]]$data$ids, list("a"))
  })

  it("lets go for NULL and for a vector of length zero: the command goes with no data", {
    for (none in list(NULL, character(), integer(), list())) {
      p <- fake_proxy()
      stage_map_select(p$proxy, none)
      expect_identical(commands(p$session), list(list(command = "select", data = NULL)))
    }
  })

  it("takes whole numbers as text, and the same id once", {
    p <- fake_proxy()
    stage_map_select(p$proxy, c(7, 100000, 7))
    expect_identical(commands(p$session)[[1]]$data$ids, list("7", "100000"))
    p <- fake_proxy()
    stage_map_select(p$proxy, 3L)
    expect_identical(commands(p$session)[[1]]$data$ids, list("3"))
  })

  it("has no default for ids, so a forgotten argument is an error and never a clear", {
    p <- fake_proxy()
    expect_error(stage_map_select(p$proxy), "ids")
    expect_length(p$session$flush_callbacks, 0L)
  })

  it("refuses ids that are not text or whole numbers, or have a missing one or a blank", {
    p <- fake_proxy()
    expect_error(stage_map_select(p$proxy, 1.5), "ids")
    expect_error(stage_map_select(p$proxy, TRUE), "ids")
    expect_error(stage_map_select(p$proxy, NA), "ids")
    expect_error(stage_map_select(p$proxy, c("a", NA)), "ids")
    expect_error(stage_map_select(p$proxy, ""), "ids")
    expect_error(stage_map_select(p$proxy, list("a")), "ids")
    expect_length(p$session$flush_callbacks, 0L)
  })

  it("stops with stagemap_error_widget for a widget, naming the proxy to use", {
    error <- expect_error(stage_map_select(stage_map(cards3), "a"), class = "stagemap_error_widget")
    expect_match(conditionMessage(error), "stage_map_proxy", fixed = TRUE)
    expect_identical(error$call[[1]], quote(stage_map_select))
  })

  it("stops with stagemap_error_widget for anything else as the map", {
    error <- expect_error(stage_map_select("map", "a"), class = "stagemap_error_widget")
    expect_match(conditionMessage(error), "character", fixed = TRUE)
    expect_error(stage_map_select(NULL, "a"), class = "stagemap_error_widget")
  })

  it("checks the map before the ids", {
    expect_error(stage_map_select("map", NA), class = "stagemap_error_widget")
  })

  it("stamps the command with the revision of the reader's choice that R has seen", {
    session <- fake_session(input = list(map_stagemap_revision = 4L))
    stage_map_select(sm_proxy("map", session = session), "a")
    session$flush()
    expect_identical(session$sent[[1]]$message$revision, 4L)
  })
})

describe("stage_map_highlight() on a proxy", {
  it("sends the ids as one command, and returns the proxy invisibly", {
    p <- fake_proxy()
    expect_invisible(result <- stage_map_highlight(p$proxy, c("a", "b")))
    expect_identical(result, p$proxy)
    expect_identical(commands(p$session), list(list(command = "highlight", data = list(ids = list("a", "b")))))
  })

  it("sends links as rows of from, to and kind, with both ends among the ids", {
    p <- fake_proxy()
    links <- data.frame(from = c("a", "b"), to = c("b", "c"), kind = c("hand", NA))
    stage_map_highlight(p$proxy, c("a", "b", "c"), links = links)
    sent <- commands(p$session)[[1]]$data
    expect_identical(
      sent$links,
      list(list(from = "a", to = "b", kind = "hand"), list(from = "b", to = "c", kind = NULL))
    )
  })

  it("leaves the kind out when no link has one, and takes ids and ends given as numbers", {
    p <- fake_proxy()
    stage_map_highlight(p$proxy, c(1, 2), links = data.frame(from = 1, to = 2, kind = NA))
    expect_identical(commands(p$session)[[1]]$data$links, list(list(from = "1", to = "2")))
  })

  it("lets go for NULL and for a vector of length zero", {
    for (none in list(NULL, character(), integer())) {
      p <- fake_proxy()
      stage_map_highlight(p$proxy, none)
      expect_identical(commands(p$session), list(list(command = "highlight", data = NULL)))
    }
  })

  it("takes links with no rows as none, also with no ids, so the state's empty links go back as they are", {
    none <- data.frame(from = character(), to = character(), kind = character())
    p <- fake_proxy()
    stage_map_highlight(p$proxy, c("a", "b"), links = none)
    stage_map_highlight(p$proxy, character(), links = none)
    stage_map_highlight(p$proxy, character(), links = data.frame())
    sent <- commands(p$session)
    expect_identical(sent[[1]]$data, list(ids = list("a", "b")))
    expect_null(sent[[2]]$data)
    expect_null(sent[[3]]$data)
  })

  it("refuses links with no ids, and a link whose end is not among the ids, with stagemap_error_data", {
    p <- fake_proxy()
    links <- data.frame(from = "a", to = "b")
    error <- expect_error(stage_map_highlight(p$proxy, NULL, links = links), class = "stagemap_error_data")
    expect_match(conditionMessage(error), "ids", fixed = TRUE)
    error <- expect_error(stage_map_highlight(p$proxy, c("a"), links = links), class = "stagemap_error_data")
    expect_match(conditionMessage(error), "\"b\"", fixed = TRUE)
    expect_length(p$session$flush_callbacks, 0L)
  })

  it("checks the columns and the type of links, and that it has no stray arguments", {
    p <- fake_proxy()
    expect_error(stage_map_highlight(p$proxy, "a", links = data.frame(from = "a")), "links")
    expect_error(stage_map_highlight(p$proxy, "a", links = "a"), "links")
    expect_error(stage_map_highlight(p$proxy, "a", data.frame(from = "a", to = "a")), class = "stagemap_error_dots")
    expect_error(
      stage_map_highlight(p$proxy, "a", links = data.frame(from = NA_character_, to = "a")),
      "links"
    )
  })

  it("has no default for ids", {
    expect_error(stage_map_highlight(fake_proxy()$proxy), "ids")
  })

  it("stops with stagemap_error_widget for something that is neither a proxy nor a widget", {
    expect_error(stage_map_highlight(list(), "a"), class = "stagemap_error_widget")
  })
})

describe("stage_map_highlight() on a widget", {
  data_highlight <- function(map) data_of(map)$options$highlight

  it("sets what is lit from the first draw, with ids as text, and returns the widget", {
    map <- stage_map_highlight(stage_map(cards3), c("a", "b"))
    expect_s3_class(map, "stagemap_widget")
    expect_identical(data_highlight(map), list(ids = list("a", "b")))
  })

  it("sends links as rows", {
    map <- stage_map(cards3) |>
      add_links(
        data.frame(from = c("a", "b"), to = c("b", "c"), kind = c("hand", "hand")),
        kinds = data.frame(id = "hand", label = "H")
      ) |>
      stage_map_highlight(c("a", "b"), links = data.frame(from = "a", to = "b", kind = "hand"))
    expect_identical(
      data_highlight(map),
      list(ids = list("a", "b"), links = list(list(from = "a", to = "b", kind = "hand")))
    )
  })

  it("takes ids given as numbers for cards whose ids are numbers", {
    map <- stage_map(data.frame(id = 1:2, label = c("A", "B"), stage = "s", lane = "l"))
    expect_identical(data_highlight(stage_map_highlight(map, c(1, 2))), list(ids = list("1", "2")))
  })

  it("replaces what an earlier call lit, and lets go for no ids", {
    map <- stage_map_highlight(stage_map(cards3), c("a", "b"))
    expect_identical(data_highlight(stage_map_highlight(map, "c")), list(ids = list("c")))
    expect_null(data_highlight(stage_map_highlight(map, NULL)))
    expect_null(data_highlight(stage_map_highlight(map, character())))
  })

  it("keeps the rest of the map: its layers, its size and its element id, and what a later layer adds", {
    map <- stage_map(cards3, height = 300, element_id = "mine", panels = FALSE) |>
      stage_map_highlight("a") |>
      add_links(data.frame(from = "a", to = "b"))
    expect_identical(map$elementId, "mine")
    expect_identical(map$height, 300)
    expect_identical(data_highlight(map), list(ids = list("a")))
    expect_length(data_of(map)$links, 1L)
    expect_true(all(c("details", "stage", "zones") %in% hosted_of(map)))
  })

  it("checks the ids against the map, with stagemap_error_id, naming the ones it lacks", {
    error <- expect_error(stage_map_highlight(stage_map(cards3), c("a", "ghost", "x")), class = "stagemap_error_id")
    expect_match(conditionMessage(error), "ghost", fixed = TRUE)
    expect_match(conditionMessage(error), "x", fixed = TRUE)
    expect_identical(error$call[[1]], quote(stage_map_highlight))
  })

  it("refuses an NA among the ids and a link that leaves the ids, with the same errors as for a proxy", {
    map <- stage_map(cards3)
    expect_error(stage_map_highlight(map, c("a", NA)), "ids")
    expect_error(
      stage_map_highlight(map, "a", links = data.frame(from = "a", to = "b")),
      class = "stagemap_error_data"
    )
  })

  it("does not warn about names the map already dropped", {
    map <- stage_map(cards3, statuses = c(done = "Pass"))
    expect_no_warning(stage_map_highlight(map, "a"))
  })
})

describe("stage_map_show(), stage_map_hide() and stage_map_enable()", {
  it("send one command for each id, in order", {
    for (verb in c("show", "hide", "enable")) {
      p <- fake_proxy()
      expect_invisible(result <- get(paste0("stage_map_", verb))(p$proxy, c("a", "b", "c")))
      expect_identical(result, p$proxy)
      expect_identical(
        commands(p$session),
        lapply(c("a", "b", "c"), function(id) list(command = verb, data = list(id = id))),
        info = verb
      )
    }
  })

  it("do nothing for NULL and for a vector of length zero", {
    for (verb in c("show", "hide", "enable")) {
      p <- fake_proxy()
      get(paste0("stage_map_", verb))(p$proxy, NULL)
      get(paste0("stage_map_", verb))(p$proxy, character())
      expect_length(p$session$flush_callbacks, 0L)
      expect_length(p$session$sent, 0L)
    }
  })

  it("take whole numbers as text and send a repeated id once", {
    p <- fake_proxy()
    stage_map_hide(p$proxy, c(7, 7, 8))
    expect_identical(vapply(commands(p$session), function(x) x$data$id, ""), c("7", "8"))
  })

  it("have no default for ids, and refuse a missing one", {
    p <- fake_proxy()
    for (verb in c("show", "hide", "enable")) {
      expect_error(get(paste0("stage_map_", verb))(p$proxy), "ids", info = verb)
      expect_error(get(paste0("stage_map_", verb))(p$proxy, NA), "ids", info = verb)
    }
  })

  it("stop with stagemap_error_widget for a widget", {
    map <- stage_map(cards3)
    expect_error(stage_map_show(map, "a"), class = "stagemap_error_widget")
    expect_error(stage_map_hide(map, "a"), class = "stagemap_error_widget")
    expect_error(stage_map_enable(map, "a"), class = "stagemap_error_widget")
    expect_error(stage_map_hide("a", "a"), class = "stagemap_error_widget")
  })

  it("send 5000 ids as 5000 commands, in a flush", {
    p <- fake_proxy()
    ids <- sprintf("card-%d", seq_len(5000))
    stage_map_hide(p$proxy, ids)
    expect_length(p$session$flush_callbacks, 1L)
    p$session$flush()
    expect_length(p$session$sent, 5000L)
  })
})

describe("stage_map_disable()", {
  it("sends one command for each id with the reason, and returns the proxy invisibly", {
    p <- fake_proxy()
    expect_invisible(result <- stage_map_disable(p$proxy, c("a", "b"), "Waiting for review"))
    expect_identical(result, p$proxy)
    expect_identical(
      commands(p$session),
      list(
        list(command = "disable", data = list(id = "a", reason = "Waiting for review")),
        list(command = "disable", data = list(id = "b", reason = "Waiting for review"))
      )
    )
  })

  it("takes one reason for each id", {
    p <- fake_proxy()
    stage_map_disable(p$proxy, c("a", "b"), c("No data", "Not started"))
    expect_identical(
      vapply(commands(p$session), function(x) x$data$reason, ""),
      c("No data", "Not started")
    )
  })

  it("refuses reasons that are not one, or one for each id", {
    p <- fake_proxy()
    expect_error(stage_map_disable(p$proxy, c("a", "b", "c"), c("x", "y")), "reason")
    expect_error(stage_map_disable(p$proxy, NULL, c("x", "y")), "reason")
    expect_length(p$session$flush_callbacks, 0L)
  })

  it("refuses a reason that is blank after trimming, missing or not text, and has no default for it", {
    p <- fake_proxy()
    expect_error(stage_map_disable(p$proxy, "a", ""), "reason")
    expect_error(stage_map_disable(p$proxy, "a", "  \t "), "reason")
    expect_error(stage_map_disable(p$proxy, c("a", "b"), c("fine", " ")), "reason")
    expect_error(stage_map_disable(p$proxy, "a", NA_character_), "reason")
    expect_error(stage_map_disable(p$proxy, "a", 1), "reason")
    expect_error(stage_map_disable(p$proxy, "a", character()), "reason")
    expect_error(stage_map_disable(p$proxy, "a"), "reason")
    expect_length(p$session$flush_callbacks, 0L)
  })

  it("does nothing for no ids, but still wants a reason", {
    p <- fake_proxy()
    stage_map_disable(p$proxy, NULL, "x")
    stage_map_disable(p$proxy, character(), "x")
    expect_length(p$session$flush_callbacks, 0L)
    expect_error(stage_map_disable(p$proxy, NULL), "reason")
  })

  it("has no default for ids, and stops with stagemap_error_widget for a widget", {
    expect_error(stage_map_disable(fake_proxy()$proxy, reason = "x"), "ids")
    expect_error(stage_map_disable(stage_map(cards3), "a", "x"), class = "stagemap_error_widget")
  })
})

describe("the verbs together", {
  it("pipe, and send their commands in call order in one flush", {
    p <- fake_proxy()
    p$proxy |>
      stage_map_select("a") |>
      stage_map_highlight(c("a", "b")) |>
      stage_map_hide("c") |>
      stage_map_disable("b", "No") |>
      stage_map_enable("b") |>
      stage_map_show("c")
    expect_length(p$session$flush_callbacks, 1L)
    expect_identical(
      vapply(commands(p$session), function(x) x$command, ""),
      c("select", "highlight", "hide", "disable", "enable", "show")
    )
  })

  it("send commands the engine's contract lists, and never warn", {
    p <- fake_proxy()
    expect_no_warning({
      stage_map_select(p$proxy, "a")
      stage_map_highlight(p$proxy, "a")
      stage_map_show(p$proxy, "a")
      stage_map_hide(p$proxy, "a")
      stage_map_enable(p$proxy, "a")
      stage_map_disable(p$proxy, "a", "x")
    })
    expect_true(all(vapply(commands(p$session), function(x) x$command, "") %in% sm_spec()$commands))
  })

  it("name the verb a user called in a warning about a command", {
    local_spec(list(commands = "select"))
    p <- fake_proxy()
    warning <- expect_warning(stage_map_hide(p$proxy, "a"), class = "stagemap_warning_command")
    expect_identical(warning$call[[1]], quote(stage_map_hide))
  })
})
