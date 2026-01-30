local M = {}

local state = {
  images = {},
}

local function get_api()
  local ok, api = pcall(require, "image")
  if not ok then
    return nil
  end
  return api
end

function M.is_available()
  return get_api() ~= nil
end

local function ensure_buf_state(bufnr)
  if not state.images[bufnr] then
    state.images[bufnr] = {}
  end
  return state.images[bufnr]
end

function M.render(bufnr, row, col, path, opts)
  local api = get_api()
  if not api then
    return nil, "image.nvim not available"
  end

  local win = opts.window or vim.api.nvim_get_current_win()
  local images = ensure_buf_state(bufnr)
  local id = opts.id

  if images[id] then
    images[id]:clear()
    images[id] = nil
  end

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
  images[id] = image
  return image, nil
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
    return
  end
  for key, image in pairs(images) do
    image:clear()
    images[key] = nil
  end
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
