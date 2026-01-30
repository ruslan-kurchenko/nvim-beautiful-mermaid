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
  assert_eq(cfg.render.format, "ascii", "default format")
  assert_eq(cfg.render.backend, "auto", "default backend")
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

print("ok")
