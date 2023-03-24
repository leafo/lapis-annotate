import default_environment from require "lapis.cmd.util"

shell_escape = (str) ->
  "'#{str\gsub "'", "''"}'"

exec = (cmd) ->
  f = io.popen cmd
  with f\read("*all")\gsub "%s*$", ""
    f\close!

DEFAULT_SCHEMA = "public"

-- add configuration arguments to cmd, return unjoined command
build_command = (cmd, config) ->
  database = assert config.postgres and config.postgres.database, "missing postgres database configuration"

  command = { cmd }

  if password = config.postgres.password
    table.insert 1, command, "PGPASSWORD=#{shell_escape password}"

  if host = config.postgres.host
    table.insert command, "-h #{shell_escape host}"

  if user = config.postgres.user
    table.insert command, "-U #{shell_escape user}"

  table.insert command, shell_escape database
  table.concat command, " "

extract_header_sql = (config, model) ->
  table_name = model\table_name!

  schema = exec build_command "pg_dump --schema-only -t #{shell_escape table_name}", config

  in_block = false

  filtered = for line in schema\gmatch "[^\n]+"
    if in_block
      in_block = false unless line\match "^%s"
      continue if in_block

    continue if line\match "^%-%-"
    continue if line\match "^SET"
    continue if line\match "^ALTER SEQUENCE"
    continue if line\match "^SELECT"

    line = line\gsub "#{DEFAULT_SCHEMA}%.#{table_name}", table_name

    if line\match("^ALTER TABLE" ) and not line\match("^ALTER TABLE ONLY") or line\match "nextval"
      continue

    if line\match "CREATE SEQUENCE"
      in_block = true
      continue

    "-- " .. line\gsub "    ", "  "

  table.insert filtered, 1, "--"
  table.insert filtered, 1, "-- Generated schema dump: (do not edit)"
  table.insert filtered, "--"

  table.concat filtered, "\n"

extract_header_table = (config, model) ->
  table_name = model\table_name!
  schema = exec build_command "psql -c #{shell_escape "\\d #{table_name}"}", config

  lines = for line in schema\gmatch "[^\n]+"
    "-- #{line\gsub "%s+$", ""}"

  table.insert lines, 1, "--"
  table.insert lines, 1, "-- Generated schema dump: (do not edit)"
  table.insert lines, "--"

  table.concat lines, "\n"

annotate_model = (config, fname, options={}) ->
  source_f = assert io.open fname, "r"
  source = assert source_f\read "*all"
  source_f\close!

  model = if fname\match ".moon$"
    moonscript = require "moonscript.base"
    assert moonscript.loadfile(fname)!
  else
    assert loadfile(fname)!

  header = switch options.format
    when "sql"
      extract_header_sql config, model
    when "table"
      extract_header_table config, model

  if options.print
    print header
    return

  -- NOTE: this only works on moonscript for files that haven't been already processed
  source_with_header = if source\match "%-%- Generated .-\nclass "
    source\gsub "%-%- Generated .-\nclass ", "#{header}\nclass ", 1
  else
    source\gsub "class ", "#{header}\nclass ", 1

  source_out = io.open fname, "w"
  source_out\write source_with_header
  source_out\close!

parsed_args = false

{
  argparser: ->
    parsed_args = true
    with require("argparse") "lapis annotate", "Extract schema information from database table to comment model"
      \argument("files", "Paths to model classes to annotate (eg. models/first.moon models/second.moon ...)")\args "+"
      \option("--preload-module", "Module to require before annotating a model")\argname "<name>"
      \option("--format", "What dump format to use")\choices({"sql", "table"})\default "sql"
      \flag("--print", "Print the output instead of editing the model files")

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
