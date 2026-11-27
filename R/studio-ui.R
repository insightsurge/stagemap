# The studio's page: the skeleton from R (bare htmltools tags, no Bootstrap), the one htmlDependency that brings its
# script and styles, and the boot JSON that carries the page's settings and words. The page's script fills the skeleton
# from the server's messages; nothing here holds data of the map. The inspector, the journal, the start card and the
# Map, Ask and Check rooms are empty and hidden here: their views fill them.

# The studio's page for the module `id`. `options` are the page's settings (studio_options()), written into the boot
# JSON.
studio_ui <- function(id, options = list()) {
  checkmate::assert_string(id, min.chars = 1L)
  options <- studio_options(options)
  rlang::check_installed("shiny")
  ns <- shiny::NS(id)
  tags <- htmltools::tags
  ui <- htmltools::tagList(
    tags$head(
      tags$title("stagemap studio"),
      tags$meta(name = "viewport", content = "width=device-width, initial-scale=1, viewport-fit=cover"),
      tags$meta(name = "color-scheme", content = "light dark")
    ),
    studio_dependency(),
    tags$div(
      class = "sms",
      `data-sms-ns` = ns(""),
      `data-theme` = "auto",
      tags$a(class = "sms-skip", href = paste0("#", ns("map")), "Skip to the map"),
      tags$main(
        class = "sms-sheet",
        `aria-label` = "The map",
        studio_ui_top(ns),
        tags$div(class = "sms-journal", id = ns("journal"), hidden = NA),
        tags$div(
          class = "sms-paper",
          tags$p(class = "sms-stamp", role = "status"),
          stage_map_output(ns("map"))
        ),
        studio_ui_hint(ns),
        tags$section(
          class = "sms-start",
          id = ns("start"),
          role = "dialog",
          `aria-modal` = "true",
          `aria-label` = "Start",
          hidden = NA
        )
      ),
      tags$aside(
        class = "sms-inspector",
        id = ns("inspector"),
        `aria-label` = "Inspector",
        hidden = NA,
        inert = NA
      ),
      studio_ui_block(ns),
      tags$div(
        class = "sms-tray",
        id = ns("tray"),
        inert = NA,
        studio_ui_room(ns, "map", "Map"),
        studio_ui_room(ns, "ask", "Ask the map"),
        studio_ui_room(ns, "check", "Check"),
        studio_ui_room(
          ns,
          "code",
          "R code",
          head = list(
            tags$span(class = "sms-kick sms-code-sum"),
            tags$button(class = "sms-btn sms-pri", type = "button", `data-sms-copy` = "code", "Copy")
          ),
          body = list(
            tags$pre(class = "sms-code", tabindex = "0", `aria-label` = "R code for this map"),
            tags$p(class = "sms-code-note"),
            tags$div(
              class = "sms-code-downloads",
              hidden = NA,
              `aria-hidden` = "true",
              shiny::downloadLink(ns("download_r"), "map.R", class = "sms-dl"),
              lapply(map_table_names, function(tbl) {
                shiny::downloadLink(ns(paste0("download_csv_", tbl)), paste0(tbl, ".csv"), class = "sms-dl")
              })
            )
          )
        )
      ),
      tags$div(
        class = "sms-toast",
        role = "status",
        tags$span(class = "sms-toast-mark", `aria-hidden` = "true", "!"),
        tags$span(class = "sms-toast-tone"),
        tags$span(class = "sms-toast-text")
      ),
      tags$div(class = "sms-closed", role = "status"),
      tags$script(type = "application/json", class = "sms-boot", studio_boot(options))
    )
  )
  attr(ui, "lang") <- "en"
  ui
}

# The header above the map: the revision, the title field (whose edits are `option` events for `title`), the facts and
# the actions. Caller: studio_ui(), with `ns` from shiny::NS().
studio_ui_top <- function(ns) {
  checkmate::assert_function(ns)
  tags <- htmltools::tags
  tags$header(
    class = "sms-top",
    tags$p(class = "sms-kick", "Map, revision ", tags$span(class = "sms-rev", "0")),
    tags$input(
      class = "sms-title",
      id = ns("title"),
      type = "text",
      `aria-label` = "Map title",
      placeholder = "Name the map",
      autocomplete = "off",
      spellcheck = "false",
      # The studio sends the field's edits itself: Shiny's text input binding must leave it alone.
      `data-shiny-no-bind-input` = NA,
      `data-sms-event` = studio_json(list(type = "option", data = list(name = "title")))
    ),
    tags$p(class = "sms-facts"),
    tags$div(
      class = "sms-acts",
      tags$nav(class = "sms-outline", `aria-label` = "Change the map", hidden = NA),
      tags$button(class = "sms-btn", type = "button", `data-sms-start` = "open", "Open map"),
      # The Map cell of the title block is hidden on a phone; this opener takes its place there (CSS).
      tags$button(
        class = "sms-btn sms-phone-map",
        type = "button",
        `data-sms-room` = "map",
        `aria-expanded` = "false",
        `aria-controls` = ns("room-map"),
        "Map"
      ),
      # A switch like the title block's: the page keeps `aria-checked` in step with the mode, and the name starts with
      # the visible words.
      tags$button(
        class = "sms-btn sms-phone-theme",
        type = "button",
        role = "switch",
        `aria-checked` = "false",
        `aria-label` = "Light or dark, dark mode",
        `data-sms-theme` = "toggle",
        "Light or dark"
      )
    )
  )
}

# The bar under the map: what the pointer is over (`.sms-hint-text`), or else the guide's next step (`.sms-hint-next`)
# with the "Try it" button and the list of steps it opens. The page fills them from the `tour` section and the engine's
# hover event; both lines are polite status regions.
studio_ui_hint <- function(ns) {
  checkmate::assert_function(ns)
  tags <- htmltools::tags
  tags$div(
    class = "sms-hint",
    hidden = NA,
    tags$p(class = "sms-hint-text", `aria-live` = "polite"),
    tags$p(class = "sms-hint-next", `aria-live` = "polite"),
    tags$button(
      class = "sms-btn sms-try-btn",
      type = "button",
      `data-sms-try` = "toggle",
      `aria-expanded` = "false",
      `aria-controls` = ns("try"),
      hidden = NA
    ),
    tags$div(
      class = "sms-try",
      id = ns("try"),
      role = "group",
      `aria-labelledby` = ns("try-title"),
      hidden = NA,
      tags$h2(id = ns("try-title"), tabindex = "-1"),
      tags$ol()
    )
  )
}

# One room of the tray, `name`, with its heading `title`, closed: hidden and inert until its button opens it. `head` and
# `body` are extra tags for the room's head and body.
studio_ui_room <- function(ns, name, title, head = list(), body = list()) {
  checkmate::assert_function(ns)
  checkmate::assert_string(name, min.chars = 1L)
  checkmate::assert_string(title, min.chars = 1L)
  checkmate::assert_list(head)
  checkmate::assert_list(body)
  tags <- htmltools::tags
  tags$section(
    class = "sms-room",
    id = ns(paste0("room-", name)),
    `data-sms-room-of` = name,
    `aria-labelledby` = ns(paste0("room-", name, "-title")),
    hidden = NA,
    inert = NA,
    tags$div(
      class = "sms-room-head",
      # Focus goes to the heading when the room opens, so the next Tab reaches the room's first control.
      tags$h2(id = ns(paste0("room-", name, "-title")), tabindex = "-1", title),
      head,
      tags$button(
        class = "sms-btn",
        type = "button",
        `data-sms-close` = name,
        `aria-label` = paste("Close", title),
        "Close"
      )
    ),
    tags$div(class = "sms-room-body", body)
  )
}

# The title block along the bottom: the name, a button for each room, the theme switch and Done.
studio_ui_block <- function(ns) {
  checkmate::assert_function(ns)
  tags <- htmltools::tags
  room_button <- function(name, label, value) {
    tags$button(
      class = "sms-cell",
      type = "button",
      `data-sms-room` = name,
      `aria-expanded` = "false",
      `aria-controls` = ns(paste0("room-", name)),
      tags$span(class = "sms-lab", label),
      tags$span(class = "sms-val", value)
    )
  }
  tags$nav(
    class = "sms-block",
    `aria-label` = "Studio",
    tags$div(
      class = "sms-cell sms-brand",
      htmltools::HTML(studio_brand_svg),
      tags$div(tags$b("stagemap"), " ", tags$span("studio"))
    ),
    room_button("map", "Map", tags$span(class = "sms-map-name")),
    room_button(
      "ask",
      "Ask",
      list(tags$span(class = "sms-long", "Trace, loose ends, gaps"), tags$span(class = "sms-short", "Questions"))
    ),
    room_button(
      "check",
      "Check",
      list(tags$span(class = "sms-long", "Problems and fixes"), tags$span(class = "sms-short", "Problems"))
    ),
    room_button("code", "R code", tags$span(class = "sms-code-count")),
    tags$button(
      class = "sms-theme",
      type = "button",
      role = "switch",
      `aria-checked` = "false",
      # The accessible name starts with the visible words, as the label-in-name rule asks.
      `aria-label` = "Theme, dark mode",
      `data-sms-theme` = "toggle",
      tags$span(class = "sms-lab", "Theme"),
      tags$span(
        class = "sms-theme-opts",
        `aria-hidden` = "true",
        tags$span(`data-sms-mode` = "light", "Light"),
        tags$span(`data-sms-mode` = "dark", "Dark")
      )
    ),
    tags$button(
      class = "sms-cell sms-done",
      type = "button",
      `data-sms-event` = studio_json(list(type = "done", data = structure(list(), names = character()))),
      tags$span(class = "sms-lab", "Done"),
      tags$span(class = "sms-val sms-back", "Back to R")
    )
  )
}

# The studio's mark: three cards joined by links, drawn in the text colour with the last card in the accent (CSS).
studio_brand_svg <- paste0(
  "<svg class=\"sms-mark\" width=\"30\" height=\"22\" viewBox=\"0 0 30 22\" aria-hidden=\"true\">",
  "<rect x=\"1\" y=\"2\" width=\"9\" height=\"7\" rx=\"1\"/>",
  "<rect x=\"11\" y=\"13\" width=\"9\" height=\"7\" rx=\"1\"/>",
  "<rect class=\"sms-mark-on\" x=\"21\" y=\"2\" width=\"8\" height=\"7\" rx=\"1\"/>",
  "<path d=\"M10 5.5h3v11M20 16.5h3V9\"/>",
  "</svg>"
)

# The page's settings, checked, with their defaults: `copy_wait_ms` (how long Copy waits for the server, 5000) and
# `hold_ms` (how long typed text is held before it is sent, 450).
studio_options <- function(options) {
  checkmate::assert_list(options, names = "unique")
  checkmate::assert_subset(names(options), c("copy_wait_ms", "hold_ms"))
  checkmate::assert_count(options$copy_wait_ms, positive = TRUE, null.ok = TRUE)
  checkmate::assert_count(options$hold_ms, null.ok = TRUE)
  list(
    copy_wait_ms = as.integer(options$copy_wait_ms %||% 5000L),
    hold_ms = as.integer(options$hold_ms %||% 450L)
  )
}

# The boot JSON: the words the page writes itself, the settings, the names of the engine's events (from its contract)
# and whether Done is offered.
studio_boot <- function(options) {
  checkmate::assert_list(options, names = "unique")
  prefix <- sm_spec()$prefix
  boot <- list(
    labels = studio_labels(),
    copy_wait_ms = options$copy_wait_ms,
    hold_ms = options$hold_ms,
    events = list(select = paste0(prefix, ":select"), hover = paste0(prefix, ":hover")),
    done = TRUE
  )
  # Written inside a script element, so a "<" is escaped to keep "</script>" out of it.
  htmltools::HTML(gsub("<", "\\u003c", studio_json(boot), fixed = TRUE))
}

# The words the page writes itself (the rest come from R in the view).
studio_labels <- function() {
  list(
    copied = "Copied the R code.",
    copy_late = "Could not copy: the server did not answer in time. Try again.",
    download_late = "Could not download: the server did not answer in time. Try again.",
    copy_manual = "Could not copy by itself. The code is selected: press Ctrl+C (Cmd+C on a Mac).",
    closed = "The map has gone back to R. You can close this tab.",
    problem = "Problem",
    line = "line",
    lines = "lines",
    undo = "Undo",
    undone = "undone",
    journal = "Journal",
    close = "Close",
    close_inspector = "Close inspector",
    empty_list = "None",
    start_kicker = "stagemap studio",
    start_heading = "Click the map to change it.",
    start_body_1 = paste(
      "A map puts things in stages and lanes and joins them with links that mean something.",
      "Pick a card, a stage, a lane or a link and an inspector opens beside it."
    ),
    start_body_2 = "The R code follows every edit, and questions about the map are one sentence away.",
    start_open = "Open",
    start_confirm = "Confirm",
    stamp_prefix = "The map shows the last version that worked:",
    problem_one = "problem",
    problem_many = "problems",
    clean = "Clean",
    info = "Info:",
    error = "Error:",
    show = "Show",
    fix_prefix = "Fix:",
    r_message = "R check message",
    notes = "Notes",
    guide_next = "Next:",
    guide_try = "Try it",
    guide_done = "done",
    guide_all_done = "Every step is done.",
    changed = "changed",
    ask_question = "Question",
    ask_failed = "Could not run question",
    ask_stale = "Map changed since: ask again",
    ask_clear = "Clear",
    ask_nothing = "Nothing to list.",
    ask_none = "No questions available.",
    legend_blue = "blue pencil edits",
    legend_red = "red pencil flags a problem",
    legend_mark = "yellow marks an answer",
    start_close = "Close start card",
    code_r = ".R",
    code_r_file = ".R file",
    code_csv = "CSV"
  )
}

# `x` as JSON, as the page reads it: one value is not an array.
studio_json <- function(x) {
  checkmate::assert_list(x)
  as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null"))
}

# The one htmlDependency of the studio's page: its module script (which imports the files under js/) and its styles.
# All files are copied, so the imports resolve.
studio_dependency <- function() {
  htmltools::htmlDependency(
    "stagemap-studio",
    unname(getNamespaceVersion("stagemap")),
    src = c(file = system.file("studio", package = "stagemap")),
    script = list(list(src = "studio.js", type = "module")),
    stylesheet = c(
      "css/tokens.css",
      "css/shell.css",
      "css/parts.css",
      "css/room-ask.css",
      "css/room-check.css",
      "css/room-code.css",
      "css/room-map.css",
      "css/room-tour.css"
    ),
    all_files = TRUE
  )
}
