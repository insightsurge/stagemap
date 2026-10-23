describe("hello_stagemap()", {
  it("greets the world by default and returns the greeting invisibly", {
    expect_message(out <- withVisible(hello_stagemap()), "Hello, world!", fixed = TRUE)
    expect_identical(out$value, "Hello, world!")
    expect_false(out$visible)
  })

  it("greets the name it is given", {
    expect_message(greeting <- hello_stagemap("relation maps"), "Hello, relation maps!", fixed = TRUE)
    expect_identical(greeting, "Hello, relation maps!")
  })

  it("checks its argument", {
    expect_error(hello_stagemap(""), "name")
    expect_error(hello_stagemap(c("a", "b")), "name")
    expect_error(hello_stagemap(1), "name")
  })
})
