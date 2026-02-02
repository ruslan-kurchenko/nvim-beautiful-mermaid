local M = {}

-- Map nvim colorscheme names to beautiful-mermaid theme names
local THEME_MAP = {
  ["tokyonight-night"] = "tokyo-night",
  ["tokyonight-storm"] = "tokyo-night-storm",
  ["tokyonight-moon"] = "tokyo-night",
  ["tokyonight-day"] = "tokyo-night-light",
  ["catppuccin-mocha"] = "catppuccin-mocha",
  ["catppuccin-latte"] = "catppuccin-latte",
  ["catppuccin-frappe"] = "catppuccin-mocha",
  ["catppuccin-macchiato"] = "catppuccin-mocha",
  ["nord"] = "nord",
  ["dracula"] = "dracula",
  ["github_dark"] = "github-dark",
  ["github_light"] = "github-light",
}

-- Map semantic color roles to highlight group fallback chains
local SEMANTIC_MAP = {
  bg = { "Normal" },
  fg = { "Normal" },
  muted = { "Comment", "NonText" },
  accent = { "Function", "Keyword", "Identifier" },
  surface = { "Visual", "CursorLine", "Pmenu" },
  border = { "WinSeparator", "VertSplit", "FloatBorder" },
  line = { "Statement", "Type", "Special" },
}

-- Cache for extracted colors
local color_cache = nil

--- Get highlight color attribute
--- @param name string Highlight group name
--- @param attr string Attribute name ('fg' or 'bg')
--- @return string|nil Hex color or nil
function M.get_hl_color(name, attr)
  local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
  local color = hl[attr]
  if not color then
    return nil
  end
  -- Handle NONE/transparent
  if color == 0 or color == "NONE" then
    return nil
  end
  return string.format("#%06x", color)
end

--- Extract colors from current colorscheme
--- @return table<string, string|nil> Semantic color map
function M.extract_colors()
  -- Return cached colors if available
  if color_cache then
    return color_cache
  end

  local colors = {}

  -- Extract each semantic color using fallback chains
  for role, groups in pairs(SEMANTIC_MAP) do
    local color = nil
    local attr = (role == "bg") and "bg" or "fg"

    -- Try each highlight group in the fallback chain
    for _, group in ipairs(groups) do
      color = M.get_hl_color(group, attr)
      if color then
        break
      end
    end

    colors[role] = color
  end

  -- Cache the extracted colors
  color_cache = colors

  return colors
end

--- Match colorscheme name to beautiful-mermaid theme
--- @param colors_name string|nil Colorscheme name from vim.g.colors_name
--- @return string|nil Matched theme name or nil
function M.match_theme(colors_name)
  if not colors_name then
    return nil
  end

  -- Direct match
  if THEME_MAP[colors_name] then
    return THEME_MAP[colors_name]
  end

  -- Partial match (e.g., "tokyonight" matches "tokyonight-night")
  for pattern, theme in pairs(THEME_MAP) do
    if colors_name:find(pattern, 1, true) or pattern:find(colors_name, 1, true) then
      return theme
    end
  end

  return nil
end

--- Resolve final theme configuration
--- @param user_theme string|nil User-specified theme
--- @param user_options table|nil User-specified theme options
--- @return string|nil theme Final theme name
--- @return table|nil options Final theme options (extracted colors)
function M.resolve(user_theme, user_options)
  -- If user explicitly set theme, use it
  if user_theme and user_theme ~= "auto" then
    return user_theme, user_options
  end

  -- Try to match current colorscheme
  local colors_name = vim.g.colors_name
  local matched_theme = M.match_theme(colors_name)

  if matched_theme then
    return matched_theme, user_options
  end

  -- Fall back to extracting colors
  local extracted = M.extract_colors()
  return nil, extracted
end

--- Invalidate color cache (call when colorscheme changes)
function M.invalidate_cache()
  color_cache = nil
end

return M
