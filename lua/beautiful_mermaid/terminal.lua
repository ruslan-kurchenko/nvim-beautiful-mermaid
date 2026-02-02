local M = {}

local function env(name)
  local v = vim.env[name]
  if v == nil then
    return nil
  end
  return tostring(v)
end

function M.is_tmux()
  return env("TMUX") ~= nil
end

local function detect_from_process_tree()
  local handle = io.popen("pstree -s $$ 2>/dev/null")
  if not handle then
    return nil
  end
  local result = handle:read("*a")
  handle:close()
  if not result or result == "" then
    return nil
  end
  result = result:lower()
  if result:find("ghostty") then
    return "ghostty"
  end
  if result:find("kitty") then
    return "kitty"
  end
  if result:find("wezterm") then
    return "wezterm"
  end
  if result:find("alacritty") then
    return "alacritty"
  end
  return nil
end

function M.detect()
  local term = env("TERM") or ""
  local term_program = env("TERM_PROGRAM") or ""

  if env("GHOSTTY") or term_program:lower() == "ghostty" or term:find("ghostty", 1, true) then
    return "ghostty"
  end
  if env("KITTY_WINDOW_ID") or term:find("kitty", 1, true) then
    return "kitty"
  end
  if env("WEZTERM_EXECUTABLE") or env("WEZTERM_PANE") then
    return "wezterm"
  end
  if env("ALACRITTY_LOG") or term_program:lower() == "alacritty" or term == "alacritty" then
    return "alacritty"
  end

  local from_tree = detect_from_process_tree()
  if from_tree then
    return from_tree
  end

  return "unknown"
end

function M.supports_kitty_graphics(app)
  return app == "ghostty" or app == "kitty" or app == "wezterm"
end

return M
