skip_without_chrome()

# The map in real Shiny apps (tests/testthat/apps/): what the reader does reaches the server's inputs, the verbs change
# the page and the state, and a map that comes late, in a module or in a hidden tab works as it does anywhere else.
# Each app writes what the server saw as JSON in the text output "dump"; a vector is always an array.

# Opens one of the apps and waits until its map is drawn and the server has had the first state.
open_app <- function(name, map = "map", env = parent.frame()) {
  app <- app_driver(test_path("apps", name), env = env)
  wait_drawn(app, map)
  app
}

# Waits until the map `map` has drawn its cards.
wait_drawn <- function(app, map = "map") {
  app$wait_for_js(sprintf("document.querySelectorAll('#%s [data-card]').length > 0", map))
}

# What the app's text output `output` (default "dump") says the server saw, as a list.
seen_by_server <- function(app, output = "dump") {
  text <- app$get_js(sprintf("document.getElementById('%s').textContent", output))
  jsonlite::fromJSON(text, simplifyVector = FALSE)
}

# Waits until the JavaScript expression `condition` is true of `d`, what the server saw (see seen_by_server()).
wait_for_server <- function(app, condition, output = "dump") {
  app$wait_for_js(sprintf(
    "(() => { try { const d = JSON.parse(document.getElementById('%s').textContent); return Boolean(%s); } catch (e) { return false; } })()",
    output,
    condition
  ))
}

# A click on card `id` of the map, made in the page as a person's click is (the engine reads a click event on the card).
click_card <- function(app, id, map = "map") {
  app$run_js(sprintf(
    "document.querySelector('#%s [data-card=\"%s\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))",
    map,
    id
  ))
}

# Clicks the Shiny button `id`, and waits for the server's answer: the count of verbs it has run goes up.
press <- function(app, id) {
  before <- seen_by_server(app)$sent
  click_now(app, paste0("#", id))
  wait_for_server(app, sprintf("d.sent === %d", before + 1L))
  invisible(app)
}

ids <- function(x) unlist(x)

describe("the map in a Shiny app: what the reader does reaches the server", {
  it("starts with nothing selected as character(0), and nothing hovered, with the state at the start", {
    app <- open_app("stage-map-verbs")
    wait_for_server(app, "d.state !== null")
    d <- seen_by_server(app)
    expect_identical(ids(d$selected), NULL)
    expect_identical(d$selected, list())
    expect_identical(d$hovered, list())
    expect_null(d$pick)
    expect_identical(names(d$state), c("selected", "stage", "step", "highlighted", "hidden", "disabled"))
    expect_identical(d$state$step, list(0L))
    expect_identical(d$state$stage, list())
    expect_identical(d$state$highlighted$links, list())
  })

  it("puts the selected cards in input$map_selected and the reader's pick in input$map_pick, seven fields", {
    app <- open_app("stage-map-verbs")
    click_card(app, "b")
    wait_for_server(app, "d.picks === 1")
    d <- seen_by_server(app)
    expect_identical(ids(d$selected), "b")
    expect_identical(names(d$pick), c("kind", "id", "ids", "from", "label", "still", "by"))
    expect_identical(ids(d$pick[c("kind", "id", "from", "by")]), c(kind = "card", id = "b", by = "reader"))
    expect_identical(ids(d$pick$ids), "b")
    expect_identical(ids(d$pick$label), "Review")
    expect_null(d$pick$still)
    expect_identical(ids(d$state$selected), "b")
  })

  it("sends the new selection in the same message as the pick, so an observer of the pick reads it", {
    app <- open_app("stage-map-verbs")
    click_card(app, "b")
    wait_for_server(app, "d.picks === 1")
    expect_identical(ids(seen_by_server(app)$seen), "b")
    # A second click on another card, and one that lets go
    click_card(app, "c")
    wait_for_server(app, "d.picks === 2")
    d <- seen_by_server(app)
    expect_identical(ids(d$seen), "c")
    expect_identical(ids(d$pick$from), "b")
    click_card(app, "c")
    wait_for_server(app, "d.picks === 3")
    d <- seen_by_server(app)
    expect_identical(d$seen, list())
    expect_identical(d$selected, list())
    expect_null(d$pick$id)
    expect_null(d$pick$label)
    expect_identical(d$pick$ids, list())
  })

  it("sends the selection and the pick in one message even when the page holds the rest back", {
    app <- open_app("stage-map-verbs")
    # Given a page that keeps every input of the map apart until released, as one batch
    app$run_js(
      "window.__held = []; window.__set = Shiny.setInputValue;
       Shiny.setInputValue = (name, value, options) => {
         if (name.startsWith('map_')) window.__held.push([name, value, options]);
         else window.__set.call(Shiny, name, value, options);
       };"
    )
    click_card(app, "b")
    app$wait_for_js("window.__held.some(([name]) => name.startsWith('map_pick'))")
    # Then nothing of the click has reached the server
    expect_identical(seen_by_server(app)$picks, 0L)
    names_held <- app$get_js("window.__held.map(([name]) => name)")
    # And the pick is the last of what is held: the plain inputs go before it, so they travel with it
    expect_match(names_held[[length(names_held)]], "^map_pick")
    expect_true(any(grepl("^map_selected", names_held)))
    app$run_js("Shiny.setInputValue = window.__set; for (const held of window.__held) Shiny.setInputValue(...held);")
    wait_for_server(app, "d.picks === 1")
    expect_identical(ids(seen_by_server(app)$seen), "b")
  })

  it("reports a stage pick with the stage as its id, and gives the stage in the state", {
    app <- open_app("stage-map-verbs")
    app$run_js(
      "document.querySelector('#map [data-stage=\"check\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))"
    )
    wait_for_server(app, "d.picks === 1")
    d <- seen_by_server(app)
    expect_identical(ids(d$pick$kind), "stage")
    expect_identical(ids(d$pick$id), "check")
    expect_identical(ids(d$pick$ids), "check")
    expect_identical(ids(d$pick$label), "Check")
    expect_identical(ids(d$state$stage), "check")
    expect_identical(d$selected, list())
  })

  it("lets go of the selected cards when the reader picks a stage, and says so in input$map_selected", {
    app <- open_app("stage-map-verbs")
    click_card(app, "a")
    wait_for_server(app, "d.selected.length === 1")
    app$run_js(
      "document.querySelector('#map [data-stage=\"check\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))"
    )
    wait_for_server(app, "d.selected.length === 0 && d.state.stage.length === 1")
    expect_identical(ids(seen_by_server(app)$state$stage), "check")
  })

  it("reports the card under the pointer in input$map_hovered, and none once it leaves", {
    app <- open_app("stage-map-verbs")
    app$run_js("document.querySelector('#map [data-card=\"a\"]').dispatchEvent(new PointerEvent('pointerenter'))")
    wait_for_server(app, "d.hovered.length === 1")
    expect_identical(ids(seen_by_server(app)$hovered), "a")
    app$run_js("document.querySelector('#map [data-card=\"a\"]').dispatchEvent(new PointerEvent('pointerleave'))")
    wait_for_server(app, "d.hovered.length === 0")
    expect_identical(seen_by_server(app)$hovered, list())
  })

  it("does not report a stage under the pointer in input$map_hovered", {
    app <- open_app("stage-map-verbs")
    app$run_js(
      "window.__hovers = [];
       document.getElementById('map').addEventListener('stagemap:hover', (e) => window.__hovers.push(e.detail));
       document.querySelector('#map [data-stage=\"check\"]').dispatchEvent(new PointerEvent('pointerenter'));"
    )
    # The engine announces the stage; the server must not hear a card
    app$wait_for_js("window.__hovers.some((hover) => hover.kind === 'stage' && hover.id === 'check')")
    # A verb after it, so the server has had everything the page said before
    press(app, "select_none")
    expect_identical(seen_by_server(app)$hovered, list())
    # And a card after the stage is reported again
    app$run_js("document.querySelector('#map [data-card=\"a\"]').dispatchEvent(new PointerEvent('pointerenter'))")
    wait_for_server(app, "d.hovered.length === 1")
  })

  it("sends input$map_selected only when the selection changes, not for a hide, a highlight or a stage pick", {
    app <- open_app("stage-map-verbs")
    wait_for_server(app, "d.state !== null")
    runs <- seen_by_server(app)$selected_runs
    press(app, "hide_b")
    press(app, "light")
    app$run_js(
      "document.querySelector('#map [data-stage=\"check\"]').dispatchEvent(new MouseEvent('click', { bubbles: true, detail: 1 }))"
    )
    wait_for_server(app, "d.state.stage.length === 1")
    press(app, "show_b")
    expect_identical(seen_by_server(app)$selected_runs, runs)
    # A change of the selection does count
    press(app, "select_c")
    wait_for_server(app, "d.selected.length === 1")
    expect_identical(seen_by_server(app)$selected_runs, runs + 1L)
  })

  it("leaves via, at and seq out of the engine's event on a lone map", {
    app <- open_app("stage-map-verbs")
    app$run_js(
      "window.__events = [];
       document.getElementById('map').addEventListener('stagemap:select', (e) => window.__events.push(e.detail));"
    )
    click_card(app, "b")
    click_card(app, "b")
    app$wait_for_js("window.__events.length === 2")
    fields <- app$get_js(
      "window.__events.map((detail) => Object.keys(detail).filter((key) => ['via', 'at', 'seq'].includes(key) && detail[key] != null))"
    )
    expect_identical(unlist(fields), NULL)
    expect_identical(
      app$get_js("window.__events.every((detail) => detail.via == null && detail.at == null && detail.seq == null)"),
      TRUE
    )
  })
})

describe("the map in a Shiny app: verbs change the page and the state", {
  it("selects from the server, changes input$map_selected and the state, and leaves input$map_pick alone", {
    app <- open_app("stage-map-verbs")
    click_card(app, "a")
    wait_for_server(app, "d.picks === 1")
    press(app, "select_c")
    wait_for_server(app, "d.selected.length === 1 && d.selected[0] === 'c'")
    d <- seen_by_server(app)
    expect_identical(ids(d$state$selected), "c")
    # The pick is still the reader's click on a, and no pick came for the verb
    expect_identical(d$picks, 1L)
    expect_identical(ids(d$pick$id), "a")
    expect_identical(app$get_js("document.querySelectorAll('#map .sm-on').length"), 1L)
    press(app, "select_none")
    wait_for_server(app, "d.selected.length === 0")
    expect_identical(seen_by_server(app)$picks, 1L)
  })

  it("hides and shows a card, and disables and enables one, as the state says", {
    app <- open_app("stage-map-verbs")
    press(app, "hide_b")
    wait_for_server(app, "d.state.hidden.length === 1")
    expect_identical(ids(seen_by_server(app)$state$hidden), "b")
    press(app, "show_b")
    wait_for_server(app, "d.state.hidden.length === 0")
    press(app, "disable_c")
    wait_for_server(app, "d.state.disabled.length === 1")
    expect_identical(ids(seen_by_server(app)$state$disabled), "c")
    expect_identical(
      app$get_js("document.querySelector('#map [data-card=\"c\"]').getAttribute('aria-disabled')"),
      "true"
    )
    press(app, "enable_c")
    wait_for_server(app, "d.state.disabled.length === 0")
    expect_identical(seen_by_server(app)$picks, 0L)
  })

  it("highlights from the server, and puts back from the state what the state holds", {
    app <- open_app("stage-map-verbs")
    press(app, "light")
    wait_for_server(app, "d.state.highlighted.ids.length === 3")
    d <- seen_by_server(app)
    expect_identical(ids(d$state$highlighted$ids), c("a", "b", "c"))
    expect_identical(d$state$highlighted$links, list(list(from = "a", to = "b", kind = "hand")))
    dimmed <- "[...document.querySelectorAll('#map .v-sm-node.v-sm-dim')].map((n) => n.dataset.card).join()"
    expect_identical(app$get_js(dimmed), "d")
    # Let go, then give back what the state held earlier (the state is read in the server when the button is pressed)
    press(app, "light_none")
    wait_for_server(app, "d.state.highlighted.ids.length === 0")
    expect_identical(app$get_js(dimmed), "")
    press(app, "light")
    wait_for_server(app, "d.state.highlighted.ids.length === 3")
    press(app, "restore")
    # The same state again: ids and the one link, with its kind
    d <- seen_by_server(app)
    expect_identical(ids(d$state$highlighted$ids), c("a", "b", "c"))
    expect_identical(d$state$highlighted$links, list(list(from = "a", to = "b", kind = "hand")))
    expect_identical(app$get_js(dimmed), "d")
  })

  it("puts back a highlight whose link has no kind, as the state reports it (a missing kind is null)", {
    app <- open_app("stage-map-verbs")
    press(app, "light_no_kind")
    wait_for_server(app, "d.state.highlighted.ids.length === 2")
    first <- seen_by_server(app)$state$highlighted
    expect_identical(first$links, list(list(from = "a", to = "b")))
    press(app, "light_none")
    wait_for_server(app, "d.state.highlighted.ids.length === 0")
    press(app, "light_no_kind")
    wait_for_server(app, "d.state.highlighted.ids.length === 2")
    press(app, "restore")
    expect_identical(seen_by_server(app)$state$highlighted, first)
    expect_identical(app$get_js("document.querySelectorAll('#map .v-sm-node.v-sm-dim').length"), 2L)
  })

  it("counts the step from 1, with 0 at the start", {
    app <- open_app("stage-map-verbs")
    expect_identical(seen_by_server(app)$state$step, list(0L))
    app$run_js("document.querySelector('#map [data-k=\"step-1\"]').click()")
    wait_for_server(app, "d.state.step[0] === 2")
    app$run_js("document.querySelector('#map [data-k=\"step-0\"]').click()")
    wait_for_server(app, "d.state.step[0] === 1")
    expect_identical(seen_by_server(app)$state$step, list(1L))
  })

  it("ignores a late answer from the server that a newer click has overtaken", {
    app <- open_app("stage-map-verbs")
    # Given a page that holds the reader's inputs back, so the server answers a button before it has seen the click
    app$run_js(
      "window.__held = []; window.__set = Shiny.setInputValue; window.__commands = 0;
       Shiny.setInputValue = (name, value, options) => {
         if (name.startsWith('map_')) window.__held.push([name, value, options]);
         else window.__set.call(Shiny, name, value, options);
       };
       $(document).on('shiny:message', (e) => { if (e.message.custom && e.message.custom['stagemap:command']) window.__commands += 1; });"
    )
    # When the reader picks b, and then the server (which has not seen that click) selects c
    click_card(app, "b")
    click_now(app, "#select_c")
    app$wait_for_js("window.__commands >= 1")
    app$wait_for_js("new Promise((resolve) => setTimeout(() => resolve(true), 0))")
    # Then the page still shows b: the older command did not undo the newer click
    expect_identical(app$get_js("[...document.querySelectorAll('#map .sm-on')].map((n) => n.dataset.card).join()"), "b")
    # And the server, once it hears the click, agrees
    app$run_js("Shiny.setInputValue = window.__set; for (const held of window.__held) Shiny.setInputValue(...held);")
    wait_for_server(app, "d.picks === 1")
    expect_identical(ids(seen_by_server(app)$selected), "b")
  })

  it("applies a command that the reader has not overtaken", {
    app <- open_app("stage-map-verbs")
    click_card(app, "b")
    wait_for_server(app, "d.picks === 1")
    press(app, "select_c")
    wait_for_server(app, "d.selected[0] === 'c'")
    expect_identical(app$get_js("[...document.querySelectorAll('#map .sm-on')].map((n) => n.dataset.card).join()"), "c")
  })

  it("draws a new map in the same output: a pick stays when its card is still there, and goes when it is not", {
    app <- open_app("stage-map-verbs")
    click_card(app, "b")
    wait_for_server(app, "d.picks === 1")
    # A map without card b (the redraw button takes a card out on its odd presses)
    click_now(app, "#redraw")
    wait_for_server(app, "d.selected.length === 0 && d.picks === 2")
    d <- seen_by_server(app)
    expect_identical(ids(d$pick$by), "data")
    expect_identical(ids(d$pick$from), "b")
    expect_identical(app$get_js("document.querySelectorAll('#map > div').length"), 1L)
    click_card(app, "c")
    wait_for_server(app, "d.selected[0] === 'c'")
    # And the next press brings card b back, with c still picked
    click_now(app, "#redraw")
    app$wait_for_js("document.querySelectorAll('#map [data-card]').length === 4")
    wait_for_server(app, "d.state.selected[0] === 'c'")
    expect_identical(ids(seen_by_server(app)$selected), "c")
  })

  it("takes the output's size by position, and writes no warning to the console", {
    app <- open_app("stage-map-verbs")
    expect_match(app$get_js("document.getElementById('map').getAttribute('style')"), "height: 480px", fixed = TRUE)
    press(app, "hide_b")
    logs <- app$get_logs()
    expect_identical(nrow(logs[logs$level %in% c("warning", "error") & logs$location == "chromote", ]), 0L)
  })
})

describe("the map in a Shiny app that builds its page on the server", {
  it("draws inside renderUI, and a new render replaces the map, with state that starts again", {
    app <- open_app("stage-map-dynamic", "main")
    click_card(app, "a", "main")
    wait_for_server(app, "d.main.length === 1")
    expect_identical(ids(seen_by_server(app)$main), "a")
    click_now(app, "#redraw")
    wait_for_server(app, "d.draws === 2 && d.main.length === 0")
    wait_drawn(app, "main")
    expect_identical(app$get_js("document.querySelectorAll('#main > div').length"), 1L)
    click_card(app, "c", "main")
    wait_for_server(app, "d.main[0] === 'c'")
  })

  it("works for a map inserted with insertUI and cleans up when it is removed", {
    app <- open_app("stage-map-dynamic", "main")
    click_now(app, "#insert")
    wait_drawn(app, "extra")
    click_card(app, "b", "extra")
    wait_for_server(app, "d.extra && d.extra[0] === 'b'")
    click_now(app, "#remove")
    app$wait_for_js("document.getElementById('extra') === null")
    # Inserting it again draws a fresh map, and the page keeps no error from the one that left
    click_now(app, "#insert")
    wait_drawn(app, "extra")
    wait_for_server(app, "d.extra.length === 0")
    click_card(app, "c", "extra")
    wait_for_server(app, "d.extra[0] === 'c'")
    logs <- app$get_logs()
    expect_identical(nrow(logs[logs$level == "error" & logs$location == "chromote", ]), 0L)
  })

  it("draws a map in a tab that was not shown when the page loaded, and applies a command sent meanwhile", {
    app <- open_app("stage-map-dynamic", "main")
    expect_identical(app$get_js("document.querySelectorAll('#hidden_map [data-card]').length"), 0L)
    click_now(app, "#select_hidden")
    app$run_js("document.querySelector('a[data-value=\"Hidden\"]').click()")
    wait_drawn(app, "hidden_map")
    wait_for_server(app, "d.hidden && d.hidden[0] === 'b'")
    expect_identical(
      app$get_js("[...document.querySelectorAll('#hidden_map .sm-on')].map((n) => n.dataset.card).join()"),
      "b"
    )
    expect_identical(
      app$get_js(
        "document.getElementById('hidden_map').style.overflow || getComputedStyle(document.getElementById('hidden_map')).overflow"
      ),
      "auto"
    )
  })

  it("keeps every command sent to a map in a hidden tab, however many, and applies them when the tab is shown", {
    app <- open_app("stage-map-dynamic", "main")
    click_now(app, "#hide_many")
    app$run_js("document.querySelector('a[data-value=\"Many\"]').click()")
    # Every card is hidden, so none is in the page: the map is drawn when its root is
    app$wait_for_js("document.querySelector('#many_map > div') !== null")
    wait_for_server(app, "d.many_hidden === 150")
    expect_identical(app$get_js("document.querySelectorAll('#many_map [data-card]').length"), 0L)
  })

  it("tells the server the selection and the state of a map drawn in a hidden tab once the tab is shown", {
    app <- open_app("stage-map-dynamic", "main")
    app$run_js("document.querySelector('a[data-value=\"Eager\"]').click()")
    app$wait_for_js("document.querySelector('#eager_map [data-card]') !== null")
    wait_for_server(app, "d.eager_state !== null && d.eager_selected !== null")
    expect_identical(seen_by_server(app)$eager_selected, list())
  })

  it("draws a map in a modal", {
    app <- open_app("stage-map-dynamic", "main")
    click_now(app, "#modal")
    wait_drawn(app, "modal_map")
    click_card(app, "a", "modal_map")
    wait_for_server(app, "d.modal && d.modal[0] === 'a'")
    expect_identical(ids(seen_by_server(app)$modal), "a")
  })

  it("keeps two copies of a module apart, with namespaced ids that hold a hyphen", {
    app <- open_app("stage-map-dynamic", "main")
    app$run_js("document.querySelector('a[data-value=\"Modules\"]').click()")
    wait_drawn(app, "m1-map")
    wait_drawn(app, "m2-map")
    click_now(app, "#m1-pick_a")
    wait_for_server(app, "d.selected.length === 1", "m1-dump")
    expect_identical(ids(seen_by_server(app, "m1-dump")$selected), "a")
    expect_identical(seen_by_server(app, "m2-dump")$selected, list())
    # A pick by the reader in the second copy reaches the second copy only
    click_card(app, "c", "m2-map")
    wait_for_server(app, "d.selected[0] === 'c'", "m2-dump")
    expect_identical(ids(seen_by_server(app, "m1-dump")$selected), "a")
    expect_identical(
      app$get_js("[...document.querySelectorAll('#m1-map .sm-on')].map((n) => n.dataset.card).join()"),
      "a"
    )
  })
})

describe("the demo app", {
  demo <- function(env = parent.frame()) {
    app <- app_driver(system.file("examples", "shiny-demo", package = "stagemap"), env = env)
    wait_drawn(app, "shed")
    app
  }
  cards_drawn <- "document.querySelectorAll('#shed [data-card]').length"
  # The text of a readout (a verbatimTextOutput of the demo).
  readout <- function(app, id) app$get_js(sprintf("document.getElementById('%s').textContent", id))

  it("draws every kind of data in the grid, and the player, the zone and the legend with no console error", {
    app <- demo()
    expect_identical(app$get_js(cards_drawn), 8L)
    expect_true(app$get_js("document.querySelector('#shed .v-sm-steps') !== null"))
    expect_match(app$get_js("document.getElementById('shed').textContent"), "Needs sign-off", fixed = TRUE)
    logs <- app$get_logs()
    expect_identical(nrow(logs[logs$level %in% c("warning", "error") & logs$location == "chromote", ]), 0L)
  })

  it("draws in the levels layout and the dates layout, and back to the grid", {
    app <- demo()
    for (layout in c("levels", "dates", "grid")) {
      # Wait for the server's own render of the new layout: a new stamp, and the output no longer busy
      stamp <- app$get_js("Number(document.getElementById('shed').getAttribute('data-stagemap-stamp'))")
      app$set_inputs(layout = layout, wait_ = FALSE)
      app$wait_for_js(sprintf(
        "Number(document.getElementById('shed').getAttribute('data-stagemap-stamp')) > %d && !document.getElementById('shed').hasAttribute('aria-busy')",
        stamp
      ))
      expect_false(app$get_js("document.querySelector('#shed .sm-has-error') !== null"), info = layout)
      expect_gt(app$get_js(cards_drawn), 0L, label = layout)
    }
    logs <- app$get_logs()
    expect_identical(nrow(logs[logs$level %in% c("warning", "error") & logs$location == "chromote", ]), 0L)
  })

  it("selects the chosen cards when the choice and the button come in one breath", {
    app <- demo()
    # Given the chosen cards set and Select pressed with no wait between
    app$run_js("Shiny.setInputValue('ids', ['frame', 'roof']); document.getElementById('select').click();")
    # Then the server selected both, and says so in its readout
    app$wait_for_js("document.getElementById('selected').textContent.includes('roof')")
    expect_match(readout(app, "selected"), "frame", fixed = TRUE)
    # The map marks the lead, the last of the cards
    expect_identical(
      app$get_js("[...document.querySelectorAll('#shed .sm-on')].map((n) => n.dataset.card).join()"),
      "roof"
    )
  })

  it("has a working control for each verb, and shows the pick, the hover and the state", {
    app <- demo()
    app$run_js("Shiny.setInputValue('ids', ['paint', 'inspect'])")
    click_now(app, "#highlight")
    app$wait_for_js("document.getElementById('state').textContent.includes('paint')")
    expect_gt(app$get_js("document.querySelectorAll('#shed .v-sm-node.v-sm-dim').length"), 0L)
    click_now(app, "#hide")
    app$wait_for_js("document.getElementById('state').textContent.match(/hidden.*inspect/s) !== null")
    click_now(app, "#show")
    click_now(app, "#disable")
    app$wait_for_js("document.getElementById('state').textContent.match(/disabled.*paint/s) !== null")
    click_now(app, "#enable")
    app$wait_for_js("!document.getElementById('state').textContent.match(/disabled.*paint/s)")
    click_now(app, "#clear")
    app$wait_for_js("document.querySelectorAll('#shed .v-sm-node.v-sm-dim').length === 0")
    click_card(app, "base", "shed")
    app$wait_for_js("document.getElementById('pick').textContent.includes('base')")
    app$run_js("document.querySelector('#shed [data-card=\"frame\"]').dispatchEvent(new PointerEvent('pointerenter'))")
    app$wait_for_js("document.getElementById('hovered').textContent.includes('frame')")
  })
})
