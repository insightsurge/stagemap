# The app the Shiny browser tests drive: one map, a button for each verb, and a text output that writes every input the
# package gives the server as JSON (a vector is always an array, and NULL is null), so a test reads what R saw.
library(shiny)
library(stagemap)

# The map, or the map without card b (and the links it had): the redraw button takes b out and puts it back.
build_map <- function(without_b = FALSE) {
  cards <- data.frame(
    id = c("a", "b", "c", "d"),
    label = c("Draft", "Review", "Publish", "Archive"),
    stage = c("write", "check", "check", "ship"),
    lane = c("docs", "docs", "code", "code")
  )
  links <- data.frame(from = c("a", "b", "c"), to = c("b", "c", "d"), kind = c("hand", "hand", NA))
  if (without_b) {
    cards <- cards[cards$id != "b", ]
    links <- links[links$from != "b" & links$to != "b", ]
  }
  stage_map_of(cards, links)
}

stage_map_of <- function(cards, links) {
  stage_map(
    cards,
    data.frame(id = c("write", "check", "ship"), label = c("Write", "Check", "Ship"), text = "Where it happens."),
    data.frame(id = c("docs", "code"), label = c("Docs", "Code"))
  ) |>
    add_links(links, kinds = data.frame(id = "hand", label = "Handed over")) |>
    add_steps(data.frame(id = c("one", "two"), label = c("Start", "Move"), stage = c("write", "check")))
}

ui <- fluidPage(
  stage_map_output("map", "100%", "480px"),
  actionButton("select_c", "Select c"),
  actionButton("select_none", "Select none"),
  actionButton("hide_b", "Hide b"),
  actionButton("show_b", "Show b"),
  actionButton("disable_c", "Disable c"),
  actionButton("enable_c", "Enable c"),
  actionButton("light", "Light a and b"),
  actionButton("light_no_kind", "Light a and b with a link of no kind"),
  actionButton("light_none", "Light none"),
  actionButton("restore", "Restore the lit cards from the state"),
  actionButton("redraw", "Draw the map again"),
  verbatimTextOutput("dump")
)

server <- function(input, output, session) {
  redraws <- reactiveVal(0L)
  output$map <- render_stage_map(build_map(redraws() %% 2L == 1L))
  proxy <- stage_map_proxy("map", session)
  # What each pick saw of the selection, to test that they arrive together.
  picks <- reactiveVal(0L)
  seen <- reactiveVal(NULL)
  observeEvent(input$map_pick, {
    picks(picks() + 1L)
    seen(input$map_selected)
  })
  sent <- reactiveVal(0L)
  verb <- function(button, action) {
    observeEvent(input[[button]], {
      action()
      sent(sent() + 1L)
    })
  }
  verb("select_c", function() stage_map_select(proxy, "c"))
  verb("select_none", function() stage_map_select(proxy, NULL))
  verb("hide_b", function() stage_map_hide(proxy, "b"))
  verb("show_b", function() stage_map_show(proxy, "b"))
  verb("disable_c", function() stage_map_disable(proxy, "c", "Not ready"))
  verb("enable_c", function() stage_map_enable(proxy, "c"))
  verb("light", function() {
    stage_map_highlight(proxy, c("a", "b", "c"), links = data.frame(from = "a", to = "b", kind = "hand"))
  })
  verb("light_no_kind", function() {
    stage_map_highlight(proxy, c("a", "b"), links = data.frame(from = "a", to = "b"))
  })
  verb("light_none", function() stage_map_highlight(proxy, NULL))
  verb("restore", function() {
    lit <- input$map_state$highlighted
    stage_map_highlight(proxy, lit$ids, links = lit$links)
  })
  observeEvent(input$redraw, redraws(redraws() + 1L))
  output$dump <- renderText(
    as.character(jsonlite::toJSON(
      list(
        selected = input$map_selected,
        hovered = input$map_hovered,
        pick = input$map_pick,
        state = input$map_state,
        picks = jsonlite::unbox(picks()),
        seen = seen(),
        sent = jsonlite::unbox(sent())
      ),
      null = "null",
      dataframe = "rows"
    ))
  )
}

shinyApp(ui, server)
