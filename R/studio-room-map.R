# Map room view: stage_map() layout and display options form.
studio_room_map_view <- function(state) {
  checkmate::assert_list(state, names = "unique")
  list(fields = list())
}
