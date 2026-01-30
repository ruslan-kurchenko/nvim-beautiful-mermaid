local M = {}

function M.setup(api)
  vim.api.nvim_create_user_command("MermaidRender", function()
    api.render_current()
  end, { desc = "Render mermaid block under cursor" })

  vim.api.nvim_create_user_command("MermaidRenderAll", function()
    api.render_all()
  end, { desc = "Render all mermaid blocks in buffer" })

  vim.api.nvim_create_user_command("MermaidPreview", function()
    api.preview_current()
  end, { desc = "Preview mermaid block in floating window" })

  vim.api.nvim_create_user_command("MermaidPreviewClose", function()
    api.preview_close()
  end, { desc = "Close mermaid preview window" })

  vim.api.nvim_create_user_command("MermaidClear", function()
    api.clear_all()
  end, { desc = "Clear all mermaid previews" })

  vim.api.nvim_create_user_command("MermaidExport", function(opts)
    api.export_current(opts.args)
  end, { nargs = "?", desc = "Export mermaid block to file" })

  vim.api.nvim_create_user_command("MermaidExportAll", function(opts)
    api.export_all(opts.args)
  end, { nargs = "?", desc = "Export all mermaid blocks to files" })
end

return M
