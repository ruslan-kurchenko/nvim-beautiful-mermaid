local config = require("beautiful_mermaid.config")
local parser = require("beautiful_mermaid.parser")
local renderer = require("beautiful_mermaid.deps.renderer")
local targets = require("beautiful_mermaid.targets")
local cache = require("beautiful_mermaid.cache")
local cache_cleanup = require("beautiful_mermaid.deps.cache_cleanup")
local commands = require("beautiful_mermaid.commands")
local live = require("beautiful_mermaid.live")

local M = {}

local state = {
  config = config.defaults(),
}

local function setup_highlights()
  local function get_hl_fg(name)
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    return hl.fg and string.format("#%06x", hl.fg) or nil
  end

  local green = get_hl_fg("Directory") or get_hl_fg("NvimTreeFolderName") or "#509475"

  vim.api.nvim_set_hl(0, "MermaidPreview", { fg = green, italic = true })
  vim.api.nvim_set_hl(0, "MermaidError", { link = "ErrorMsg" })
  vim.api.nvim_set_hl(0, "MermaidPlaceholder", { fg = green, italic = true })
end

function M.get_config(bufnr)
  return config.get(bufnr, state.config)
end

function M.set_buffer_config(bufnr, overrides)
  config.set_buffer(bufnr, overrides)
end

local function render_block(block)
  local cfg = M.get_config(block.bufnr)
  local key = cache.key(block.hash, cfg)
  local cached = cache.get(key)
  if cached then
    targets.show(block, cached, cfg)
    return
  end

  renderer.render_async(block.content, cfg, function(result)
    if not result.ok then
      targets.show_error(block, result.error, cfg)
      return
    end
    cache.set(key, result.output, cfg)
    targets.show(block, result.output, cfg)
  end)
end

function M.render_current()
  local bufnr = vim.api.nvim_get_current_buf()
  local block = parser.extract_at_cursor(bufnr, M.get_config(bufnr))
  if not block then
    return
  end
  block.bufnr = bufnr
  render_block(block)
end

function M.render_all(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cfg = M.get_config(bufnr)
  local blocks = parser.extract(bufnr, cfg)
  if #blocks == 0 then
    return
  end
  targets.clear(bufnr)
  for _, block in ipairs(blocks) do
    block.bufnr = bufnr
    render_block(block)
  end
end

function M.export_current(path)
  local bufnr = vim.api.nvim_get_current_buf()
  local cfg = M.get_config(bufnr)
  local block = parser.extract_at_cursor(bufnr, cfg)
  if not block then
    return
  end
  renderer.render_async(block.content, cfg, function(result)
    if not result.ok then
      vim.notify(result.error, vim.log.levels.ERROR)
      return
    end
    targets.export_output(result.output, cfg, path)
  end)
end

function M.export_all(path)
  local bufnr = vim.api.nvim_get_current_buf()
  local cfg = M.get_config(bufnr)
  local blocks = parser.extract(bufnr, cfg)
  if #blocks == 0 then
    return
  end

  local export = require("beautiful_mermaid.targets.external")
  for i, block in ipairs(blocks) do
    local index = i
    renderer.render_async(block.content, cfg, function(result)
      if not result.ok then
        vim.notify(result.error, vim.log.levels.ERROR)
        return
      end
      local out_path = export.build_export_path(path, index, cfg.render.format)
      export.export_output(result.output, cfg, out_path)
    end)
  end
end

function M.preview_current()
  local bufnr = vim.api.nvim_get_current_buf()
  local cfg = M.get_config(bufnr)
  local block = parser.extract_at_cursor(bufnr, cfg)
  if not block then
    vim.notify("No mermaid block under cursor", vim.log.levels.WARN)
    return
  end
  block.bufnr = bufnr

  local float = require("beautiful_mermaid.targets.float")
  local key = cache.key(block.hash, cfg)
  local cached = cache.get(key)

  if cached then
    float.show(block, cached, cfg)
    return
  end

  renderer.render_async(block.content, cfg, function(result)
    if not result.ok then
      vim.notify(result.error, vim.log.levels.ERROR)
      return
    end
    cache.set(key, result.output, cfg)
    float.show(block, result.output, cfg)
  end)
end

function M.preview_close()
  local float = require("beautiful_mermaid.targets.float")
  float.close()
end

function M.clear_current()
  local bufnr = vim.api.nvim_get_current_buf()
  targets.clear(bufnr)
end

function M.clear_all()
  local bufnr = vim.api.nvim_get_current_buf()
  targets.clear(bufnr)
  M.preview_close()
  M.split_close()
end

function M.split_open()
  local split = require("beautiful_mermaid.targets.split")
  split.open()
end

function M.split_close()
  local split = require("beautiful_mermaid.targets.split")
  split.close()
end

function M.split_toggle()
  local split = require("beautiful_mermaid.targets.split")
  split.toggle()
end

local function setup_keymaps(cfg)
  if cfg.keymaps == false then
    return
  end

  local keymaps = cfg.keymaps or {}
  local defaults = {
    render = "<leader>rr",
    render_all = "<leader>rR",
    preview = "<leader>rf",
    clear = "<leader>rc",
    split = "<leader>rs",
  }

  local maps = vim.tbl_extend("force", defaults, keymaps)
  local opts = { noremap = true, silent = true, desc = "Mermaid" }

  if maps.render then
    vim.keymap.set("n", maps.render, M.render_current, vim.tbl_extend("force", opts, { desc = "Render mermaid block" }))
  end
  if maps.render_all then
    vim.keymap.set("n", maps.render_all, M.render_all, vim.tbl_extend("force", opts, { desc = "Render all mermaid blocks" }))
  end
  if maps.preview then
    vim.keymap.set("n", maps.preview, M.preview_current, vim.tbl_extend("force", opts, { desc = "Preview mermaid in float" }))
  end
  if maps.clear then
    vim.keymap.set("n", maps.clear, M.clear_all, vim.tbl_extend("force", opts, { desc = "Clear mermaid previews" }))
  end
  if maps.split then
    vim.keymap.set("n", maps.split, M.split_toggle, vim.tbl_extend("force", opts, { desc = "Toggle split preview" }))
  end
end

function M.setup(opts)
  state.config = config.normalize(opts or {})
  setup_highlights()
  setup_keymaps(state.config)
  cache_cleanup.cleanup(7)
  cache.clear()

  -- Setup ColorScheme autocmd for theme = "nvim"
  if state.config.mermaid.theme == "nvim" then
    local theme_group = vim.api.nvim_create_augroup("BeautifulMermaidTheme", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = theme_group,
      callback = function()
        local theme = require("beautiful_mermaid.theme")
        theme.invalidate_cache()
        cache.clear()
        -- Re-render visible markdown buffers
        vim.schedule(function()
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "markdown" then
              M.render_all(buf)
            end
          end
        end)
      end,
    })
  end

  commands.setup(M)
  require("beautiful_mermaid.lsp").setup(M)
  if state.config.render.live then
    live.enable(M)
  else
    live.disable()
  end
end

return M
