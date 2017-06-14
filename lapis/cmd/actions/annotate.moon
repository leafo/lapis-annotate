import default_environment from require "lapis.cmd.util"

shell_escape = (str) ->
  "'#{str\gsub "'", "''"}'"

exec = (cmd) ->
  f = io.popen cmd
  with f\read("*all")\gsub "%s*$", ""
    f\close!

extract_header = (config, model) ->
  table_name = model\table_name!
  database = assert config.postgres.database, "missing db"

  command = { }

  if password = config.postgres.password
    table.insert command, "PGPASSWORD=#{shell_escape password}"

  table.insert command, "pg_dump --schema-only"

  if host = config.postgres.host
    table.insert command, "-h #{shell_escape host}"

  if user = config.postgres.user
    table.insert command, "-U #{shell_escape user}"

  table.insert command, "-t #{shell_escape table_name}"
  table.insert command, shell_escape database

  schema = exec table.concat command, " "

  in_block = false

  filtered = for line in schema\gmatch "[^\n]+"
    if in_block
      in_block = false unless line\match "^%s"
      continue if in_block

    continue if line\match "^%-%-"
    continue if line\match "^SET"
    continue if line\match "^ALTER SEQUENCE"

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

extract_header2 = (config, model) ->
  table_name = model\table_name!
  schema = exec "psql -U postgres #{assert config.postgres.database, "missing db"} -c '\\d #{table_name}'"
  lines = for line in schema\gmatch "[^\n]+"
    "-- #{line\gsub "%s+^", ""}"

  table.insert lines, 1, "--"
  table.insert lines, 1, "-- Generated schema dump: (do not edit)"
  table.insert lines, "--"

  table.concat lines, "\n"

annotate_model = (config, fname) ->
  source_f = io.open fname, "r"
  source = source_f\read "*all"
  source_f\close!

  model = if fname\match ".moon$"
    moonscript = require "moonscript.base"
    assert moonscript.loadfile(fname)!
  else
    assert loadfile(fname)!

  header = extract_header config, model

  source_with_header = if source\match "%-%- Generated .-\nclass "
    source\gsub "%-%- Generated .-\nclass ", "#{header}\nclass ", 1
  else
    source\gsub "class ", "#{header}\nclass ", 1

  source_out = io.open fname, "w"
  source_out\write source_with_header
  source_out\close!

{
  name: "annotate"
  usage: "annotate models/model1.moon models/model2.moon ..."
  help: "annotate a model with schema"

  (flags, ...) =>
    args = { ... }
    config = require("lapis.config").get!

    unless next args
      error "no models passed to annotate"

    for fname in *args
      print "Annotating #{fname}"
      annotate_model config, fname

}
