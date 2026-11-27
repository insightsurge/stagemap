# The studio's protocol: the events the page sends and the message R sends back.

event <- function(type = "ready", data = structure(list(), names = character()), seq = 1L, rev = 0L) {
  list(seq = seq, type = type, data = data, rev = rev)
}

describe("studio_event_types", {
  it("lists every event of the protocol with the fields its data needs", {
    expect_named(
      studio_event_types,
      c(
        "ready",
        "open",
        "edit",
        "option",
        "add",
        "remove",
        "move",
        "link_add",
        "link_reverse",
        "fix",
        "undo",
        "target",
        "ask",
        "ask_clear",
        "seen",
        "done"
      )
    )
    expect_identical(studio_event_types$option, c("name", "value"))
    expect_identical(studio_event_types$edit, c("table", "uid", "field", "value"))
    expect_identical(studio_event_types$done, character())
  })
})

describe("studio_event_check()", {
  it("returns a good event with whole numbers as integers and its data as a list", {
    checked <- studio_event_check(event("option", list(name = "title", value = "T"), seq = 3, rev = 2))
    expect_identical(checked$seq, 3L)
    expect_identical(checked$rev, 2L)
    expect_identical(checked$type, "option")
    expect_identical(checked$data, list(name = "title", value = "T"))
  })

  it("takes the shapes Shiny gives: an empty object, an empty text and a null value", {
    expect_identical(studio_event_check(event())$data, structure(list(), names = character()))
    expect_identical(studio_event_check(event("ready", list()))$data, list())
    expect_identical(studio_event_check(event("option", list(name = "title", value = "")))$data$value, "")
    expect_null(studio_event_check(event("option", list(name = "title", value = NULL)))$data$value)
    expect_named(studio_event_check(event("option", list(name = "title", value = NULL)))$data, c("name", "value"))
  })

  it("refuses an event whose data lacks a field its type needs, and names the field", {
    expect_error(
      studio_event_check(event("option", list(name = "title"))),
      "A `option` event needs `value` in its data.",
      fixed = TRUE,
      class = "stagemap_error_studio"
    )
  })

  it("refuses a type the studio does not know", {
    expect_error(studio_event_check(event("explode")), "not an event the studio knows", class = "stagemap_error_studio")
    expect_error(studio_event_check(event(NULL)), "type", class = "stagemap_error_studio")
  })

  it("refuses what is not an event: no list, no names, or a field missing", {
    expect_error(studio_event_check("ready"), "The event: Must be of type 'list'", class = "stagemap_error_studio")
    expect_error(studio_event_check(NULL), "The event", class = "stagemap_error_studio")
    expect_error(studio_event_check(list(1, 2)), "names", class = "stagemap_error_studio")
    expect_error(
      studio_event_check(list(seq = 1L, type = "ready")),
      "has no data, rev",
      class = "stagemap_error_studio"
    )
  })

  it("refuses a seq that is not a whole number from 1, a rev below 0 and data that is not a list", {
    expect_error(studio_event_check(event(seq = 0L)), "`seq`", class = "stagemap_error_studio")
    expect_error(studio_event_check(event(seq = 1.5)), "`seq`", class = "stagemap_error_studio")
    expect_error(studio_event_check(event(rev = -1L)), "`rev`", class = "stagemap_error_studio")
    expect_error(studio_event_check(event(data = "x")), "`data`", class = "stagemap_error_studio")
  })

  it("keeps the problem on the error, for the notice", {
    error <- tryCatch(studio_event_check(event(seq = 0L)), error = function(e) e)
    expect_match(error$problem, "^Its `seq`: ")
  })
})

describe("studio_message()", {
  view <- list(header = list(title = "A"), notice = NULL, code = list(text = "x"))

  it("has every section when nothing was sent before", {
    message <- studio_message(view, NULL)
    expect_identical(message$sections, view)
    expect_named(message$sections, c("header", "notice", "code"))
  })

  it("has only the sections that changed", {
    sent <- view
    sent$header <- list(title = "B")
    expect_identical(studio_message(view, sent)$sections, list(header = list(title = "A")))
  })

  it("sends a section that became null, and leaves out one that stays null", {
    sent <- list(header = list(title = "A"), notice = list(n = 1L), code = list(text = "x"))
    expect_identical(studio_message(view, sent)$sections, list(notice = NULL))
  })

  it("has an empty named list when nothing changed, which is a JSON object", {
    sections <- studio_message(view, view)$sections
    expect_length(sections, 0L)
    expect_identical(as.character(jsonlite::toJSON(sections)), "{}")
  })

  it("checks its arguments", {
    expect_error(studio_message(list(1), NULL), "view")
    expect_error(studio_message(view, "sent"), "sent")
  })
})

describe("studio_event_check() and the names of data", {
  it("refuses data with a repeated key or a key without a name, instead of reaching a handler", {
    repeated <- jsonlite::parse_json('{"kind":"card","uid":"u1","uid":"u2"}')
    expect_length(repeated, 3L)
    unnamed <- jsonlite::parse_json('{"kind":"card","uid":"u1","":5}')
    for (type in c("open", "target", "add", "ask", "ready")) {
      expect_error(
        studio_event_check(event(type, repeated)),
        "Its `data`: Must have unique names",
        class = "stagemap_error_studio"
      )
      expect_error(
        studio_event_check(event(type, unnamed)),
        "Its `data`",
        class = "stagemap_error_studio"
      )
    }
    expect_error(studio_event_check(event("target", list(1, 2))), "Its `data`", class = "stagemap_error_studio")
  })

  it("answers such an event with a notice and changes nothing", {
    s <- studio_state_new(full_map())
    for (type in c("open", "target", "add", "ask")) {
      data <- jsonlite::parse_json(
        '{"kind":"card","uid":"u1","uid":"u2","table":"cards","template":"blank","question":"trace"}'
      )
      res <- studio_step(s, list(seq = 1L, type = type, data = data, rev = 0L))
      expect_match(res$state$notice$text, "unique names")
      expect_identical(res$state$doc, s$doc)
      expect_length(res$effects, 0L)
    }
  })

  it("still takes an empty object and data whose names are all different", {
    expect_no_error(studio_event_check(event("ready", jsonlite::parse_json("{}"))))
    expect_no_error(studio_event_check(event("target", jsonlite::parse_json('{"kind":"none","uid":null}'))))
  })
})
