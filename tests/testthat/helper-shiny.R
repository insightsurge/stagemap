# A session that records what the proxy does: its namespace prefix, the inputs it has seen, the flush callbacks it was
# given and the custom messages it sent. It stands in for Shiny's session, which the proxy only talks to through these.
fake_session <- function(prefix = "mod-", input = list()) {
  session <- new.env()
  session$ns <- function(id) paste0(prefix, id)
  session$userData <- new.env()
  session$input <- input
  session$flush_callbacks <- list()
  session$flush_requests <- 0L
  session$sent <- list()
  session$onFlushed <- function(fun, once = TRUE) {
    session$flush_callbacks[[length(session$flush_callbacks) + 1L]] <- fun
  }
  session$requestFlush <- function() session$flush_requests <- session$flush_requests + 1L
  session$sendCustomMessage <- function(type, message) {
    session$sent[[length(session$sent) + 1L]] <- list(type = type, message = message)
  }
  session$flush <- function() {
    callbacks <- session$flush_callbacks
    session$flush_callbacks <- list()
    for (callback in callbacks) {
      callback()
    }
  }
  session
}
