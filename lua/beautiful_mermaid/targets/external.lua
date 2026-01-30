local M = {}
---@diagnostic disable: unused-local

local function ext_for_format(format)
  return format == "ascii" and "txt" or "svg"
end

local function write_temp(output, format)
  local ext = ext_for_format(format)
  local path = vim.fn.tempname() .. "." .. ext
  local fd, err = io.open(path, "w")
  if not fd then
    vim.notify("beautiful_mermaid: failed to write file: " .. tostring(err), vim.log.levels.ERROR)
    return nil
  end
  fd:write(output)
  fd:close()
  return path
end

function M.build_export_path(base_path, index, format)
  local ext = ext_for_format(format)
  if not base_path or base_path == "" then
    return vim.fn.tempname() .. "." .. ext
  end
  if vim.fn.isdirectory(base_path) == 1 then
    return base_path .. "/mermaid-" .. tostring(index) .. "." .. ext
  end
  local root = vim.fn.fnamemodify(base_path, ":r")
  return root .. "-" .. tostring(index) .. "." .. ext
end

---@diagnostic disable-next-line: unused-local
function M.show(_block, output, cfg)
  local path = write_temp(output, cfg.render.format)
  if not path then
    vim.notify("beautiful_mermaid: failed to write temp file", vim.log.levels.ERROR)
    return
  end
  if cfg.external.command == "" then
    vim.notify("beautiful_mermaid: external.command not set", vim.log.levels.WARN)
    return
  end
  vim.fn.jobstart({ cfg.external.command, path }, { detach = true })
end

function M.export_output(output, cfg, path)
  local out_path = path
  if not out_path or out_path == "" then
    out_path = write_temp(output, cfg.render.format)
  else
    local fd, err = io.open(out_path, "w")
    if not fd then
      vim.notify("beautiful_mermaid: failed to write file: " .. tostring(err), vim.log.levels.ERROR)
      return
    end
    fd:write(output)
    fd:close()
  end
  vim.notify("beautiful_mermaid: exported to " .. out_path, vim.log.levels.INFO)
end

return M
