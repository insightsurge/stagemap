#' Say hello
#'
#' A placeholder that lets the package build, test and publish its website while the real functions are designed. It
#' will be removed once they arrive.
#'
#' @param name A single string: who to greet.
#' @returns The greeting, a single string, invisibly. The greeting is also shown as a message.
#' @export
#' @examples
#' hello_stagemap()
#' hello_stagemap("relation maps")
hello_stagemap <- function(name = "world") {
  checkmate::assert_string(name, min.chars = 1)
  greeting <- paste0("Hello, ", name, "!")
  cli::cli_inform(greeting)
  invisible(greeting)
}
