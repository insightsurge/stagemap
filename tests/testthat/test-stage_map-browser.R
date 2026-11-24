skip_without_chrome()

# Opens `map` on a page and waits until the engine has drawn its cards. Returns the page.
open_map <- function(map, cards = 4L, env = parent.frame()) {
  page <- open_widget(map, env = env)
  wait_for_page(page, sprintf("document.querySelectorAll('#map [data-card]').length === %d", cards))
  page
}

# Whether the first element `selector` names inside the map is not hidden (false when there is none).
shown <- function(page, selector) {
  page_js(
    page,
    sprintf("(() => { const e = document.querySelector('#map %s'); return e !== null && !e.hidden; })()", selector)
  )
}

describe("stage_map() in a browser", {
  it("draws a map with every kind of data: its cards, stages and zone, with no error and no uncaught exception", {
    page <- open_map(full_map(title = "Release notes", element_id = "map"))
    expect_false(page_js(page, "document.querySelector('#map .sm-has-error') !== null"))
    expect_match(page_js(page, "document.querySelector('#map').textContent"), "Release notes", fixed = TRUE)
    expect_identical(page_js(page, "document.querySelectorAll('#map .v-sm-node').length"), 4L)
    expect_identical(page$messages$seen, character())
  })

  it("names an untitled map \"Stage map\" for screen readers", {
    page <- open_map(full_map(element_id = "map"))
    expect_true(page_js(page, "document.querySelector('#map svg[aria-label=\"Stage map\"]') !== null"))
  })

  it("shows the card details, the stage panel and the zone notes by default", {
    page <- open_map(full_map(element_id = "map"))
    expect_true(shown(page, ".sm-detail"))
    expect_true(shown(page, ".v-sm-panel"))
    expect_true(shown(page, ".v-sm-zones"))
    expect_match(page_js(page, "document.querySelector('#map .v-sm-zones').textContent"), "Two people read it.")
  })

  it("hides the card details, the stage panel and the zone notes with panels = FALSE", {
    page <- open_map(full_map(panels = FALSE, element_id = "map"))
    expect_false(shown(page, ".sm-detail"))
    expect_false(shown(page, ".v-sm-panel"))
    expect_false(shown(page, ".v-sm-zones"))
    expect_identical(page$messages$seen, character())
  })

  it("keeps the step player out of sight until steps bring it", {
    page <- open_map(full_map(element_id = "map"))
    expect_false(shown(page, ".v-sm-steps"))
    steps <- data.frame(id = c("one", "two"), label = c("Start", "Move"), stage = c("write", "check"))
    stepped <- add_steps(full_map(element_id = "map"), steps)
    page <- open_map(stepped)
    expect_true(shown(page, ".v-sm-steps"))
    expect_identical(page$messages$seen, character())
  })

  it("fades every card but the highlighted ones and the links between them", {
    map <- full_map(highlight = list(ids = c("a", "b")), element_id = "map")
    page <- open_map(map)
    dimmed <- "[...document.querySelectorAll('#map .v-sm-node.v-sm-dim')].map(n => n.dataset.card).sort().join()"
    wait_for_page(page, sprintf("%s === 'c,d'", dimmed))
    expect_identical(page_js(page, dimmed), "c,d")
    expect_identical(page$messages$seen, character())
  })

  it("loads the engine from the page's own folder, with no request to another site", {
    page <- open_map(full_map(element_id = "map"))
    sources <- page_js(page, "[...document.querySelectorAll('script[src], link[href]')].map(e => e.src || e.href)")
    expect_false(any(grepl("^https?://", unlist(sources))))
    expect_true(any(grepl("stage-map.js", unlist(sources), fixed = TRUE)))
  })

  it("draws statuses given as rows, cells of several columns, bundled links and a step's changes without error", {
    cards <- data.frame(
      id = c("a", "b", "c", "d"),
      label = c("A", "B", "C", "D"),
      stage = c("s1", "s1", "s1", "s2"),
      lane = "l",
      status = c("done", "blocked", "running", "blocked")
    )
    map <- stage_map(
      cards,
      data.frame(id = c("s1", "s2"), label = c("One", "Two")),
      data.frame(id = "l", label = "Lane"),
      statuses = data.frame(
        id = c("done", "blocked"),
        label = c("Passed", "Blocked"),
        tone = c("good", "bad"),
        icon = c(NA, "lock")
      ),
      cell_columns = 3,
      bundle_links = TRUE,
      element_id = "map"
    ) |>
      add_links(data.frame(from = "a", to = "d")) |>
      add_steps(
        data.frame(id = c("one", "two"), label = c("Start", "Move"), stage = c("s1", "s2")),
        changes = data.frame(step = "two", card = "b", stage = "s2", status = "done")
      )
    page <- open_map(map)
    expect_false(page_js(page, "document.querySelector('#map .sm-has-error') !== null"))
    legend <- page_js(page, "document.querySelector('#map').textContent")
    expect_match(legend, "Passed", fixed = TRUE)
    expect_match(legend, "Blocked", fixed = TRUE)
    expect_identical(page$messages$seen, character())
  })
})
