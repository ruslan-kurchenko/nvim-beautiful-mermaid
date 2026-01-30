local in_buffer = require("beautiful_mermaid.targets.in_buffer")
local float = require("beautiful_mermaid.targets.float")
local external = require("beautiful_mermaid.targets.external")

local M = {}

function M.show(block, output, cfg)
  local target = cfg.render.target
  if target == "float" then
    return float.show(block, output, cfg)
  elseif target == "external" then
    return external.show(block, output, cfg)
  end
  return in_buffer.show(block, output, cfg)
end

function M.show_error(block, message, cfg)
  local target = cfg.render.target
  if target == "float" or target == "external" then
    vim.notify("beautiful_mermaid: " .. tostring(message), vim.log.levels.ERROR)
    return
  end
  return in_buffer.show_error(block, message, cfg)
end

function M.clear(bufnr)
  return in_buffer.clear(bufnr)
end

function M.export_output(output, cfg, path)
  return external.export_output(output, cfg, path)
end

return M
