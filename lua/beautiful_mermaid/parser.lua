local M = {}

local function hash_text(text)
  return vim.fn.sha256(text)
end

local function normalize_node(value)
  if type(value) == "table" then
    if value.range then
      return value
    end
    return value[1]
  end
  return value
end

local function extract_treesitter(bufnr, fence)
  if not vim.treesitter or not vim.treesitter.get_parser then
    return nil
  end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return nil
  end

  local lang = parser:lang()
  local query_ok, query = pcall(vim.treesitter.query.parse, lang, [[
    (fenced_code_block
      (info_string) @lang
      (code_fence_content) @content) @block
  ]])
  if not query_ok then
    return nil
  end

  pcall(function()
    parser:invalidate(true)
  end)

  local tree = parser:parse(true)[1]
  if not tree then
    return nil
  end

  local root = tree:root()
  local blocks = {}
  local capture_ids = {}
  for idx, name in ipairs(query.captures) do
    capture_ids[name] = idx
  end
  for _, match in query:iter_matches(root, bufnr, 0, -1) do
    local lang_node = normalize_node(match[capture_ids.lang])
    local content_node = normalize_node(match[capture_ids.content])
    local block_node = normalize_node(match[capture_ids.block])
    if lang_node and content_node and block_node then
      local ok_info, info = pcall(vim.treesitter.get_node_text, lang_node, bufnr)
      if not ok_info then
        info = nil
      end
      local tag = info and info:match("^(%S+)") or ""
      if tag == fence then
        local ok_range, sr, _, er, _ = pcall(function()
          return block_node:range()
        end)
        local ok_content, content = pcall(vim.treesitter.get_node_text, content_node, bufnr)
        if ok_range and ok_content and content then
          table.insert(blocks, {
            content = content,
            range = { start_row = sr, end_row = er },
            hash = hash_text(content),
            filetype = vim.bo[bufnr].filetype,
          })
        end
      end
    end
  end

  return blocks
end

local function extract_markdown(bufnr, fence)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks = {}
  local in_block = false
  local start_row = 0
  local content = {}

  for i, line in ipairs(lines) do
    if not in_block then
      local open = line:match("^```%s*(%w+)%s*$")
      if open == fence then
        in_block = true
        start_row = i - 1
        content = {}
      end
    else
      if line:match("^```%s*$") then
        local end_row = i - 1
        local body = table.concat(content, "\n")
        table.insert(blocks, {
          content = body,
          range = { start_row = start_row, end_row = end_row },
          hash = hash_text(body),
          filetype = vim.bo[bufnr].filetype,
        })
        in_block = false
      else
        table.insert(content, line)
      end
    end
  end
  return blocks
end

function M.extract(bufnr, cfg)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  cfg = cfg or {}
  if cfg.markdown and cfg.markdown.enabled then
    local fence = cfg.markdown.fence or "mermaid"
    if cfg.treesitter and cfg.treesitter.enable then
      local blocks = extract_treesitter(bufnr, fence)
      if blocks and #blocks > 0 then
        return blocks
      end
    end
    return extract_markdown(bufnr, fence)
  end
  return {}
end

function M.extract_at_cursor(bufnr, cfg)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  cfg = cfg or {}
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  if cfg.treesitter and cfg.treesitter.enable then
    local blocks = M.extract(bufnr, cfg)
    for _, block in ipairs(blocks) do
      if row >= block.range.start_row and row <= block.range.end_row then
        return block
      end
    end
    return nil
  end

  if not (cfg.markdown and cfg.markdown.enabled) then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local fence = cfg.markdown.fence or "mermaid"

  local start_row = nil
  for i = row, 0, -1 do
    local line = lines[i + 1]
    if line:match("^```%s*" .. fence .. "%s*$") then
      start_row = i
      break
    elseif line:match("^```%s*$") and i < row then
      return nil
    end
  end

  if not start_row then
    return nil
  end

  local end_row = nil
  local content_lines = {}
  for i = start_row + 1, #lines - 1 do
    local line = lines[i + 1]
    if line:match("^```%s*$") then
      end_row = i
      break
    end
    table.insert(content_lines, line)
  end

  if not end_row then
    return nil
  end
  if row < start_row or row > end_row then
    return nil
  end

  local content = table.concat(content_lines, "\n")
  return {
    content = content,
    range = { start_row = start_row, end_row = end_row },
    hash = hash_text(content),
    filetype = vim.bo[bufnr].filetype,
  }
end

return M
