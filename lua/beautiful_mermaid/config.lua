local M = {}

local defaults = {
  render = {
    target = "in_buffer",
    format = "ascii",
    backend = "auto",
    live = true,
    debounce_ms = 200,
  },
  mermaid = {
    theme = "default",
    options = {
      bg = nil,
      fg = nil,
      line = nil,
      accent = nil,
      muted = nil,
      surface = nil,
      border = nil,
      font = nil,
      padding = 8,
      nodeSpacing = 30,
      layerSpacing = 40,
      transparent = false,
    },
  },
  markdown = {
    enabled = true,
    fence = "mermaid",
  },
  external = {
    command = "",
  },
  lsp = {
    enable = true,
    server = "mermaid",
  },
  treesitter = {
    enable = true,
    injection_lang = "mermaid",
  },
  renderer = {
    command = "bun",
    script = nil,
    timeout_ms = 5000,
  },
  image = {
    backend = "image.nvim",
    max_width = nil,
    max_height = nil,
    scale = 1.0,
    padding_rows = 2,
  },
  rasterizer = {
    command = "auto",
    dpi = 144,
    timeout_ms = 3000,
  },
  cache = {
    max_entries = 200,
  },
  float = {
    max_width = nil,
    max_height = nil,
    min_width = 40,
    min_height = 10,
  },
  keymaps = {
    render = "<leader>rr",
    render_all = "<leader>rR",
    preview = "<leader>rf",
    clear = "<leader>rc",
    split = "<leader>rs",
  },
}

local function notify(msg)
  vim.notify(msg, vim.log.levels.WARN)
end

function M.defaults()
  return vim.deepcopy(defaults)
end

function M.normalize(user_opts)
  local cfg = vim.tbl_deep_extend("force", M.defaults(), user_opts or {})

  local targets = { in_buffer = true, float = true, external = true }
  if not targets[cfg.render.target] then
    notify("beautiful_mermaid: invalid render.target, using in_buffer")
    cfg.render.target = "in_buffer"
  end

  local formats = { svg = true, ascii = true }
  if not formats[cfg.render.format] then
    notify("beautiful_mermaid: invalid render.format, using svg")
    cfg.render.format = "svg"
  end

  local backends = { auto = true, ascii = true, image = true, external = true }
  if not backends[cfg.render.backend] then
    cfg.render.backend = "auto"
  end

  if cfg.render.backend == "auto" then
    local terminal = require("beautiful_mermaid.terminal")
    local app = terminal.detect()
    if terminal.supports_kitty_graphics(app) then
      cfg.render.backend = "image"
      cfg.render.format = "svg"
    elseif app == "alacritty" and cfg.external.command ~= "" then
      cfg.render.backend = "external"
      cfg.render.target = "external"
      cfg.render.format = "svg"
    else
      cfg.render.backend = "ascii"
      cfg.render.format = "ascii"
    end
  end

  if cfg.render.target == "external" and cfg.render.format == "ascii" then
    cfg.render.format = "svg"
  end

  if type(cfg.image.scale) ~= "number" then
    cfg.image.scale = defaults.image.scale
  end
  if type(cfg.image.padding_rows) ~= "number" then
    cfg.image.padding_rows = defaults.image.padding_rows
  end
  if type(cfg.rasterizer.dpi) ~= "number" then
    cfg.rasterizer.dpi = defaults.rasterizer.dpi
  end
  if type(cfg.rasterizer.timeout_ms) ~= "number" then
    cfg.rasterizer.timeout_ms = defaults.rasterizer.timeout_ms
  end

  if type(cfg.render.debounce_ms) ~= "number" then
    cfg.render.debounce_ms = defaults.render.debounce_ms
  end

  if cfg.renderer.command then
    local cmd = cfg.renderer.command
    if not cmd:match("bun") then
      notify("beautiful_mermaid: only bun is supported, forcing bun")
      cmd = "bun"
    end
    cfg.renderer.command = cmd
    if vim.fn.executable(cfg.renderer.command) ~= 1 then
      notify("beautiful_mermaid: renderer.command is not executable")
    end
  end

  if type(cfg.renderer.timeout_ms) ~= "number" then
    cfg.renderer.timeout_ms = defaults.renderer.timeout_ms
  end

  if type(cfg.cache.max_entries) ~= "number" then
    cfg.cache.max_entries = defaults.cache.max_entries
  end

  local opts = cfg.mermaid.options or {}
  if type(opts.padding) ~= "number" then
    opts.padding = defaults.mermaid.options.padding
  end
  if type(opts.nodeSpacing) ~= "number" then
    opts.nodeSpacing = defaults.mermaid.options.nodeSpacing
  end
  if type(opts.layerSpacing) ~= "number" then
    opts.layerSpacing = defaults.mermaid.options.layerSpacing
  end
  if type(opts.transparent) ~= "boolean" then
    opts.transparent = defaults.mermaid.options.transparent
  end
  cfg.mermaid.options = opts

  return cfg
end

function M.set_buffer(bufnr, overrides)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.b[bufnr].beautiful_mermaid_config = overrides
end

function M.get(bufnr, base)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  base = base or M.defaults()
  local overrides = vim.b[bufnr].beautiful_mermaid_config or {}
  return M.normalize(vim.tbl_deep_extend("force", base, overrides))
end

return M
