local health = vim.health or require("health")
local renderer = require("beautiful_mermaid.deps.renderer")
local image_backend = require("beautiful_mermaid.deps.image_backend")
local rasterizer = require("beautiful_mermaid.deps.rasterizer")

local M = {}

function M.check()
  health.start("beautiful_mermaid")
  if vim.fn.has("nvim-0.9") == 1 then
    health.ok("Neovim >= 0.9")
  else
    health.error("Neovim 0.9+ required")
  end

  local cfg = require("beautiful_mermaid.config").defaults()
  if renderer.is_available(cfg) then
    health.ok("renderer available (bun)")
  else
    health.error("renderer unavailable (bun)")
  end

  local script = renderer.script_path(cfg)
  if vim.fn.filereadable(script) == 1 then
    health.ok("renderer script found")
  else
    health.error("renderer script missing: " .. script)
  end

  local bundle = vim.fn.fnamemodify(script, ":h") .. "/vendor/beautiful-mermaid.bundle.cjs"
  if vim.fn.filereadable(bundle) == 1 then
    health.ok("beautiful-mermaid bundle found")
  else
    health.error("beautiful-mermaid bundle missing: " .. bundle)
  end

  if cfg.render.target == "in_buffer" and cfg.render.format == "svg" then
    if image_backend.is_available() then
      health.ok("image.nvim available for inline rendering")
    else
      local load_err = image_backend.get_load_error and image_backend.get_load_error()
      if load_err then
        health.error("image.nvim failed to load: " .. load_err)
      else
        health.warn("image.nvim not available; inline svg will fall back to placeholder")
      end
    end
    if rasterizer.is_available(cfg) then
      local rast_cmd = rasterizer.get_command(cfg)
      if rast_cmd == "magick" or rast_cmd == "convert" then
        health.warn("ImageMagick rasterizer has known SVG vulnerabilities; consider installing resvg")
      else
        health.ok("rasterizer available (" .. rast_cmd .. ")")
      end
    else
      health.warn("rasterizer not available (resvg/rsvg-convert/magick/convert)")
    end
  end

  if cfg.external.command ~= "" then
    if vim.fn.executable(cfg.external.command) == 1 then
      health.ok("external command executable")
    else
      health.warn("external command not executable")
    end
  end

  if cfg.treesitter.enable then
    if vim.treesitter and vim.treesitter.get_parser then
      health.ok("treesitter available")
    else
      health.warn("treesitter not available, falling back to regex")
    end
    if vim.treesitter and vim.treesitter.language and vim.treesitter.language.require_language then
      local ok_lang = pcall(vim.treesitter.language.require_language, "mermaid")
      if ok_lang then
        health.ok("treesitter mermaid language available")
      else
        health.warn("treesitter mermaid language not installed")
      end
    end
  end
end

return M
