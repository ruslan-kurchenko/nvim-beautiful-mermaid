local M = {}

local image_backend = require("beautiful_mermaid.deps.image_backend")
local rasterizer = require("beautiful_mermaid.deps.rasterizer")

local state = {
  win = nil,
  buf = nil,
  current_output = nil,
  current_cfg = nil,
  current_size = nil,
  augroup = nil,
}

local SCALE_FACTOR = 2

local function cache_dir()
  local dir = vim.fn.stdpath("cache") .. "/beautiful_mermaid"
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  return dir
end

local function cache_paths(output, width)
  local content_key = vim.fn.sha256(output)
  local size_key = width and tostring(width) or "default"
  local dir = cache_dir()
  return {
    key = content_key .. "-" .. size_key,
    svg = dir .. "/" .. content_key .. ".svg",
    png = dir .. "/" .. content_key .. "-" .. size_key .. ".png",
  }
end

local function ensure_buf()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    return state.buf
  end
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].filetype = "mermaid-preview"
  return state.buf
end

local function setup_keymaps(buf)
  local opts = { noremap = true, silent = true, buffer = buf }
  vim.keymap.set("n", "q", M.close, opts)
  vim.keymap.set("n", "<Esc>", M.close, opts)
  vim.keymap.set("n", "<C-c>", M.close, opts)
end

local function calculate_dimensions(cfg)
  local max_width = cfg.float and cfg.float.max_width or math.floor(vim.o.columns * 0.8)
  local max_height = cfg.float and cfg.float.max_height or math.floor(vim.o.lines * 0.8)
  local min_width = cfg.float and cfg.float.min_width or 40
  local min_height = cfg.float and cfg.float.min_height or 10

  local width = math.max(min_width, math.min(max_width, math.floor(vim.o.columns * 0.7)))
  local height = math.max(min_height, math.min(max_height, math.floor(vim.o.lines * 0.7)))

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  return { width = width, height = height, row = row, col = col }
end

local function get_window_inner_size()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return nil, nil
  end
  local width = vim.api.nvim_win_get_width(state.win)
  local height = vim.api.nvim_win_get_height(state.win)
  return width, height
end

local function estimate_pixel_width(cell_width)
  return cell_width * 10 * SCALE_FACTOR
end

local function setup_resize_autocmd()
  if state.augroup then
    return
  end

  state.augroup = vim.api.nvim_create_augroup("MermaidFloatResize", { clear = true })

  vim.api.nvim_create_autocmd("VimResized", {
    group = state.augroup,
    callback = function()
      if not M.is_open() then
        return
      end
      M.resize()
    end,
  })
end

local function clear_resize_autocmd()
  if state.augroup then
    vim.api.nvim_del_augroup_by_id(state.augroup)
    state.augroup = nil
  end
end

local function open_window(buf, cfg)
  local dims = calculate_dimensions(cfg)

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_config(state.win, {
      relative = "editor",
      row = dims.row,
      col = dims.col,
      width = dims.width,
      height = dims.height,
    })
    return state.win
  end

  state.win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = dims.row,
    col = dims.col,
    width = dims.width,
    height = dims.height,
    style = "minimal",
    border = "rounded",
    title = " Mermaid Preview ",
    title_pos = "center",
  })

  vim.wo[state.win].winblend = 0
  vim.wo[state.win].cursorline = false

  return state.win
end

local function clear_current_image()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    image_backend.clear(state.buf)
  end
end

local function render_image_in_float(png_path)
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end

  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  clear_current_image()

  local win_width, _ = get_window_inner_size()
  if not win_width then
    return
  end

  image_backend.render(state.buf, 0, 0, png_path, {
    id = "mermaid-float-preview",
    width = win_width,
    window = state.win,
    max_width_window_percentage = 100,
    max_height_window_percentage = 100,
  })
end

local function ensure_png_for_size(output, cfg, pixel_width, callback)
  local paths = cache_paths(output, pixel_width)

  if vim.fn.filereadable(paths.svg) == 0 then
    local fd = io.open(paths.svg, "w")
    if fd then
      fd:write(output)
      fd:close()
    end
  end

  if vim.fn.filereadable(paths.png) == 1 then
    callback(paths.png)
    return
  end

  local ok, err = rasterizer.rasterize(paths.svg, paths.png, cfg, {
    width = pixel_width,
  })

  if not ok then
    vim.notify("Rasterization failed: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  callback(paths.png)
end

function M.resize()
  if not M.is_open() then
    return
  end

  local cfg = state.current_cfg
  local output = state.current_output
  if not cfg or not output then
    return
  end

  local dims = calculate_dimensions(cfg)
  vim.api.nvim_win_set_config(state.win, {
    relative = "editor",
    row = dims.row,
    col = dims.col,
    width = dims.width,
    height = dims.height,
  })

  if cfg.render.format == "ascii" then
    return
  end

  local win_width, _ = get_window_inner_size()
  if not win_width then
    return
  end

  local pixel_width = estimate_pixel_width(win_width)
  local size_key = tostring(pixel_width)

  if state.current_size == size_key then
    local paths = cache_paths(output, pixel_width)
    if vim.fn.filereadable(paths.png) == 1 then
      vim.schedule(function()
        render_image_in_float(paths.png)
      end)
    end
    return
  end

  state.current_size = size_key

  vim.schedule(function()
    ensure_png_for_size(output, cfg, pixel_width, function(png_path)
      vim.schedule(function()
        render_image_in_float(png_path)
      end)
    end)
  end)
end

function M.show(_block, output, cfg)
  M.close()

  local buf = ensure_buf()
  setup_keymaps(buf)
  setup_resize_autocmd()

  state.current_output = output
  state.current_cfg = cfg

  if cfg.render.format == "ascii" then
    local lines = vim.split(output, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    open_window(buf, cfg)
    return
  end

  if not image_backend.is_available() then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "Image backend not available.",
      "Install image.nvim for SVG preview.",
      "",
      "Press 'q' to close.",
    })
    open_window(buf, cfg)
    return
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
  open_window(buf, cfg)

  local win_width, _ = get_window_inner_size()
  if not win_width then
    return
  end

  local pixel_width = estimate_pixel_width(win_width)
  state.current_size = tostring(pixel_width)

  vim.schedule(function()
    ensure_png_for_size(output, cfg, pixel_width, function(png_path)
      vim.schedule(function()
        render_image_in_float(png_path)
      end)
    end)
  end)
end

function M.close()
  clear_current_image()

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end

  clear_resize_autocmd()

  state.win = nil
  state.buf = nil
  state.current_output = nil
  state.current_cfg = nil
  state.current_size = nil
end

function M.is_open()
  return state.win and vim.api.nvim_win_is_valid(state.win)
end

function M.toggle(block, output, cfg)
  if M.is_open() then
    M.close()
  else
    M.show(block, output, cfg)
  end
end

return M
