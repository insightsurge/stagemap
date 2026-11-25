# A demo app for the stage map in Shiny, to try every function by hand. Give the folder that holds this file to
# runApp(): with the package installed, system.file("examples", "shiny-demo", package = "stagemap") is its path; from
# a source checkout, load the package first with devtools::load_all().
# The project is made up: a small garden shed, built in four stages. Everything here runs offline.
# An app attaches the packages it uses.
library(shiny) # nolint: undesirable_function_linter.
if (!"package:stagemap" %in% search()) {
  library(stagemap) # nolint: undesirable_function_linter.
}

# --- The made-up project ---------------------------------------------------------------------------------------

cards <- data.frame(
  id = c("plan", "permit", "base", "frame", "roof", "paint", "inspect", "handover"),
  label = c(
    "Draw the plan",
    "Ask for a permit",
    "Lay the base",
    "Build the frame",
    "Fit the roof",
    "Paint it",
    "Inspection",
    "Hand over the keys"
  ),
  stage = c("plan", "plan", "build", "build", "build", "finish", "check", "check"),
  lane = c("design", "paper", "build", "build", "build", "build", "paper", "paper"),
  status = c("done", "done", "done", "running", "waiting", "waiting", "waiting", "waiting"),
  zone = c(NA, NA, NA, NA, NA, NA, "signoff", "signoff"),
  variants = c(NA, NA, NA, NA, NA, "full", NA, NA),
  sub = c("Ana", "Ben", "Cho", "Cho", "Dev", "Eli", "Ben", "Ana")
)
stages <- data.frame(
  id = c("plan", "build", "finish", "check"),
  label = c("Plan", "Build", "Finish", "Check"),
  text = c("Where the shed goes, and what it needs.", "The shed takes shape.", "Paint and trim.", "Sign-off."),
  date = c("2026-03-02", "2026-03-03", "2026-03-04", "2026-03-05")
)
lanes <- data.frame(id = c("design", "paper", "build"), label = c("Design", "Paperwork", "Building"))
links <- data.frame(
  from = c("plan", "plan", "permit", "base", "frame", "roof", "paint", "inspect"),
  to = c("permit", "base", "base", "frame", "roof", "paint", "inspect", "handover"),
  kind = c("hand", NA, "hand", NA, NA, NA, "check", "check")
)
kinds <- data.frame(
  id = c("hand", "check"),
  label = c("Handed over", "Needs a check"),
  line = c("dashed", "dotted")
)
steps <- data.frame(
  id = c("s1", "s2", "s3"),
  label = c("Start", "Frame goes up", "Finish"),
  stage = c("plan", "build", "check")
)
changes <- data.frame(step = c("s2", "s3"), card = c("frame", "roof"), status = c("done", "running"))
zones <- data.frame(id = "signoff", label = "Needs sign-off", note = "Two people read it before the keys change hands.")
variants <- data.frame(id = c("full", "basic"), label = c("Full finish", "Basic finish"))

# The map for a layout: the grid draws every kind of data; "levels" flows each lane into one card and has variants;
# "dates" draws a table of lanes by stages, one stage a day.
build_map <- function(layout) {
  base <- if (identical(layout, "levels")) {
    stage_map(cards, stages, lanes, title = "Garden shed", layout = "levels", target = "handover", variant = "full")
  } else {
    stage_map(cards, stages, lanes, title = "Garden shed", layout = layout)
  }
  base |>
    add_links(links, kinds = kinds) |>
    add_zones(zones) |>
    add_steps(steps, changes = changes) |>
    add_variants(variants)
}

# --- Trace questions: sm_trace(), sm_orphans() and sm_missing() -----------------------------------------------------
# The buttons below light the answers of sm_trace(), sm_orphans() and sm_missing() with stage_map_highlight().
stage_choices <- setNames(stages$id, stages$label)

# --- The page -------------------------------------------------------------------------------------------------------

ui <- fluidPage(
  titlePanel("stagemap: the shed demo"),
  sidebarLayout(
    sidebarPanel(
      width = 4,
      h4("Draw"),
      selectInput("layout", "Layout", c("grid", "levels", "dates")),
      h4("Choose cards"),
      selectInput("ids", "Cards for the buttons", setNames(cards$id, cards$label), multiple = TRUE),
      h4("Verbs"),
      actionButton("select", "Select"),
      actionButton("highlight", "Highlight"),
      actionButton("clear", "Let go of both"),
      br(),
      br(),
      actionButton("show", "Show"),
      actionButton("hide", "Hide"),
      br(),
      br(),
      textInput("reason", "Reason for a disabled card", "Waiting for the permit"),
      actionButton("enable", "Enable"),
      actionButton("disable", "Disable"),
      h4("Trace"),
      selectInput("direction", "Direction", c("downstream", "upstream", "both")),
      actionButton("trace", "Trace from the chosen cards"),
      actionButton("orphans", "Cards with no link"),
      selectInput("missing_stage", "Cards of this stage ...", stage_choices, selected = "check"),
      selectInput("missing_linked", "... with no link to this stage", stage_choices, selected = "build"),
      actionButton("missing", "Find the gaps"),
      # A long answer wraps inside the box instead of running off its right edge.
      textOutput(
        "trace_note",
        container = function(...) tags$pre(style = "white-space: pre-wrap; overflow-wrap: anywhere;", ...)
      )
    ),
    mainPanel(
      width = 8,
      stage_map_output("shed", "100%", "560px"),
      h4("What the server reads"),
      h5("input$shed_selected"),
      verbatimTextOutput("selected"),
      h5("input$shed_hovered (experimental)"),
      verbatimTextOutput("hovered"),
      h5("input$shed_pick"),
      verbatimTextOutput("pick"),
      h5("input$shed_state"),
      verbatimTextOutput("state")
    )
  )
)

server <- function(input, output, session) {
  output$shed <- render_stage_map(build_map(input$layout))
  proxy <- stage_map_proxy("shed", session)

  observeEvent(input$select, stage_map_select(proxy, input$ids))
  observeEvent(input$highlight, stage_map_highlight(proxy, input$ids))
  observeEvent(input$clear, {
    stage_map_select(proxy, NULL)
    stage_map_highlight(proxy, NULL)
  })
  observeEvent(input$show, stage_map_show(proxy, input$ids))
  observeEvent(input$hide, stage_map_hide(proxy, input$ids))
  observeEvent(input$enable, stage_map_enable(proxy, input$ids))
  observeEvent(input$disable, {
    req(nzchar(trimws(input$reason)))
    stage_map_disable(proxy, input$ids, input$reason)
  })

  # The trace buttons.
  note <- reactiveVal("")
  show_trace <- function(ids, what) {
    stage_map_highlight(proxy, ids)
    note(sprintf("%s: %s", what, if (length(ids) > 0L) paste(ids, collapse = ", ") else "none"))
  }
  # An error from a trace call is shown in the note; left alone, it would end the session.
  show_errors <- function(code) {
    tryCatch(code, error = function(e) note(paste("Could not answer:", conditionMessage(e))))
  }
  observeEvent(input$trace, {
    req(input$ids)
    show_errors({
      reached <- sm_trace(build_map(input$layout), input$ids, direction = input$direction)
      show_trace(reached$id, "Reached")
    })
  })
  observeEvent(input$orphans, {
    show_errors({
      loose <- sm_orphans(build_map(input$layout))
      show_trace(loose$id, "No link")
    })
  })
  observeEvent(input$missing, {
    req(input$missing_stage, input$missing_linked)
    show_errors({
      gaps <- sm_missing(
        build_map(input$layout),
        input$missing_stage,
        linked_to = input$missing_linked
      )
      show_trace(gaps$id, "Missing a link")
    })
  })
  output$trace_note <- renderText(note())

  output$selected <- renderPrint(input$shed_selected)
  output$hovered <- renderPrint(input$shed_hovered)
  output$pick <- renderPrint(str(input$shed_pick))
  output$state <- renderPrint(str(input$shed_state))
}

shinyApp(ui, server)
