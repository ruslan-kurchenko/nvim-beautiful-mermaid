local config = require("beautiful_mermaid.config")
local parser = require("beautiful_mermaid.parser")
local renderer = require("beautiful_mermaid.deps.renderer")
local targets = require("beautiful_mermaid.targets")
local cache = require("beautiful_mermaid.cache")
local commands = require("beautiful_mermaid.commands")
local live = require("beautiful_mermaid.live")

local M = {}

local state = {
  config = config.defaults(),
}

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

function M.render_all()
  local bufnr = vim.api.nvim_get_current_buf()
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

function M.setup(opts)
  state.config = config.normalize(opts or {})
  cache.clear()
  commands.setup(M)
  require("beautiful_mermaid.lsp").setup(M)
  if state.config.render.live then
    live.enable(M)
  else
    live.disable()
  end
end

return M
