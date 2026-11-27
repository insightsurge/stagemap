# The dependency builder. Caller: sm_widget(). It turns the engine's contract into one htmlDependency: d3 and the
# stage-map files, from inst/kit/, in the order the contract's `files` lists them (d3 first, which the engine draws
# with). The contract lists no fonts: the map uses the page's own font.

sm_path <- function(...) {
  system.file("kit", ..., package = "stagemap")
}

# The htmlDependency for the engine, versioned with the engine (not with the package), so a page that loads two
# copies can tell them apart. Only the listed files are copied when a page is saved.
sm_dependencies <- function() {
  files <- sm_spec()$files
  list(htmltools::htmlDependency(
    "stagemap",
    sm_kit_version(),
    src = c(file = sm_path()),
    script = files[endsWith(files, ".js")],
    stylesheet = files[endsWith(files, ".css")],
    all_files = FALSE
  ))
}
