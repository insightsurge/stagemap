# What the page shows, computed from the state: a named list of sections, each the value one renderer on the page draws.
# The server sends only the sections that changed (studio_message()). These are the sections the shell draws (the
# header, the status, the notice and the R code); the views of the document, the inspector, the journal and the rooms
# join them, and the code section's stand-in below gives way to the generated code.

# The view of `state`: the sections `header`, `status`, `notice` and `code`.
studio_view <- function(state) {
  checkmate::assert_list(state, names = "unique")
  title <- state$doc$args$title %||% ""
  list(
    header = list(title = title, facts = studio_facts(state$good$map), template = NULL),
    status = list(drawn_rev = state$good$rev, problems = nrow(state$check$faults), closed = state$closed),
    notice = state$notice,
    code = studio_view_code(title)
  )
}

# The line under the title that says how big the map is, such as "4 cards in 3 stages and 2 lanes".
studio_facts <- function(map) {
  checkmate::assert_class(map, "stagemap_widget")
  data <- sm_widget_data(map)
  count <- function(table, one, many) {
    n <- if (is.data.frame(data[[table]])) nrow(data[[table]]) else 0L
    sprintf("%d %s", n, if (n == 1L) one else many)
  }
  sprintf(
    "%s in %s and %s",
    count("cards", "card", "cards"),
    count("stages", "stage", "stages"),
    count("lanes", "lane", "lanes")
  )
}

# Projects `journal` entries to the fields the page receives (`n`, `verb`, `text`, `state`, `target`).
studio_view_journal <- function(journal) {
  checkmate::assert_list(journal)
  lapply(journal, function(entry) {
    entry[c("n", "verb", "text", "state", "target")]
  })
}

# The code section. A stand-in that the code room's generated code replaces: one line, a call that holds the title, so
# that Copy can be shown to copy what the server has.
studio_view_code <- function(title) {
  checkmate::assert_string(title)
  text <- sprintf("stage_map(cards, title = %s)", encodeString(title, quote = "\""))
  list(
    lines = list(list(spans = list(list(text, "")), changed = FALSE)),
    text = text,
    problem = NULL,
    downloads = list()
  )
}
