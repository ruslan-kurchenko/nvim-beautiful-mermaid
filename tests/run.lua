local config = require("beautiful_mermaid.config")
local parser = require("beautiful_mermaid.parser")
local targets = require("beautiful_mermaid.targets")
local external = require("beautiful_mermaid.targets.external")

local function assert_eq(a, b, msg)
  if a ~= b then
    error(msg or ("assertion failed: " .. tostring(a) .. " != " .. tostring(b)))
  end
end

local function test_config_defaults()
  local cfg = config.normalize({})
  assert_eq(cfg.render.target, "in_buffer", "default target")
  local valid_backends = { image = true, ascii = true, external = true }
  assert_eq(valid_backends[cfg.render.backend] ~= nil, true, "backend auto-detected to valid value")
end

local function test_parser_markdown()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "# Title",
    "```mermaid",
    "graph TD",
    "A-->B",
    "```",
  })
  local blocks = parser.extract(buf, config.normalize({}))
  assert_eq(#blocks, 1, "one mermaid block")
  assert_eq(blocks[1].content, "graph TD\nA-->B", "content matches")
end

local function test_buffer_config_override()
  local buf = vim.api.nvim_create_buf(false, true)
  config.set_buffer(buf, { render = { target = "float" } })
  local cfg = config.get(buf, config.normalize({}))
  assert_eq(cfg.render.target, "float", "buffer override applied")
end

local function test_in_buffer_clear()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "```mermaid",
    "graph TD",
    "A-->B",
    "```",
  })
  local block = {
    bufnr = buf,
    range = { start_row = 0, end_row = 3 },
    content = "graph TD\nA-->B",
    hash = vim.fn.sha256("graph TD\nA-->B"),
  }
  targets.show(block, "A-->B", config.normalize({ render = { format = "ascii" } }))
  targets.clear(buf)
  local marks = vim.api.nvim_buf_get_extmarks(buf, vim.api.nvim_create_namespace("beautiful_mermaid"), 0, -1, {})
  assert_eq(#marks, 0, "extmarks cleared")
end

local function test_export_path_builder()
  local tmp_dir = vim.fn.tempname()
  vim.fn.mkdir(tmp_dir)
  local path = external.build_export_path(tmp_dir, 2, "svg")
  assert_eq(path, tmp_dir .. "/mermaid-2.svg", "dir export path")

  local base = vim.fn.tempname() .. ".svg"
  local root = vim.fn.fnamemodify(base, ":r")
  local file_path = external.build_export_path(base, 3, "svg")
  assert_eq(file_path, root .. "-3.svg", "file export path")
end

test_config_defaults()
test_parser_markdown()
test_buffer_config_override()
test_in_buffer_clear()
test_export_path_builder()

-- Theme integration tests
local theme = require("beautiful_mermaid.theme")

local function test_theme_matching()
  assert_eq(theme.match_theme("tokyonight-storm"), "tokyo-night-storm", "tokyonight-storm mapping")
  assert_eq(theme.match_theme("nord"), "nord", "nord mapping")
  assert_eq(theme.match_theme("unknown-theme"), nil, "unknown theme returns nil")
end

local function test_color_extraction()
  vim.cmd("colorscheme default")
  theme.invalidate_cache()
  local colors = theme.extract_colors()
  assert_eq(type(colors.bg), "string", "bg is string")
  assert_eq(colors.bg:sub(1, 1), "#", "bg starts with #")
  assert_eq(type(colors.fg), "string", "fg is string")
  assert_eq(type(colors.muted), "string", "muted is string")
end

local function test_theme_resolution()
  vim.cmd("colorscheme default")
  theme.invalidate_cache()
  local resolved_theme, resolved_options = theme.resolve("nvim", {})
  assert_eq(type(resolved_theme), "string", "resolved theme is string")
  assert_eq(type(resolved_options), "table", "resolved options is table")
end

local function test_user_override()
  vim.cmd("colorscheme default")
  theme.invalidate_cache()
  local resolved_theme, resolved_options = theme.resolve("dracula", {})
  assert_eq(resolved_theme, "dracula", "explicit theme is preserved")
  assert_eq(type(resolved_options), "table", "options table provided")
end

local function test_backward_compat()
  local cfg = config.normalize({ mermaid = { theme = "dracula" } })
  assert_eq(cfg.mermaid.theme, "dracula", "explicit theme unchanged")
end

local function test_cache_invalidation()
  vim.cmd("colorscheme default")
  theme.invalidate_cache()
  local colors1 = theme.extract_colors()
  local colors2 = theme.extract_colors()
  assert_eq(colors1.bg, colors2.bg, "cached colors match")
  theme.invalidate_cache()
  local colors3 = theme.extract_colors()
  assert_eq(colors1.bg, colors3.bg, "colors consistent after invalidation")
end

local function test_partial_theme_matching()
  local tokyonight_match = theme.match_theme("tokyonight")
  assert_eq(tokyonight_match ~= nil, true, "partial tokyonight match returns non-nil")
  local catppuccin_match = theme.match_theme("catppuccin")
  assert_eq(catppuccin_match ~= nil, true, "partial catppuccin match returns non-nil")
  local valid_catppuccin = { ["catppuccin-mocha"] = true, ["catppuccin-latte"] = true }
  assert_eq(valid_catppuccin[catppuccin_match] ~= nil, true, "catppuccin match is valid variant")
end

test_theme_matching()
test_color_extraction()
test_theme_resolution()
test_user_override()
test_backward_compat()
test_cache_invalidation()
test_partial_theme_matching()

print("ok")
