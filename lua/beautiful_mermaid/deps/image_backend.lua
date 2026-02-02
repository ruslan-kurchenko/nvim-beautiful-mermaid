local M = {}

local state = {
  images = {},
  load_error = nil,
  checked = false,
}

local function get_api()
  if state.checked then
    if state.load_error then
      return nil, state.load_error
    end
  end

  local ok, result = pcall(require, "image")
  state.checked = true

  if not ok then
    state.load_error = tostring(result)
    return nil, state.load_error
  end

  return result, nil
end

function M.is_available()
  local api, _ = get_api()
  return api ~= nil
end

function M.get_load_error()
  if not state.checked then
    get_api()
  end
  return state.load_error
end

local function ensure_buf_state(bufnr)
  if not state.images[bufnr] then
    state.images[bufnr] = {}
  end
  return state.images[bufnr]
end

function M.render(bufnr, row, col, path, opts)
  local api, load_err = get_api()
  if not api then
    local msg = "image.nvim not available"
    if load_err then
      msg = msg .. ": " .. load_err
    end
    return nil, msg
  end

  local win = opts.window or vim.api.nvim_get_current_win()
  local images = ensure_buf_state(bufnr)
  local id = opts.id

  if images[id] then
    pcall(function()
      images[id]:clear()
    end)
    images[id] = nil
  end

  local ok, result = pcall(function()
    local image = api.from_file(path, {
      id = id,
      window = win,
      buffer = bufnr,
      inline = true,
      with_virtual_padding = true,
      x = col,
      y = row,
      width = opts.width,
      height = opts.height,
      max_width_window_percentage = opts.max_width_window_percentage,
      max_height_window_percentage = opts.max_height_window_percentage,
    })
    image:render()
    return image
  end)

  if not ok then
    return nil, "image.nvim render failed: " .. tostring(result)
  end

  images[id] = result
  return result, nil
end

function M.clear(bufnr, id)
  local images = state.images[bufnr]
  if not images then
    return
  end
  if id then
    if images[id] then
      images[id]:clear()
      images[id] = nil
    end
    -- Clean up empty table
    if next(images) == nil then
      state.images[bufnr] = nil
    end
    return
  end
  for key, image in pairs(images) do
    image:clear()
    images[key] = nil
  end
  state.images[bufnr] = nil
end

function M.clear_all_global()
  local api = get_api()
  if not api then
    return
  end
  api.clear()
  state.images = {}
end

return M
