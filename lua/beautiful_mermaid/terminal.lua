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
  return "unknown"
end

function M.supports_kitty_graphics(app)
  return app == "ghostty" or app == "kitty" or app == "wezterm"
end

return M
