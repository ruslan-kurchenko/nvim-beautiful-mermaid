local M = {}
---@diagnostic disable: deprecated

local image_backend = require("beautiful_mermaid.deps.image_backend")
local rasterizer = require("beautiful_mermaid.deps.rasterizer")
local parser = require("beautiful_mermaid.parser")
local renderer = require("beautiful_mermaid.deps.renderer")
local cache = require("beautiful_mermaid.cache")

local state = {
  source_buf = nil,
  source_win = nil,
  preview_buf = nil,
  preview_win = nil,
  current_block = nil,
  current_size = nil,
  augroup = nil,
  debounce_timer = nil,
}

local render_generation = {}

local function next_generation(bufnr)
  render_generation[bufnr] = (render_generation[bufnr] or 0) + 1
  return render_generation[bufnr]
end

local SCALE_FACTOR = 2
local DEBOUNCE_MS = 500

local function cache_dir()
  local dir = vim.fn.stdpath("cache") .. "/beautiful_mermaid/split"
  if vim.fn.isdirectory(dir) == 0 then
    local ok = vim.fn.mkdir(dir, "p")
    if ok == 0 then
      vim.notify("beautiful_mermaid: failed to create cache directory: " .. dir, vim.log.levels.ERROR)
      return nil
    end
  end
  return dir
end

local function cache_paths(output, width)
  local content_key = vim.fn.sha256(output)
  local size_key = width and tostring(width) or "default"
  local dir = cache_dir()
  if not dir then
    return nil
  end
  return {
    key = content_key .. "-" .. size_key,
    svg = dir .. "/" .. content_key .. ".svg",
    png = dir .. "/" .. content_key .. "-" .. size_key .. ".png",
  }
end

local function get_preview_inner_size()
  if not state.preview_win or not vim.api.nvim_win_is_valid(state.preview_win) then
    return nil, nil
  end
  local width = vim.api.nvim_win_get_width(state.preview_win)
  local height = vim.api.nvim_win_get_height(state.preview_win)
  return width, height
end

local function estimate_pixel_width(cell_width)
  return cell_width * 10 * SCALE_FACTOR
end

local function clear_preview_image()
  if state.preview_buf and vim.api.nvim_buf_is_valid(state.preview_buf) then
    image_backend.clear(state.preview_buf)
  end
end

local function render_image_in_split(png_path)
  if not state.preview_win or not vim.api.nvim_win_is_valid(state.preview_win) then
    return
  end

  if not state.preview_buf or not vim.api.nvim_buf_is_valid(state.preview_buf) then
    return
  end

  clear_preview_image()

  local win_width, _ = get_preview_inner_size()
  if not win_width then
    return
  end

  image_backend.render(state.preview_buf, 0, 0, png_path, {
    id = "mermaid-split-preview",
    width = win_width,
    window = state.preview_win,
    max_width_window_percentage = 100,
    max_height_window_percentage = 100,
  })
end

local function ensure_png_for_size(output, cfg, pixel_width, callback)
  local paths = cache_paths(output, pixel_width)
  if not paths then
    return
  end

  if vim.fn.filereadable(paths.svg) == 0 then
    local fd, err = io.open(paths.svg, "w")
    if not fd then
      vim.notify("beautiful_mermaid: failed to write file: " .. tostring(err), vim.log.levels.ERROR)
      return
    end
    fd:write(output)
    fd:close()
  end

  if vim.fn.filereadable(paths.png) == 1 then
    callback(paths.png)
    return
  end

  ---@diagnostic disable-next-line: deprecated
  rasterizer.rasterize_async(paths.svg, paths.png, cfg, {
    width = pixel_width,
  }, function(ok, err)
    if not ok then
      vim.notify("Rasterization failed: " .. tostring(err), vim.log.levels.ERROR)
      return
    end

    callback(paths.png)
  end)
end

local function show_error_in_preview(msg)
  if not state.preview_buf or not vim.api.nvim_buf_is_valid(state.preview_buf) then
    return
  end
  clear_preview_image()
  vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, {
    "Error:",
    msg,
  })
end

local function show_placeholder()
  if not state.preview_buf or not vim.api.nvim_buf_is_valid(state.preview_buf) then
    return
  end
  clear_preview_image()
  vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, {
    "Move cursor to a mermaid block to preview",
  })
end

local function render_block_in_split(block, cfg)
  if not block then
    show_placeholder()
    return
  end

  state.current_block = block

  if not image_backend.is_available() then
    show_error_in_preview("image.nvim not available")
    return
  end

  local win_width, _ = get_preview_inner_size()
  if not win_width then
    return
  end

  local pixel_width = estimate_pixel_width(win_width)
  state.current_size = tostring(pixel_width)

  vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, { "" })

  local key = cache.key(block.hash, cfg)
  local cached_svg = cache.get(key)

  if cached_svg then
    vim.schedule(function()
      ensure_png_for_size(cached_svg, cfg, pixel_width, function(png_path)
        vim.schedule(function()
          render_image_in_split(png_path)
        end)
      end)
    end)
    return
  end

  local bufnr = block.bufnr or state.source_buf
  local gen = next_generation(bufnr)

  renderer.render_async(block.content, cfg, function(result)
    if render_generation[bufnr] ~= gen then
      return
    end
    if not result.ok then
      show_error_in_preview(result.error)
      return
    end

    cache.set(key, result.output, cfg)

    vim.schedule(function()
      ensure_png_for_size(result.output, cfg, pixel_width, function(png_path)
        vim.schedule(function()
          render_image_in_split(png_path)
        end)
      end)
    end)
  end)
end

local function update_preview()
  if not M.is_open() then
    return
  end

  if not state.source_buf or not vim.api.nvim_buf_is_valid(state.source_buf) then
    M.close()
    return
  end

  local main_mod = require("beautiful_mermaid")
  local cfg = main_mod.get_config(state.source_buf)
  local block = parser.extract_at_cursor(state.source_buf, cfg)

  if block then
    block.bufnr = state.source_buf
  end

  render_block_in_split(block, cfg)
end

local function debounced_update()
  if state.debounce_timer then
    vim.fn.timer_stop(state.debounce_timer)
    state.debounce_timer = nil
  end

  state.debounce_timer = vim.fn.timer_start(DEBOUNCE_MS, function()
    state.debounce_timer = nil
    vim.schedule(update_preview)
  end)
end

local function setup_autocmds()
  if state.augroup then
    return
  end

  state.augroup = vim.api.nvim_create_augroup("MermaidSplitPreview", { clear = true })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = state.augroup,
    buffer = state.source_buf,
    callback = debounced_update,
  })

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = state.augroup,
    buffer = state.source_buf,
    callback = debounced_update,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = state.augroup,
    callback = function(args)
      local closed_win = tonumber(args.match)
      if closed_win == state.preview_win or closed_win == state.source_win then
        vim.schedule(M.close)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = state.augroup,
    buffer = state.source_buf,
    callback = function()
      vim.schedule(M.close)
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = state.augroup,
    callback = function()
      if M.is_open() then
        vim.schedule(update_preview)
      end
    end,
  })
end

local function clear_autocmds()
  if state.debounce_timer then
    vim.fn.timer_stop(state.debounce_timer)
    state.debounce_timer = nil
  end

  if state.augroup then
    vim.api.nvim_del_augroup_by_id(state.augroup)
    state.augroup = nil
  end
end

local function create_preview_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "mermaid-preview"
  vim.bo[buf].modifiable = true
  return buf
end

function M.open()
  if M.is_open() then
    update_preview()
    return
  end

  state.source_buf = vim.api.nvim_get_current_buf()
  state.source_win = vim.api.nvim_get_current_win()

  state.preview_buf = create_preview_buffer()

  vim.cmd("vsplit")
  state.preview_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.preview_win, state.preview_buf)

  vim.wo[state.preview_win].number = false
  vim.wo[state.preview_win].relativenumber = false
  vim.wo[state.preview_win].signcolumn = "no"
  vim.wo[state.preview_win].foldcolumn = "0"
  vim.wo[state.preview_win].cursorline = false

  vim.api.nvim_set_current_win(state.source_win)

  setup_autocmds()
  update_preview()
end

function M.close()
  clear_preview_image()
  clear_autocmds()

  if state.preview_win and vim.api.nvim_win_is_valid(state.preview_win) then
    vim.api.nvim_win_close(state.preview_win, true)
  end

  state.source_buf = nil
  state.source_win = nil
  state.preview_buf = nil
  state.preview_win = nil
  state.current_block = nil
  state.current_size = nil
end

function M.is_open()
  return state.preview_win and vim.api.nvim_win_is_valid(state.preview_win)
end

function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

function M.refresh()
  if M.is_open() then
    update_preview()
  end
end

return M
