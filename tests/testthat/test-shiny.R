skip_if_not_installed("shiny")

describe("sm_proxy()", {
  it("is a value object that holds the namespaced id, the session and the flush choice", {
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    expect_s3_class(proxy, "stagemap_proxy")
    expect_identical(proxy$id, "mod-map")
    expect_identical(proxy$session, session)
    expect_true(proxy$defer)
  })

  it("does not add the namespace twice when the id already has it", {
    session <- fake_session()
    expect_identical(sm_proxy("map", session = session)$id, sm_proxy(session$ns("map"), session = session)$id)
  })

  it("leaves the id alone in a session with no namespace", {
    expect_identical(sm_proxy("map", session = fake_session(prefix = ""))$id, "map")
  })

  it("follows Shiny's own namespace in a module, plain or already namespaced", {
    shiny::testServer(
      function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          session$userData$ids <- c(sm_proxy("map")$id, sm_proxy(session$ns("map"))$id)
          session$userData$prefix <- session$ns("")
        })
      },
      {
        expect_identical(session$userData$ids, paste0(session$userData$prefix, c("map", "map")))
        expect_match(session$userData$ids[1], "-map$")
      },
      args = list(id = "inner")
    )
  })

  it("waits for the flush by default, and not when asked", {
    expect_true(sm_proxy("map", session = fake_session())$defer)
    expect_false(sm_proxy("map", session = fake_session(), defer_until_flush = FALSE)$defer)
  })

  it("prints and formats itself", {
    proxy <- sm_proxy("map", session = fake_session())
    expect_identical(format(proxy), c("<stagemap_proxy>", "  id: mod-map"))
    expect_output(print(proxy), "<stagemap_proxy>", fixed = TRUE)
  })

  it("checks its arguments", {
    expect_error(sm_proxy(1, session = fake_session()), "id")
    expect_error(sm_proxy("", session = fake_session()), "id")
    expect_error(sm_proxy("map", session = NULL), "session")
    expect_error(sm_proxy("map", session = fake_session(), defer_until_flush = "yes"), "defer_until_flush")
  })
})

describe("sm_send()", {
  it("sends nothing until the flush, then every command in call order", {
    # Given two commands in one observer
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    sm_send(proxy, "select", data = list(kind = "card", id = "a"))
    sm_send(proxy, "history")
    # Then nothing has left, and one flush callback is waiting
    expect_length(session$sent, 0L)
    expect_length(session$flush_callbacks, 1L)
    expect_identical(session$flush_requests, 1L)
    # When the flush happens
    session$flush()
    # Then both leave in order, as one custom message each
    expect_identical(vapply(session$sent, function(m) m$type, ""), c("stagemap:command", "stagemap:command"))
    expect_identical(vapply(session$sent, function(m) m$message$command, ""), c("select", "history"))
    expect_identical(unclass(session$sent[[1]]$message$data), "{\"kind\":\"card\",\"id\":\"a\"}")
    expect_identical(session$sent[[1]]$message$id, "mod-map")
  })

  it("starts a new batch after a flush", {
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    sm_send(proxy, "history")
    session$flush()
    sm_send(proxy, "history")
    session$flush()
    expect_length(session$sent, 2L)
  })

  it("returns the proxy invisibly, so calls pipe", {
    proxy <- sm_proxy("map", session = fake_session())
    expect_invisible(result <- sm_send(proxy, "history"))
    expect_identical(result, proxy)
  })

  it("stamps each command with the latest revision of the reader's choice that R has seen", {
    session <- fake_session(input = list(map_selected = list(revision = 3L, by = "reader")))
    proxy <- sm_proxy("map", session = session)
    sm_send(proxy, "select", data = list(kind = "card", id = "a"))
    session$flush()
    expect_identical(session$sent[[1]]$message$revision, 3L)
  })

  it("counts revision 0 when the reader has chosen nothing", {
    session <- fake_session()
    sm_send(sm_proxy("map", session = session), "select")
    session$flush()
    expect_identical(session$sent[[1]]$message$revision, 0L)
  })

  it("reads the revision under the name the module sees", {
    session <- fake_session(prefix = "mod-", input = list(map_selected = list(revision = 2L)))
    sm_send(sm_proxy("map", session = session), "select")
    session$flush()
    expect_identical(session$sent[[1]]$message$revision, 2L)
  })

  it("sends at once, past the flush, for a proxy made with defer_until_flush = FALSE", {
    session <- fake_session()
    sm_send(sm_proxy("map", session = session, defer_until_flush = FALSE), "select")
    expect_length(session$sent, 1L)
    expect_length(session$flush_callbacks, 0L)
    expect_identical(session$sent[[1]]$type, "stagemap:command")
  })

  it("sends every command the contract lists, among them the ones the package relies on", {
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    for (command in kit_relied_on$commands) {
      expect_no_warning(sm_send(proxy, command))
    }
    session$flush()
    expect_identical(vapply(session$sent, function(m) m$message$command, ""), kit_relied_on$commands)
  })

  it("warns and sends nothing for a command the contract does not list", {
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    warning <- expect_warning(sm_send(proxy, "selct"), class = "stagemap_warning_command")
    expect_match(conditionMessage(warning), "Commands it takes: .*select")
    expect_length(session$flush_callbacks, 0L)
  })

  it("follows the contract's list, not one of its own", {
    local_spec(list(commands = c("select", "hosted")))
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    sm_send(proxy, "select")
    expect_warning(sm_send(proxy, "history"), class = "stagemap_warning_command")
    session$flush()
    expect_identical(vapply(session$sent, function(m) m$message$command, ""), "select")
  })

  it("sends nothing when the contract lists no commands", {
    local_spec(list(commands = character()))
    session <- fake_session()
    warning <- expect_warning(
      sm_send(sm_proxy("map", session = session), "select"),
      class = "stagemap_warning_command"
    )
    expect_match(conditionMessage(warning), "It takes no commands.", fixed = TRUE)
    expect_no_match(conditionMessage(warning), "Commands it takes", fixed = TRUE)
    expect_length(session$flush_callbacks, 0L)
  })

  it("writes a named vector as an object, so c(kind = , id = ) selects", {
    session <- fake_session()
    sm_send(sm_proxy("map", session = session), "select", data = c(kind = "card", id = "a"))
    session$flush()
    expect_identical(unclass(session$sent[[1]]$message$data), "{\"kind\":\"card\",\"id\":\"a\"}")
  })

  it("sends a command with a highlight's ids and links as the engine reads them", {
    session <- fake_session()
    sm_send(
      sm_proxy("map", session = session),
      "highlight",
      data = list(ids = I("a"), links = data.frame(from = "a", to = "b"))
    )
    session$flush()
    expect_identical(
      unclass(session$sent[[1]]$message$data),
      "{\"ids\":[\"a\"],\"links\":[{\"from\":\"a\",\"to\":\"b\"}]}"
    )
  })

  it("warns and sends nothing when the data cannot be written as JSON", {
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    expect_warning(sm_send(proxy, "select", data = new.env()), class = "stagemap_warning_command")
    expect_length(session$flush_callbacks, 0L)
    expect_length(session$sent, 0L)
  })

  it("shows the message of a data error as it is, with its braces", {
    local_mocked_bindings(convert_json = function(...) stop("bad {x}", call. = FALSE))
    session <- fake_session()
    warning <- expect_warning(
      sm_send(sm_proxy("map", session = session), "select", data = 1),
      class = "stagemap_warning_command"
    )
    expect_match(conditionMessage(warning), "bad {x}", fixed = TRUE)
    expect_no_match(conditionMessage(warning), "{{", fixed = TRUE)
  })

  it("names the function that called it in a warning, so a caller's own function is shown", {
    session <- fake_session()
    proxy <- sm_proxy("map", session = session)
    select_card <- function() sm_send(proxy, "selct")
    warning <- expect_warning(select_card(), class = "stagemap_warning_command")
    expect_identical(warning$call, quote(select_card()))
    pick <- function() sm_send(proxy, "select", data = new.env())
    expect_identical(expect_warning(pick(), class = "stagemap_warning_command")$call, quote(pick()))
  })

  it("checks its arguments", {
    proxy <- sm_proxy("map", session = fake_session())
    expect_error(sm_send("map", "select"), "proxy")
    expect_error(sm_send(proxy, "select", call = 1), "call")
    expect_error(sm_send(proxy, c("a", "b")), "command")
    expect_error(sm_send(proxy, "select", dat = 1), class = "stagemap_error_dots")
  })
})

describe("sm_state()", {
  held <- list(selected = "adae", selected_ids = c("adae", "adsl"), hidden = character())

  it("reads the whole state, one field of it, or a field the state does not have", {
    session <- fake_session(prefix = "", input = list(view_state = held))
    expect_identical(sm_state("view", session = session), held)
    expect_identical(sm_state("view", "selected_ids", session = session), c("adae", "adsl"))
    expect_null(sm_state("view", "nothing", session = session))
  })

  it("gives NULL before the page has answered", {
    session <- fake_session(prefix = "")
    expect_null(sm_state("view", session = session))
    expect_null(sm_state("view", "selected", session = session))
  })

  it("takes a plain or a namespaced id in a module, and reads the name the module sees", {
    session <- fake_session(prefix = "mod-", input = list(view_state = held))
    expect_identical(sm_state("view", "selected", session = session), "adae")
    expect_identical(sm_state("mod-view", "selected", session = session), "adae")
  })

  it("reads one input in a reactive, sends nothing, and runs again only when the state changes", {
    shiny::testServer(
      function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          runs <- 0L
          seen <- shiny::reactive({
            runs <<- runs + 1L
            sm_state("view", "selected_ids")
          })
          shiny::observe(seen())
          session$userData$runs <- function() runs
          session$userData$seen <- seen
        })
      },
      {
        # Given a reactive that reads the state before the page has answered
        session$flushReact()
        expect_null(session$userData$seen())
        before <- session$userData$runs()
        # When the page answers, and the server then flushes again with no new answer
        session$setInputs(view_state = list(selected_ids = c("a", "b")))
        session$flushReact()
        session$flushReact()
        session$flushReact()
        # Then the reactive saw the answer, ran once more for it, and queued no command
        expect_identical(session$userData$seen(), c("a", "b"))
        expect_identical(session$userData$runs(), before + 1L)
        expect_null(session$userData$stagemap_queue)
      },
      args = list(id = "inner")
    )
  })

  it("checks its arguments", {
    session <- fake_session()
    expect_error(sm_state(1, session = session), "output_id")
    expect_error(sm_state("view", name = c("a", "b"), session = session), "name")
    expect_error(sm_state("view", name = "", session = session), "name")
    expect_error(sm_state("view", session = NULL), "session")
  })
})

describe("the stagemap.state input type", {
  it("makes lists of single values vectors, keeps names, NULL and nested objects, and leaves an empty list alone", {
    value <- list(
      selected = "a",
      selected_ids = list("a", "b"),
      count = list(1L, 2L),
      none = NULL,
      hidden = list(),
      host_changes = list(list(id = "a", hidden = TRUE), list(id = "b", hidden = FALSE))
    )
    out <- sm_state_value(value, NULL, "view_state")
    expect_identical(out$selected, "a")
    expect_identical(out$selected_ids, c("a", "b"))
    expect_identical(out$count, 1:2)
    expect_true("none" %in% names(out))
    expect_null(out$none)
    expect_identical(out$hidden, character())
    expect_identical(out$host_changes[[2]], list(id = "b", hidden = FALSE))
  })

  it("gives an empty list of ids as character(0), as an event does, and leaves other empty lists alone", {
    out <- sm_state_value(
      list(
        selected_ids = list(),
        hidden = list(),
        disabled = list("a"),
        highlighted = list(ids = list(), links = list()),
        host_changes = list()
      ),
      NULL,
      "view_state"
    )
    expect_identical(out$selected_ids, character())
    expect_identical(out$hidden, character())
    expect_identical(out$disabled, "a")
    expect_identical(out$highlighted, list(ids = character(), links = list()))
    expect_identical(out$host_changes, list())
    # The same empty list of ids in an event
    expect_identical(sm_event("select", list(kind = "all", ids = list()))$ids, character())
  })

  it("passes an answer that is not a list through as it is", {
    expect_identical(sm_state_value("idle", NULL, "view_state"), "idle")
    expect_null(sm_state_value(NULL, NULL, "view_state"))
  })

  it("keeps a state without those fields as it is, and a highlight with ids as a vector", {
    expect_identical(sm_state_value(list(step = -1L), NULL, "view_state"), list(step = -1L))
    out <- sm_state_value(list(highlighted = list(ids = list("a", "b"), links = list())), NULL, "view_state")
    expect_identical(out$highlighted$ids, c("a", "b"))
  })
})

describe("the event reader", {
  contract_fields <- function(event) names(kit_contract()$event_data[[paste0("stagemap:", event)]])

  # What the page sends for a pick: every field the engine stamped, with the trail on, plus the binding's revision.
  picked <- function() {
    list(
      kind = "card",
      id = "a",
      ids = list("b", "a"),
      from = "b",
      label = "Card A",
      details = list(title = "A", kpis = c("x", "y")),
      about = NULL,
      still = list(kind = "stage", id = "s"),
      by = "reader",
      via = "key",
      at = "2026-03-03T10:15:00.000Z",
      seq = 4,
      part = "stage-map",
      name = NULL,
      revision = 3
    )
  }

  it("passes every field the contract lists for a select, in the contract's order, then the revision", {
    out <- sm_event("select", picked())
    expect_identical(names(out), c(contract_fields("select"), "revision"))
  })

  it("passes the fields only the trail stamps: how a pick was made, when, and its place in the order", {
    out <- sm_event("select", picked())
    expect_identical(out$via, "key")
    expect_identical(out$at, "2026-03-03T10:15:00.000Z")
    expect_identical(out$seq, 4L)
    expect_identical(out$part, "stage-map")
  })

  it("types the fields: text, an id vector, an integer revision, lists", {
    out <- sm_event("select", picked())
    expect_identical(c(out$kind, out$id, out$from, out$label, out$by), c("card", "a", "b", "Card A", "reader"))
    expect_identical(out$ids, c("b", "a"))
    expect_identical(out$revision, 3L)
    expect_identical(out$still, list(kind = "stage", id = "s"))
    expect_identical(out$details$kpis, list("x", "y"))
  })

  it("gives the same shape for an empty event: NA for a text, character(0) for no ids, NULL for no record", {
    # The trail is off, so the page sends no via, at or seq
    empty <- sm_event(
      "select",
      list(kind = "all", id = NULL, ids = list(), by = "reader", details = NULL, still = NULL)
    )
    expect_identical(names(empty), names(sm_event("select", picked())))
    expect_identical(c(empty$id, empty$from, empty$label, empty$via, empty$at), rep(NA_character_, 5L))
    expect_identical(empty$seq, NA_integer_)
    expect_identical(empty$ids, character())
    expect_identical(empty$revision, 0L)
    expect_null(empty$details)
    expect_null(empty$still)
    expect_null(empty$about)
  })

  it("keeps one id as a vector of one, and no ids as character(0)", {
    expect_identical(sm_event("select", list(kind = "card", id = "a", ids = "a"))$ids, "a")
    expect_identical(sm_event("select", list(kind = "card", id = "a"))$ids, character())
  })

  it("reads a hover with the fields the contract lists for it, and no revision", {
    out <- sm_event("hover", list(kind = "card", id = "a", seq = 2, part = "stage-map"))
    expect_identical(names(out), contract_fields("hover"))
    expect_identical(out$id, "a")
    expect_identical(out$seq, 2L)
  })

  it("reads a size with its width as a number and its breakpoint as an integer", {
    out <- sm_event("size", list(needs = 640.5, stack_below = 500, part = "stage-map"))
    expect_identical(names(out), contract_fields("size"))
    expect_identical(out$needs, 640.5)
    expect_identical(out$stack_below, 500L)
    expect_identical(sm_event("size", list())$needs, NA_real_)
  })

  it("follows the contract, so a field the engine adds reaches R without a change in the package", {
    event_data <- sm_spec()$event_data
    event_data[["stagemap:select"]]$item_ids <- list(type = "json", required = FALSE)
    local_spec(list(event_data = event_data))
    out <- sm_event("select", c(picked(), list(item_ids = list("a"))))
    expect_identical(out$item_ids, list("a"))
    expect_identical(names(out), c(names(event_data[["stagemap:select"]]), "revision"))
  })

  it("refuses an event the contract does not list", {
    expect_error(sm_event("no_such_event", list()), class = "stagemap_error_unknown")
  })

  it("is what Shiny calls for the typed inputs, as the package registers them", {
    reader <- sm_event_reader("select")
    expect_identical(reader(picked(), NULL, "map_selected"), sm_event("select", picked()))
    expect_error(sm_event_reader(1), "event")
  })

  it("is registered with Shiny when the package loads, for a pick, a hover and the state", {
    # Shiny refuses a second handler for a type unless it is forced, so a refusal shows the type is registered
    .onLoad("", "stagemap")
    for (type in c("stagemap.select", "stagemap.hover", "stagemap.state")) {
      expect_error(shiny::registerInputHandler(type, identity), "already an input handler", info = type)
    }
  })
})
