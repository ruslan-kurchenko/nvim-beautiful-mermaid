local M = {}

local timer = nil
local group = vim.api.nvim_create_augroup("BeautifulMermaidLive", { clear = true })

local function debounce(ms, fn)
  if timer then
    timer:stop()
    timer:close()
  end
  timer = vim.uv.new_timer()
  timer:start(ms, 0, vim.schedule_wrap(fn))
end

function M.enable(api)
  vim.api.nvim_clear_autocmds({ group = group })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
    group = group,
    callback = function()
      local cfg = api.get_config(vim.api.nvim_get_current_buf())
      debounce(cfg.render.debounce_ms, function()
        api.render_all()
      end)
    end,
  })
end

function M.disable()
  vim.api.nvim_clear_autocmds({ group = group })
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
end

return M
