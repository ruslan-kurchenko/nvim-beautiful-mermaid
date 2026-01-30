local M = {}

local store = {}
local access = {}
local counter = 0

local function is_list_table(value)
  if type(value) ~= "table" then
    return false
  end
  local count = 0
  for k in pairs(value) do
    if type(k) ~= "number" then
      return false
    end
    count = count + 1
  end
  for i = 1, count do
    if value[i] == nil then
      return false
    end
  end
  return true
end

local function encode_value(value)
  local t = type(value)
  if t == "nil" then
    return "null"
  end
  if t == "number" or t == "boolean" then
    return tostring(value)
  end
  if t == "string" then
    return vim.fn.json_encode(value)
  end
  if t == "table" then
    if is_list_table(value) then
      local parts = {}
      for _, item in ipairs(value) do
        table.insert(parts, encode_value(item))
      end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = vim.tbl_keys(value)
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
      table.insert(parts, encode_value(k) .. ":" .. encode_value(value[k]))
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

function M.key(hash, cfg)
  local fmt = cfg.render.format
  local theme = cfg.mermaid.theme
  local options = encode_value(cfg.mermaid.options or {})
  return table.concat({ hash, fmt, theme, options }, ":")
end

local function touch(key)
  counter = counter + 1
  access[key] = counter
end

function M.get(key)
  local entry = store[key]
  if entry then
    touch(key)
    return entry.value
  end
  return nil
end

local function prune(max_entries)
  local size = 0
  for _ in pairs(store) do
    size = size + 1
  end
  if size <= max_entries then
    return
  end

  local oldest_key
  local oldest_at = math.huge
  for key, at in pairs(access) do
    if at < oldest_at then
      oldest_at = at
      oldest_key = key
    end
  end
  if oldest_key then
    store[oldest_key] = nil
    access[oldest_key] = nil
  end
end

function M.set(key, value, cfg)
  store[key] = { value = value }
  touch(key)
  local max_entries = cfg and cfg.cache and cfg.cache.max_entries or 200
  prune(max_entries)
end

function M.clear()
  store = {}
  access = {}
  counter = 0
end

return M
