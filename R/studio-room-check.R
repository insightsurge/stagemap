# Check room view: build status, messages and faults on the document.
studio_room_check_view <- function(state) {
  checkmate::assert_list(state, names = "unique")
  list(
    ok = isTRUE(state$check$ok),
    head = state$check$head,
    lines = state$check$lines %||% list(),
    faults = list(),
    notes = as.list(state$check$notes %||% character())
  )
}
