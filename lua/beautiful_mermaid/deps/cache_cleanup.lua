local M = {}

local function get_cache_dirs()
  local base = vim.fn.stdpath("cache") .. "/beautiful_mermaid"
  return {
    base,
    base .. "/split",
  }
end

function M.cleanup(max_age_days)
  max_age_days = max_age_days or 7
  local max_age_seconds = max_age_days * 24 * 60 * 60
  local now = os.time()
  local removed = 0

  for _, dir in ipairs(get_cache_dirs()) do
    if vim.fn.isdirectory(dir) == 1 then
      local files = vim.fn.glob(dir .. "/*", false, true)
      for _, file in ipairs(files) do
        local stat = vim.uv.fs_stat(file)
        if stat and stat.type == "file" then
          local age = now - stat.mtime.sec
          if age > max_age_seconds then
            vim.fn.delete(file)
            removed = removed + 1
          end
        end
      end
    end
  end

  return removed
end

return M
