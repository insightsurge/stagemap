# Ask room view: questions and answers on the map.
studio_room_ask_view <- function(state) {
  checkmate::assert_list(state, names = "unique")
  list(questions = list(), answer = NULL)
}
