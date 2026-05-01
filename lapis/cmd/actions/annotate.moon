import extract_schema_sql, extract_schema_table from require "lapis.annotate.pg_schema"

-- this can be used to annotate enum columns with a comment in the schema
enum_to_comment = (enum) ->
  keys = [k for k in pairs enum when type(k) == "number"]
  table.sort keys
  "enum(" .. table.concat(["#{enum[k]} = #{k}" for k in *keys], ", ") .. ")"

print_enum_comments_for_model = (model, table_model) ->
  if type(model) == "string"
    model = require model

  table_model = model unless table_model

  import instance_of from require "tableshape.moonscript"
  import Enum from require "lapis.db.model"

  is_enum = instance_of(Enum)\describe "db.enum"

  db = require "lapis.db" -- NOTE: this the default environment

  import singularize from require "lapis.util"
  for k,v in pairs model
    continue unless is_enum v
    table_name = table_model\table_name!
    column_name = singularize k

    print [[db.query(%q, %q)]]\format(
      "comment on column #{db.escape_identifier table_name}.#{db.escape_identifier column_name} is ?"
      enum_to_comment v
    )

  if model.__parent
    print_enum_comments_for_model model.__parent, table_model


replace_header = (input, replacement) ->
  import P, S, Cs from require("lpeg")
  newline = P"\r"^-1 * P"\n"
  rest_of_line = (1 - newline)^0 * (newline + P -1)

  comment = P "--" * rest_of_line

  existing_header = P("-- Generated schema dump") * rest_of_line * comment^0
  replaced_header = Cs existing_header / replacement

  patt = Cs (1 - replaced_header)^0 * replaced_header * P(1)^0
  patt\match input

annotate_model = (config, fname, options={}) ->
  source_f = assert io.open fname, "r"
  source = assert source_f\read "*all"
  source_f\close!

  model = if fname\match ".moon$"
    moonscript = require "moonscript.base"
    assert assert(moonscript.loadfile(fname))!
  else
    assert assert(loadfile(fname))!

  header_lines = switch options.format
    when "sql"
      extract_schema_sql config, model
    when "table"
      extract_schema_table config, model
    when "generate_enum_comments"
      print_enum_comments_for_model model
      return
    else
      error "Unimplemented format: #{options.format}"

  if options.print
    print table.concat header_lines, "\n"
    return

  -- turn it into a Lua/Moon comment
  table.insert header_lines, 1, ""
  table.insert header_lines, 1, "Generated schema dump: (do not edit)"
  table.insert header_lines, ""

  for idx, line in ipairs header_lines
    header_lines[idx] = "-- #{line}"\gsub("%s+$", "")

  header = table.concat(header_lines, "\n") .. "\n"

  updated_source = replace_header source, header

  -- TODO: this is kinda sloppy and only works with MoonScript
  unless updated_source
    updated_source = source\gsub "class ", "#{header}class ", 1

  source_out = assert io.open fname, "w"
  source_out\write updated_source
  source_out\close!

parsed_args = false

{
  argparser: ->
    parsed_args = true
    with require("argparse") "lapis annotate", "Extract schema information from model's table to comment model"
      \argument("files", "Paths to model classes to annotate (eg. models/first.moon models/second.moon ...)")\args "+"
      \option("--preload-module", "Module to require before annotating a model")\argname "<name>"
      \option("--format", "What dump format to use")\choices({"sql", "table", "generate_enum_comments"})\default "sql"
      \flag("--print -p", "Print the output instead of editing the model files")

  (args, lapis_args) =>
    assert parsed_args,
      "The version of Lapis you are using does not support this version of lapis-annotate. Please upgrade Lapis ≥ v1.14.0"

    if mod_name = args.preload_module
      assert type(mod_name) == "string", "preload-module must be a astring"
      require(mod_name)

    config = @get_config lapis_args.environment

    for fname in *args.files
      io.stderr\write "Annotating #{fname}\n"
      annotate_model config, fname, args
}
