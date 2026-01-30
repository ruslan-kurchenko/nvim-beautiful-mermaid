local M = {}

function M.setup(api)
  vim.api.nvim_create_user_command("MermaidRender", function()
    api.render_current()
  end, {})

  vim.api.nvim_create_user_command("MermaidRenderAll", function()
    api.render_all()
  end, {})

  vim.api.nvim_create_user_command("MermaidExport", function(opts)
    api.export_current(opts.args)
  end, { nargs = "?" })

  vim.api.nvim_create_user_command("MermaidExportAll", function(opts)
    api.export_all(opts.args)
  end, { nargs = "?" })
end

return M
