{
  name: "annotate"
  usage: "annotate models/my_model.moon"
  help: "annotate a model with schema"

  (...) =>
    flags, args = parse_flags { ... }
    { command, environment } = args

}
