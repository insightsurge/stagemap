# The app the Shiny browser tests drive for maps that are not on the page from the start: inside renderUI, in a tab
# that is not shown, inserted and removed, in a modal, and in two copies of a module. Each map's inputs are written as
# JSON in a text output.
library(shiny)
library(stagemap)

cards <- data.frame(
  id = c("a", "b", "c"),
  label = c("A", "B", "C"),
  stage = c("s1", "s1", "s2"),
  lane = "l"
)
map <- stage_map(cards, data.frame(id = c("s1", "s2"), label = c("One", "Two")), data.frame(id = "l", label = "L"))

# A map with 150 cards, to send it more commands than the page keeps for a map that is not drawn yet.
many_ids <- sprintf("c%03d", 1:150)
many_map <- stage_map(
  data.frame(id = many_ids, label = many_ids, stage = "s1", lane = "l"),
  data.frame(id = "s1", label = "One"),
  data.frame(id = "l", label = "L")
)

json <- function(...) as.character(jsonlite::toJSON(list(...), null = "null"))

module_ui <- function(id) {
  ns <- NS(id)
  tagList(
    stage_map_output(ns("map")),
    actionButton(ns("pick_a"), "Select a"),
    verbatimTextOutput(ns("dump"))
  )
}

module_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    output$map <- render_stage_map(map)
    observeEvent(input$pick_a, stage_map_select(stage_map_proxy("map"), "a"))
    output$dump <- renderText(json(selected = input$map_selected, state = input$map_state))
  })
}

ui <- fluidPage(
  tabsetPanel(
    id = "tabs",
    tabPanel(
      "One",
      uiOutput("slot"),
      actionButton("redraw", "Draw the slot again"),
      actionButton("select_hidden", "Select b in the hidden map"),
      actionButton("insert", "Insert a map"),
      actionButton("remove", "Remove the inserted map"),
      actionButton("modal", "Open a modal"),
      actionButton("hide_many", "Hide every card of the many map"),
      tags$div(id = "placeholder")
    ),
    tabPanel("Hidden", stage_map_output("hidden_map", height = "300px")),
    tabPanel("Many", stage_map_output("many_map", height = "300px")),
    tabPanel("Eager", stage_map_output("eager_map", height = "300px")),
    tabPanel("Modules", module_ui("m1"), module_ui("m2"))
  ),
  verbatimTextOutput("dump")
)

server <- function(input, output, session) {
  draws <- reactiveVal(1L)
  output$slot <- renderUI({
    draws()
    stage_map_output("main")
  })
  output$main <- render_stage_map(map)
  output$hidden_map <- render_stage_map(map)
  output$many_map <- render_stage_map(many_map)
  output$eager_map <- render_stage_map(map)
  # An output that is drawn although its tab is hidden.
  outputOptions(output, "eager_map", suspendWhenHidden = FALSE)
  observeEvent(input$hide_many, stage_map_hide(stage_map_proxy("many_map"), many_ids))
  output$extra <- render_stage_map(map)
  output$modal_map <- render_stage_map(map)
  observeEvent(input$redraw, draws(draws() + 1L))
  observeEvent(input$select_hidden, stage_map_select(stage_map_proxy("hidden_map"), "b"))
  observeEvent(input$insert, insertUI("#placeholder", ui = tags$div(id = "inserted", stage_map_output("extra"))))
  observeEvent(input$remove, removeUI("#inserted"))
  observeEvent(input$modal, showModal(modalDialog(stage_map_output("modal_map"), easyClose = TRUE)))
  module_server("m1")
  module_server("m2")
  output$dump <- renderText(
    json(
      main = input$main_selected,
      hidden = input$hidden_map_selected,
      extra = input$extra_selected,
      modal = input$modal_map_selected,
      many_hidden = if (!is.null(input$many_map_state)) jsonlite::unbox(length(input$many_map_state$hidden)),
      eager_state = input$eager_map_state$selected,
      eager_selected = input$eager_map_selected,
      draws = jsonlite::unbox(draws())
    )
  )
}

shinyApp(ui, server)
