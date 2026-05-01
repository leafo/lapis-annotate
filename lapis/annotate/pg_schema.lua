local shell_escape
shell_escape = function(str)
  return "'" .. tostring(str:gsub("'", "''")) .. "'"
end
local exec
exec = function(cmd)
  local f = io.popen(cmd)
  do
    local _with_0 = f:read("*all"):gsub("%s*$", "")
    f:close()
    return _with_0
  end
end
local DEFAULT_SCHEMA = "public"
local build_command
build_command = function(cmd, config)
  local database = assert(config.postgres and config.postgres.database, "missing postgres database configuration")
  local command = {
    cmd
  }
  do
    local password = config.postgres.password
    if password then
      table.insert(command, 1, "PGPASSWORD=" .. tostring(shell_escape(password)))
    end
  end
  do
    local host = config.postgres.host
    if host then
      table.insert(command, "-h " .. tostring(shell_escape(host)))
    end
  end
  do
    local user = config.postgres.user
    if user then
      table.insert(command, "-U " .. tostring(shell_escape(user)))
    end
  end
  table.insert(command, shell_escape(database))
  return table.concat(command, " ")
end
local extract_schema_sql
extract_schema_sql = function(config, model)
  local table_name = model:table_name()
  local schema = exec(build_command("pg_dump --schema-only -t " .. tostring(shell_escape(table_name)), config))
  local in_block = false
  return (function()
    local _accum_0 = { }
    local _len_0 = 1
    for line in schema:gmatch("[^\n]+") do
      local _continue_0 = false
      repeat
        if in_block then
          if not (line:match("^%s")) then
            in_block = false
          end
          if in_block then
            _continue_0 = true
            break
          end
        end
        if line:match("^%-%-") then
          _continue_0 = true
          break
        end
        if line:match("^SET") then
          _continue_0 = true
          break
        end
        if line:match("^ALTER SEQUENCE") then
          _continue_0 = true
          break
        end
        if line:match("^SELECT") then
          _continue_0 = true
          break
        end
        if line:match("^\\restrict") then
          _continue_0 = true
          break
        end
        if line:match("^\\unrestrict") then
          _continue_0 = true
          break
        end
        line = line:gsub(tostring(DEFAULT_SCHEMA) .. "%." .. tostring(table_name), table_name)
        if line:match("^ALTER TABLE") and not line:match("^ALTER TABLE ONLY") or line:match("nextval") then
          _continue_0 = true
          break
        end
        if line:match("CREATE SEQUENCE") then
          in_block = true
          _continue_0 = true
          break
        end
        local _value_0 = line:gsub("    ", "  ")
        _accum_0[_len_0] = _value_0
        _len_0 = _len_0 + 1
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    return _accum_0
  end)()
end
local extract_schema_table
extract_schema_table = function(config, model)
  local table_name = model:table_name()
  local schema = exec(build_command("psql -c " .. tostring(shell_escape("\\d " .. tostring(table_name))), config))
  return (function()
    local _accum_0 = { }
    local _len_0 = 1
    for line in schema:gmatch("[^\n]+") do
      _accum_0[_len_0] = line:gsub("%s+$", "")
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)()
end
return {
  build_command = build_command,
  extract_schema_sql = extract_schema_sql,
  extract_schema_table = extract_schema_table
}
