# Check room view: build status, R's error lines, located fault cards with Show and Fix actions, and warnings.
studio_room_check_view <- function(state) {
  checkmate::assert_list(state, names = "unique")
  ok <- isTRUE(state$check$ok)
  faults_df <- state$check$faults
  faults <- if (is.data.frame(faults_df) && nrow(faults_df) > 0L) {
    lapply(seq_len(nrow(faults_df)), function(i) {
      f <- faults_df[i, , drop = FALSE]
      where_kind <- switch(f$table, cards = "card", stages = "stage", lanes = "lane", links = "link", NULL)
      where <- if (!is.null(where_kind)) {
        list(kind = where_kind, uid = f$uid, field = f$field)
      } else {
        NULL
      }
      fixes_raw <- studio_fixes(state$doc, f)
      fix_names <- names(fixes_raw)
      non_remove <- fix_names[fix_names != "remove"]
      primary_name <- if (length(non_remove) > 0L) non_remove[[1L]] else NULL
      fix_actions <- unname(lapply(fix_names, function(fix_name) {
        style <- if (identical(fix_name, "remove")) {
          "danger"
        } else if (identical(fix_name, primary_name)) {
          "primary"
        } else {
          "plain"
        }
        studio_action(
          fixes_raw[[fix_name]]$label,
          list(type = "fix", data = list(fault = f$id, fix = fix_name)),
          style = style
        )
      }))
      list(
        id = f$id,
        text = f$text,
        where = where,
        fixes = fix_actions
      )
    })
  } else {
    list()
  }
  list(
    ok = ok,
    head = if (ok) "stage_map() accepts this map." else state$check$head,
    lines = state$check$lines %||% list(),
    faults = faults,
    notes = as.list(state$check$notes %||% character())
  )
}
