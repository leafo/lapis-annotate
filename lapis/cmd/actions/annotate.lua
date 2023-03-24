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
local extract_header
extract_header = function(config, model)
  local table_name = model:table_name()
  local database = assert(config.postgres.database, "missing db")
  local command = { }
  do
    local password = config.postgres.password
    if password then
      table.insert(command, "PGPASSWORD=" .. tostring(shell_escape(password)))
    end
  end
  table.insert(command, "pg_dump --schema-only")
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
  table.insert(command, "-t " .. tostring(shell_escape(table_name)))
  table.insert(command, shell_escape(database))
  local schema = exec(table.concat(command, " "))
  local in_block = false
  local filtered
  do
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
        local _value_0 = "-- " .. line:gsub("    ", "  ")
        _accum_0[_len_0] = _value_0
        _len_0 = _len_0 + 1
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    filtered = _accum_0
  end
  table.insert(filtered, 1, "--")
  table.insert(filtered, 1, "-- Generated schema dump: (do not edit)")
  table.insert(filtered, "--")
  return table.concat(filtered, "\n")
end
local extract_header2
extract_header2 = function(config, model)
  local table_name = model:table_name()
  local schema = exec("psql -U postgres " .. tostring(assert(config.postgres.database, "missing db")) .. " -c '\\d " .. tostring(table_name) .. "'")
  local lines
  do
    local _accum_0 = { }
    local _len_0 = 1
    for line in schema:gmatch("[^\n]+") do
      _accum_0[_len_0] = "-- " .. tostring(line:gsub("%s+^", ""))
      _len_0 = _len_0 + 1
    end
    lines = _accum_0
  end
  table.insert(lines, 1, "--")
  table.insert(lines, 1, "-- Generated schema dump: (do not edit)")
  table.insert(lines, "--")
  return table.concat(lines, "\n")
end
local annotate_model
annotate_model = function(config, fname)
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
  local header = extract_header(config, model)
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
      print("Annotating " .. tostring(fname))
      annotate_model(config, fname)
    end
  end
}
