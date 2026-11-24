# the dots error / names a typo and an unnamed value, and lists the valid arguments

    Code
      sm_send(sm_proxy("map", session = fake_session()), "select", dat = "x", 3)
    Condition
      Error in `sm_send()`:
      ! Arguments after `...` must be named, and these are not arguments of this function: 1 unnamed value and `dat`.
      i Valid arguments: `proxy`, `command`, and `data`.

# the unknown-command warning / lists the commands the contract has

    Code
      sm_send(sm_proxy("map", session = fake_session()), "selct")
    Condition
      Warning in `sm_send()`:
      The command "selct" was not sent: the stage map does not take it.
      i Commands it takes: "select", "highlight", "hosted", "size", "history", "show", "hide", "disable", "enable", and "state".

