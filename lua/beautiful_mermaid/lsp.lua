local M = {}

local group = vim.api.nvim_create_augroup("BeautifulMermaidLsp", { clear = true })

function M.setup(api)
  vim.api.nvim_clear_autocmds({ group = group })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local bufnr = args.buf
      local cfg = api.get_config(bufnr)
      if not cfg.lsp.enable then
        return
      end
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or client.name ~= cfg.lsp.server then
        return
      end
       if cfg.render.live then
         api.render_all(bufnr)
       end
    end,
  })
end

return M
