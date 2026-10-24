# stagemap output / prints the example map

    Code
      print(stagemap(nodes, links))
    Output
      <stagemap> 4 nodes, 2 links
      Stages (3): Requirement, Test, Result
      Lanes (2): Safety, Usability
      Kinds (2): verifies, produces

# stagemap output / explains a missing column

    Code
      stagemap(data.frame(id = "a"))
    Condition
      Error in `stagemap()`:
      ! `nodes` is missing required columns: stage. Columns present: id.

# stagemap output / explains an unknown endpoint

    Code
      stagemap(data.frame(id = "a", stage = "S"), data.frame(from = "a", to = "unknown"))
    Condition
      Error in `stagemap()`:
      ! Row 1 of `links` has an unknown node id in column to.
      i Unknown ids: "unknown".

# stagemap output / explains unexpected arguments

    Code
      stagemap(data.frame(id = "a", stage = "S"), foo = 1)
    Condition
      Error in `stagemap()`:
      ! Unexpected arguments: "foo".
      i `stagemap()` takes only `nodes` and `links`.

