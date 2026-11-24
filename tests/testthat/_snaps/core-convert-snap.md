# the data error / lists problems with their paths

    Code
      sm_widget(data)
    Condition
      Error:
      ! The data cannot be turned into what the stage-map engine reads.
      x `stages` needs a column `label`.
      x `nodes$id[2]` is required but has NA.
      x `nodes$tone[2]` must be one of "teal", "good", "warn", "bad", "muted", "orange", "blue", "violet", "pink", "gold", "grey", not "bogus".

# the data error / counts the problems beyond the first ten

    Code
      sm_widget(data)
    Condition
      Error:
      ! The data cannot be turned into what the stage-map engine reads.
      x `stages$id[1]` is required but has NA.
      x `stages$label[1]` is required but has NA.
      x `lanes$id[1]` is required but has NA.
      x `lanes$label[1]` is required but has NA.
      x `nodes$id[1]` is required but has NA.
      x `nodes$label[1]` is required but has NA.
      x `nodes$stage[1]` is required but has NA.
      x `nodes$lane[1]` is required but has NA.
      x `nodes$tone[1]` must be one of "teal", "good", "warn", "bad", "muted", "orange", "blue", "violet", "pink", "gold", "grey", not "bogus".
      x `nodes$milestone` must be TRUE or FALSE, not character.
      i ... and 1 more.

# the unused-columns warning / names the dropped column and the valid ones

    Code
      invisible(sm_widget(data))
    Condition
      Warning:
      Some columns have no field in the stage-map engine, so they were left out.
      i Dropped `n` from `nodes`. Valid columns: id, label, stage, lane, sub, status, tone, text, zone, milestone, variants, hidden, disabled, reason.

# the unused-columns warning / calls an unknown entry of a named vector a name, not a column

    Code
      invisible(sm_widget(data))
    Condition
      Warning:
      Some names have no field in the stage-map engine, so they were left out.
      i Dropped `bogus` from `options$statuses`. Valid names: done, running, waiting, failed, skipped.

# the unused-columns warning / says columns or names when both were dropped

    Code
      invisible(sm_widget(data))
    Condition
      Warning:
      Some columns or names have no field in the stage-map engine, so they were left out.
      i Dropped `bogus` from `options$statuses`. Valid names: done, running, waiting, failed, skipped.
      i Dropped `n` from `nodes`. Valid columns: id, label, stage, lane, sub, status, tone, text, zone, milestone, variants, hidden, disabled, reason.

