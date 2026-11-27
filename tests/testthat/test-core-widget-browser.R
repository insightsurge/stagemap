# The binding draws the map in a real browser. Skips the whole file on CRAN or without Chrome, before any code runs.
skip_without_chrome()

describe("the htmlwidgets binding", {
  data <- function() {
    data <- map_data()
    data$cards <- data.frame(id = c("a", "b"), label = c("A", "B"), stage = c("s", "s"), lane = "l")
    data
  }
  cards <- "document.querySelectorAll('#map [data-card]').length"

  it("draws the map with the engine: one card for each node, in the engine's root", {
    page <- open_widget(sm_widget(data(), element_id = "map"))
    wait_for_page(page, paste(cards, "=== 2"))
    expect_identical(
      page_js(page, "document.querySelector('#map > div').getAttribute('data-stagemap-visual')"),
      "stage-map"
    )
    expect_identical(
      page_js(page, "[...document.querySelectorAll('#map [data-card]')].map(c => c.dataset.card).join()"),
      "a,b"
    )
    expect_identical(page_js(page, "document.querySelectorAll('#map > div').length"), 1L)
  })

  it("writes no warning and no error to the console", {
    page <- open_widget(sm_widget(data(), element_id = "map"))
    wait_for_page(page, paste(cards, "=== 2"))
    expect_identical(page$messages$seen, character())
  })

  it("draws again in the same root for new data, and leaves one root", {
    page <- open_widget(sm_widget(data(), element_id = "map"))
    wait_for_page(page, paste(cards, "=== 2"))
    # Given a render with one node more, sent to the instance htmlwidgets made
    more <- data()
    more$cards <- rbind(more$cards, data.frame(id = "c", label = "C", stage = "s", lane = "l"))
    x <- jsonlite::toJSON(sm_widget(more)$x, auto_unbox = TRUE, null = "null", json_verbatim = TRUE)
    page_js(
      page,
      sprintf(
        "(() => { window.__root = document.querySelector('#map > div'); HTMLWidgets.find('#map').renderValue(%s); })()",
        x
      )
    )
    # Then the card appears, in the root that was already there
    wait_for_page(page, paste(cards, "=== 3"))
    expect_true(page_js(page, "window.__root === document.querySelector('#map > div')"))
    expect_identical(page_js(page, "document.querySelectorAll('#map > div').length"), 1L)
  })

  it("follows the colours of the page when the look says mode host", {
    widget <- sm_widget(data(), element_id = "map")
    widget$x$look <- list(mode = "host")
    page <- open_widget(widget)
    wait_for_page(page, paste(cards, "=== 2"))
    expect_true(page_js(page, "document.querySelector('#map > div').hasAttribute('data-stagemap-mode')"))
    expect_identical(page$messages$seen, character())
  })

  it("says what is wrong in the element when the engine is not on the page", {
    widget <- sm_widget(data(), element_id = "map")
    widget$x$engine$global <- "no_such_engine"
    page <- open_widget(widget)
    wait_for_page(page, "document.getElementById('map').textContent.includes('no_such_engine')")
    expect_identical(page_js(page, "document.querySelectorAll('#map [data-card]').length"), 0L)
  })

  it("keeps the commands waiting for a map drawn again under the same id when the old one is destroyed", {
    # Given a page with a stand-in for Shiny's custom message handler, and a map drawn under the id "map"
    shiny_stand_in <- "window.Shiny = { addCustomMessageHandler: (type, fun) => { window.__handler = fun; } };"
    page <- open_widget(sm_widget(data(), element_id = "map"), before = shiny_stand_in)
    wait_for_page(page, paste(cards, "=== 2"))
    x <- jsonlite::toJSON(sm_widget(data())$x, auto_unbox = TRUE, null = "null", json_verbatim = TRUE)
    # When a second widget takes the id but cannot draw yet (its engine is missing), R sends it a select, and the old
    # element leaves the page, which destroys the old widget
    page_js(
      page,
      sprintf(
        "(async () => {
          const x = %s;
          const definition = HTMLWidgets.widgets.find((widget) => widget.name === 'stage_map');
          const old = document.getElementById('map');
          const element = document.createElement('div');
          element.id = 'map';
          element.dataset.again = 'yes';
          document.body.append(element);
          window.__again = definition.initialize(element, 300, 200);
          window.__again.renderValue({ ...x, engine: { ...x.engine, global: 'not_loaded' } });
          window.__handler({ id: 'map', command: 'select', data: { kind: 'card', ids: ['a'] }, revision: 0 });
          old.remove();
          await new Promise((resolve) => setTimeout(resolve, 300));
          window.__x = x;
        })()",
        x
      )
    )
    # And the second widget then draws
    page_js(page, "window.__again.renderValue(window.__x)")
    # Then the select that waited for it is applied: card a is picked
    wait_for_page(page, "!!document.querySelector('[data-again] [data-card=\"a\"].sm-on')")
    expect_identical(page_js(page, "document.querySelectorAll('[data-again] .sm-on').length"), 1L)
  })
})
