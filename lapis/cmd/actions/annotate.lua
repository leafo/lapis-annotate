local default_environment
default_environment = require("lapis.cmd.util").default_environment
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
      table.insert(1, command, "PGPASSWORD=" .. tostring(shell_escape(password)))
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
local annotate_model
annotate_model = function(config, fname, options)
  if options == nil then
    options = { }
  end
  local source_f = assert(io.open(fname, "r"))
  local source = assert(source_f:read("*all"))
  source_f:close()
  local model
  if fname:match(".moon$") then
    local moonscript = require("moonscript.base")
    model = assert(moonscript.loadfile(fname)())
  else
    model = assert(loadfile(fname)())
  end
  local header_lines
  local _exp_0 = options.format
  if "sql" == _exp_0 then
    header_lines = extract_schema_sql(config, model)
  elseif "table" == _exp_0 then
    header_lines = extract_schema_table(config, model)
  end
  if options.print then
    print(table.concat(header_lines, "\n"))
    return 
  end
  table.insert(header_lines, 1, "")
  table.insert(header_lines, 1, "Generated schema dump: (do not edit)")
  table.insert(header_lines, "")
  for idx, line in ipairs(header_lines) do
    header_lines[idx] = ("-- " .. tostring(line)):gsub("%s+$", "")
  end
  local header = table.concat(header_lines, "\n")
  local source_with_header
  if source:match("%-%- Generated .-\nclass ") then
    source_with_header = source:gsub("%-%- Generated .-\nclass ", tostring(header) .. "\nclass ", 1)
  else
    source_with_header = source:gsub("class ", tostring(header) .. "\nclass ", 1)
  end
  local source_out = io.open(fname, "w")
  source_out:write(source_with_header)
  return source_out:close()
end
local parsed_args = false
return {
  argparser = function()
    parsed_args = true
    do
      local _with_0 = require("argparse")("lapis annotate", "Extract schema information from database table to comment model")
      _with_0:argument("files", "Paths to model classes to annotate (eg. models/first.moon models/second.moon ...)"):args("+")
      _with_0:option("--preload-module", "Module to require before annotating a model"):argname("<name>")
      _with_0:option("--format", "What dump format to use"):choices({
        "sql",
        "table"
      }):default("sql")
      _with_0:flag("--print -p", "Print the output instead of editing the model files")
      return _with_0
    end
  end,
  function(self, args, lapis_args)
    assert(parsed_args, "The version of Lapis you are using does not support this version of lapis-annotate. Please upgrade Lapis ≥ v1.14.0")
    do
      local mod_name = args.preload_module
      if mod_name then
        assert(type(mod_name) == "string", "preload-module must be a astring")
        require(mod_name)
      end
    end
    local config = self:get_config(lapis_args.environment)
    local _list_0 = args.files
    for _index_0 = 1, #_list_0 do
      local fname = _list_0[_index_0]
      io.stderr:write("Annotating " .. tostring(fname) .. "\n")
      annotate_model(config, fname, args)
    end
  end
}
