# R code room view: generated R code lines for the current document.
studio_room_code_view <- function(state) {
  checkmate::assert_list(state, names = "unique")
  lines <- code_map(studio_doc_parts(state$doc))
  list(
    lines = lapply(lines, function(line) list(spans = list(list(line, "")), changed = FALSE)),
    text = paste(lines, collapse = "\n"),
    problem = NULL,
    downloads = list()
  )
}
