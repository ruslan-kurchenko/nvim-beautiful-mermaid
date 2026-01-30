local M = {}

local image_backend = require("beautiful_mermaid.deps.image_backend")
local rasterizer = require("beautiful_mermaid.deps.rasterizer")

local state = {
  win = nil,
  buf = nil,
  image_id = nil,
}

local function cache_dir()
  local dir = vim.fn.stdpath("cache") .. "/beautiful_mermaid"
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  return dir
end

local function cache_paths(output)
  local key = vim.fn.sha256(output)
  local dir = cache_dir()
  return {
    key = key,
    svg = dir .. "/" .. key .. ".svg",
    png = dir .. "/" .. key .. ".png",
  }
end

local function ensure_buf()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    return state.buf
  end
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(state.buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(state.buf, "filetype", "mermaid-preview")
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

local function open_window(buf, cfg)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    return state.win
  end

  local dims = calculate_dimensions(cfg)

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

  vim.api.nvim_win_set_option(state.win, "winblend", 0)
  vim.api.nvim_win_set_option(state.win, "cursorline", false)

  return state.win
end

function M.show(_block, output, cfg)
  M.close()

  local buf = ensure_buf()
  setup_keymaps(buf)

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

  local paths = cache_paths(output)

  if vim.fn.filereadable(paths.svg) == 0 then
    local fd = io.open(paths.svg, "w")
    if fd then
      fd:write(output)
      fd:close()
    end
  end

  if vim.fn.filereadable(paths.png) == 0 then
    local ok, err = rasterizer.rasterize(paths.svg, paths.png, cfg)
    if not ok then
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "Rasterization failed: " .. tostring(err),
        "",
        "Press 'q' to close.",
      })
      open_window(buf, cfg)
      return
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
  open_window(buf, cfg)

  vim.schedule(function()
    if not state.win or not vim.api.nvim_win_is_valid(state.win) then
      return
    end

    state.image_id = "bm-float-" .. paths.key
    image_backend.render(buf, 1, 0, paths.png, {
      id = state.image_id,
      width = cfg.image and cfg.image.max_width,
      height = cfg.image and cfg.image.max_height,
    })
  end)
end

function M.close()
  if state.image_id and state.buf then
    image_backend.clear(state.buf)
    state.image_id = nil
  end

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end

  state.win = nil
  state.buf = nil
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
