local default_environment
default_environment = require("lapis.cmd.util").default_environment
local exec
exec = function(cmd)
  local f = io.popen(cmd)
  do
    local _with_0 = f:read("*all"):gsub("%s*$", "")
    f:close()
    return _with_0
  end
end
local extract_header
extract_header = function(config, model)
  local table_name = model:table_name()
  local schema = exec("pg_dump --schema-only -U postgres -t " .. tostring(table_name) .. " " .. tostring(assert(config.postgres.database, "missing db")))
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
  local source_f = io.open(fname, "r")
  local source = source_f:read("*all")
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
return {
  name = "annotate",
  usage = "annotate models/model1.moon models/model2.moon ...",
  help = "annotate a model with schema",
  function(self, flags, ...)
    local args = {
      ...
    }
    local config = require("lapis.config").get()
    if not (next(args)) then
      error("no models passed to annotate")
    end
    for _index_0 = 1, #args do
      local fname = args[_index_0]
      print("Annotating " .. tostring(fname))
      annotate_model(config, fname)
    end
  end
}
