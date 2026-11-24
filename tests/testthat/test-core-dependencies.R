describe("sm_dependencies()", {
  dependency <- function() sm_dependencies()[[1]]

  it("is one dependency: d3 and the stage-map files, named after the package", {
    expect_length(sm_dependencies(), 1L)
    expect_identical(dependency()$name, "stagemap")
  })

  it("lists the files in the order the contract does, scripts and styles apart", {
    files <- kit_contract()$files
    files <- unlist(files)
    expect_identical(dependency()$script, files[endsWith(files, ".js")])
    expect_identical(dependency()$stylesheet, files[endsWith(files, ".css")])
    # d3 comes before the engine that draws with it
    expect_identical(dependency()$script, c("d3.min.js", "stage-map.js"))
    expect_identical(dependency()$stylesheet, "stage-map.css")
  })

  it("gives the dependency the engine's version, not the package's", {
    version <- as.character(dependency()$version)
    expect_identical(version, sm_kit_version())
    expect_false(identical(version, as.character(utils::packageVersion("stagemap"))))
  })

  it("ships every file it lists in the installed package, and copies only those", {
    directory <- dependency()$src$file
    expect_true(dir.exists(directory))
    expect_true(all(file.exists(file.path(directory, c(dependency()$script, dependency()$stylesheet)))))
    expect_false(dependency()$all_files)
  })

  it("lists no fonts: the map uses the page's own", {
    expect_false(any(grepl("font", c(dependency()$script, dependency()$stylesheet), ignore.case = TRUE)))
  })

  it("comes with the widget", {
    widget <- sm_widget(map_data())
    expect_identical(vapply(widget$dependencies, function(d) d$name, ""), "stagemap")
  })
})
