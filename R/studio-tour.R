# Guided tour definitions and server-side proof ticking. Once a step is ticked it stays ticked.

studio_tours <- list(
  example = list(
    title = "Try the studio",
    steps = list(
      list(
        text = "Open the example map.",
        done = function(state) identical(state$template, "example")
      ),
      list(
        text = "Click round_dose() and set its status to Done.",
        done = function(state) {
          cards <- state$doc$tables$cards
          idx <- match("round_dose", as_text(cards$id))
          !is.na(idx) && "status" %in% names(cards) && identical(as_text(cards$status[[idx]]), "done")
        }
      ),
      list(
        text = "Select Log every call and connect it to calc_dose().",
        done = function(state) {
          links <- state$doc$tables$links
          is.data.frame(links) &&
            nrow(links) > 0L &&
            any(as_text(links$from) == "log_calls" & as_text(links$to) == "calc_dose", na.rm = TRUE)
        }
      ),
      list(
        text = "Open R code: the new link is marked as changed.",
        done = function(state) "code" %in% state$seen
      ),
      list(
        text = "Under Ask, trace everything downstream of Doses scale with weight.",
        done = function(state) {
          !is.null(state$ask) && identical(state$ask$question, "trace") && is.null(state$ask$error)
        }
      ),
      list(
        text = "Under Check, apply the fix for the link that points at nothing.",
        done = function(state) isTRUE(state$check$ok) && nrow(state$check$faults) == 0L
      )
    )
  )
)

# Evaluates the tour's step proofs on `state` and sets `state$tour$done`. A ticked step stays ticked.
studio_tour_tick <- function(state) {
  checkmate::assert_list(state, names = "unique")
  if (is.null(state$tour)) {
    return(state)
  }
  tour <- studio_tours[[state$tour$id]]
  if (is.null(tour)) {
    return(state)
  }
  done <- state$tour$done
  for (i in seq_along(tour$steps)) {
    if (!isTRUE(done[[i]]) && isTRUE(tour$steps[[i]]$done(state))) {
      done[[i]] <- TRUE
    }
  }
  state$tour$done <- done
  state
}
