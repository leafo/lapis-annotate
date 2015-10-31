return {
  name = "annotate",
  usage = "annotate models/my_model.moon",
  help = "annotate a model with schema",
  function(self, ...)
    local flags, args = parse_flags({
      ...
    })
    local command, environment
    command, environment = args[1], args[2]
  end
}
