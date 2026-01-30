if vim.g.loaded_beautiful_mermaid == 1 then
  return
end
vim.g.loaded_beautiful_mermaid = 1

vim.api.nvim_create_user_command("MermaidCheckHealth", function()
  require("beautiful_mermaid.health").check()
end, {})
