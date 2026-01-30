local M = {}

local timers = {}
local group = vim.api.nvim_create_augroup("BeautifulMermaidLive", { clear = true })

local function debounce(bufnr, ms, fn)
  if timers[bufnr] then
    timers[bufnr]:stop()
    timers[bufnr]:close()
  end
  timers[bufnr] = vim.uv.new_timer()
  timers[bufnr]:start(ms, 0, vim.schedule_wrap(fn))
end

function M.enable(api)
  vim.api.nvim_clear_autocmds({ group = group })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
    group = group,
    callback = function(args)
      local bufnr = args.buf
      local cfg = api.get_config(bufnr)
      debounce(bufnr, cfg.render.debounce_ms, function()
        api.render_all(bufnr)
      end)
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(args)
      local bufnr = args.buf
      if timers[bufnr] then
        timers[bufnr]:stop()
        timers[bufnr]:close()
        timers[bufnr] = nil
      end
    end,
  })
end

function M.disable()
  vim.api.nvim_clear_autocmds({ group = group })
  for bufnr, buf_timer in pairs(timers) do
    buf_timer:stop()
    buf_timer:close()
    timers[bufnr] = nil
  end
end

return M
