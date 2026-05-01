shell_escape = (str) ->
  "'#{str\gsub "'", "''"}'"

exec = (cmd) ->
  f = io.popen cmd
  with f\read("*all")\gsub "%s*$", ""
    f\close!

DEFAULT_SCHEMA = "public"

-- Build a `pg_dump` / `psql` invocation, prefixing PGPASSWORD when needed and
-- appending host/user/database from the supplied Lapis config.
build_command = (cmd, config) ->
  database = assert config.postgres and config.postgres.database, "missing postgres database configuration"

  command = { cmd }

  if password = config.postgres.password
    table.insert command, 1, "PGPASSWORD=#{shell_escape password}"

  if host = config.postgres.host
    table.insert command, "-h #{shell_escape host}"

  if user = config.postgres.user
    table.insert command, "-U #{shell_escape user}"

  table.insert command, shell_escape database
  table.concat command, " "

-- Run `pg_dump --schema-only` for the model's table and return an array of
-- cleaned-up SQL lines (comments, SET statements, sequence noise stripped).
extract_schema_sql = (config, model) ->
  table_name = model\table_name!

  schema = exec build_command "pg_dump --schema-only -t #{shell_escape table_name}", config

  in_block = false

  return for line in schema\gmatch "[^\n]+"
    if in_block
      in_block = false unless line\match "^%s"
      continue if in_block

    continue if line\match "^%-%-"
    continue if line\match "^SET"
    continue if line\match "^ALTER SEQUENCE"
    continue if line\match "^SELECT"
    continue if line\match "^\\restrict"
    continue if line\match "^\\unrestrict"

    line = line\gsub "#{DEFAULT_SCHEMA}%.#{table_name}", table_name

    if line\match("^ALTER TABLE" ) and not line\match("^ALTER TABLE ONLY") or line\match "nextval"
      continue

    if line\match "CREATE SEQUENCE"
      in_block = true
      continue

    line\gsub "    ", "  "

-- Run `psql \\d <table>` and return the lines of the human-readable table
-- description, with trailing whitespace trimmed.
extract_schema_table = (config, model) ->
  table_name = model\table_name!
  schema = exec build_command "psql -c #{shell_escape "\\d #{table_name}"}", config

  return for line in schema\gmatch "[^\n]+"
    line\gsub("%s+$", "")

{
  :build_command
  :extract_schema_sql
  :extract_schema_table
}
