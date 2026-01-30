local M = {}

local namespace = vim.api.nvim_create_namespace("beautiful_mermaid")
local image_backend = require("beautiful_mermaid.deps.image_backend")
local rasterizer = require("beautiful_mermaid.deps.rasterizer")

local function placeholder(cfg)
  if cfg.render.format == "ascii" then
    return nil
  end
  return "[mermaid preview: svg output]"
end

local function cache_dir()
  local dir = vim.fn.stdpath("cache") .. "/beautiful_mermaid"
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  return dir
end

local function cache_paths(block, svg_output)
  local key = vim.fn.sha256(svg_output .. ":" .. block.hash .. ":" .. tostring(block.range.start_row))
  local dir = cache_dir()
  return {
    key = key,
    svg = dir .. "/" .. key .. ".svg",
    png = dir .. "/" .. key .. ".png",
  }
end

local function can_render_image(cfg)
  if cfg.render.backend == "ascii" then
    return false
  end
  if cfg.render.backend == "external" then
    return false
  end
  return image_backend.is_available()
end

function M.show(block, output, cfg)
  local bufnr = block.bufnr or vim.api.nvim_get_current_buf()
  local row = block.range.end_row
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if row >= line_count then
    row = line_count - 1
  end
  if row < 0 then
    row = 0
  end
  M.clear(bufnr, block.range.start_row, block.range.end_row)
  local virt = {}
  if cfg.render.format == "ascii" then
    local lines = vim.split(output, "\n", { plain = true })
    local virt_lines = {}
    for _, line in ipairs(lines) do
      table.insert(virt_lines, { { line, "Comment" } })
    end
    virt = virt_lines
  else
    if can_render_image(cfg) then
      local paths = cache_paths(block, output)
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
          virt = { { { "[mermaid error] " .. err, "ErrorMsg" } } }
        end
      end
      if vim.fn.filereadable(paths.png) == 1 then
        image_backend.render(bufnr, row + 1, 0, paths.png, {
          id = "bm-" .. paths.key,
          width = cfg.image.max_width,
          height = cfg.image.max_height,
        })
        local padding = math.max(1, cfg.image.padding_rows)
        local blanks = {}
        for _ = 1, padding do
          table.insert(blanks, { { "", "Comment" } })
        end
        virt = blanks
      end
    end

    if #virt == 0 then
      virt = { { { placeholder(cfg), "Comment" } } }
    end
  end

  vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
    virt_lines = virt,
    virt_lines_above = false,
    hl_mode = "combine",
  })
end

function M.show_error(block, message, cfg)
  local msg = tostring(message or "")
  if msg == "" then
    msg = "unknown error (run :MermaidCheckHealth)"
  end
  local bufnr = block.bufnr or vim.api.nvim_get_current_buf()
  local row = block.range.end_row
  M.clear(bufnr, block.range.start_row, block.range.end_row)
  vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
    virt_lines = { { { "[mermaid error] " .. msg, "ErrorMsg" } } },
    virt_lines_above = false,
    hl_mode = "combine",
  })
end

function M.clear(bufnr, start_row, end_row)
  image_backend.clear(bufnr)
  if start_row and end_row then
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, start_row, end_row + 1)
  else
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  end
end

return M
