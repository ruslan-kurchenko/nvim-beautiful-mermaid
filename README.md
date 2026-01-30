# nvim-beautiful-mermaid

Neovim plugin to render Mermaid diagrams inline using Beautiful Mermaid and image.nvim.

![Mermaid diagram rendered inline in Neovim](https://github.com/user-attachments/assets/placeholder.png)

## Features

- **Inline rendering** - Diagrams render directly in your buffer
- **Floating preview** - Pop-up preview window for quick diagram viewing
- **SVG + ASCII support** - High-quality SVG images or ASCII fallback
- **Live updates** - Diagrams re-render as you type (configurable)
- **Tmux compatible** - Works inside tmux with proper configuration
- **Customizable keymaps** - All keymaps are configurable or can be disabled
- **Theme-aware highlights** - Matches your colorscheme automatically

## Requirements

- Neovim 0.9+
- [Bun](https://bun.sh/) - JavaScript runtime
- [image.nvim](https://github.com/3rd/image.nvim) - For inline image rendering
- A rasterizer: `resvg` (recommended), `rsvg-convert`, or ImageMagick
- Terminal with Kitty graphics protocol: Kitty, Ghostty, or WezTerm

### Installing dependencies

```bash
# Install Bun
curl -fsSL https://bun.sh/install | bash

# Install resvg (recommended rasterizer)
brew install resvg        # macOS
cargo install resvg       # or via Rust
```

## Installation

### lazy.nvim (recommended)

```lua
{
  "yourname/nvim-beautiful-mermaid",
  dependencies = { "3rd/image.nvim" },
  config = function()
    require("image").setup({
      backend = "kitty",
      editor_only_render_when_focused = true,  -- Recommended for tmux
      integrations = { markdown = { enabled = false } },
    })
    require("beautiful_mermaid").setup({
      render = { target = "in_buffer", format = "svg", backend = "image" },
    })
  end,
}
```

### packer.nvim

```lua
use({
  "yourname/nvim-beautiful-mermaid",
  requires = { "3rd/image.nvim" },
  config = function()
    require("image").setup({
      backend = "kitty",
      editor_only_render_when_focused = true,
      integrations = { markdown = { enabled = false } },
    })
    require("beautiful_mermaid").setup({
      render = { target = "in_buffer", format = "svg", backend = "image" },
    })
  end,
})
```

### vim-plug

```vim
Plug '3rd/image.nvim'
Plug 'yourname/nvim-beautiful-mermaid'

lua << EOF
require("image").setup({
  backend = "kitty",
  editor_only_render_when_focused = true,
  integrations = { markdown = { enabled = false } },
})
require("beautiful_mermaid").setup({
  render = { target = "in_buffer", format = "svg", backend = "image" },
})
EOF
```

## Commands

| Command | Description |
|---------|-------------|
| `:MermaidRender` | Render the mermaid block under cursor |
| `:MermaidRenderAll` | Render all mermaid blocks in buffer |
| `:MermaidPreview` | Show diagram in floating window |
| `:MermaidPreviewClose` | Close the floating preview |
| `:MermaidClear` | Clear all rendered diagrams |
| `:MermaidExport [path]` | Export current block to file |
| `:MermaidExportAll [path]` | Export all blocks to files |
| `:MermaidCheckHealth` | Check plugin dependencies |

## Keymaps

Default keymaps (all configurable):

| Keymap | Action | Description |
|--------|--------|-------------|
| `<leader>rr` | `render` | Render mermaid block under cursor |
| `<leader>rR` | `render_all` | Render all mermaid blocks |
| `<leader>rf` | `preview` | Preview in floating window |
| `<leader>rc` | `clear` | Clear all previews |

### Customizing keymaps

```lua
require("beautiful_mermaid").setup({
  keymaps = {
    render = "<leader>mr",      -- Custom keymap
    render_all = "<leader>mR",
    preview = "<leader>mp",
    clear = "<leader>mc",
  },
})
```

### Disabling keymaps

```lua
require("beautiful_mermaid").setup({
  keymaps = false,  -- Disable all keymaps
})
```

### Disabling individual keymaps

```lua
require("beautiful_mermaid").setup({
  keymaps = {
    render = "<leader>rr",
    render_all = false,  -- Disable this specific keymap
    preview = "<leader>rf",
    clear = false,
  },
})
```

## Configuration

### Full configuration with defaults

```lua
require("beautiful_mermaid").setup({
  render = {
    target = "in_buffer",   -- "in_buffer" | "float" | "external"
    format = "ascii",       -- "svg" | "ascii"
    backend = "auto",       -- "auto" | "image" | "ascii" | "external"
    live = true,            -- Re-render on text changes
    debounce_ms = 200,      -- Debounce for live rendering
  },
  mermaid = {
    theme = "default",
    options = {
      -- Colors (nil = use defaults)
      bg = nil,
      fg = nil,
      line = nil,
      accent = nil,
      muted = nil,
      surface = nil,
      border = nil,
      -- Typography
      font = nil,           -- Font family name (e.g., "JetBrains Mono")
      -- Layout
      padding = 8,
      nodeSpacing = 30,
      layerSpacing = 40,
      transparent = false,
    },
  },
  float = {
    max_width = nil,        -- nil = auto-size
    max_height = nil,
    min_width = 40,
    min_height = 10,
  },
  image = {
    backend = "image.nvim",
    max_width = nil,
    max_height = nil,
    scale = 1.0,
    padding_rows = 2,
  },
  rasterizer = {
    command = "auto",       -- "auto" | "resvg" | "rsvg-convert" | "magick"
    dpi = 144,
    timeout_ms = 3000,
  },
  renderer = {
    command = "bun",
    timeout_ms = 5000,
  },
  cache = {
    max_entries = 200,
  },
  external = {
    command = "",           -- e.g., "open" on macOS
  },
  markdown = {
    enabled = true,
    fence = "mermaid",
  },
  lsp = {
    enable = true,
    server = "mermaid",
  },
  treesitter = {
    enable = true,
    injection_lang = "mermaid",
  },
  keymaps = {
    render = "<leader>rr",
    render_all = "<leader>rR",
    preview = "<leader>rf",
    clear = "<leader>rc",
  },
})
```

### Recommended setup for SVG rendering

```lua
require("beautiful_mermaid").setup({
  render = {
    target = "in_buffer",
    format = "svg",
    backend = "image",
  },
})
```

### Custom font

To use a custom font, specify the **font family name** (not the file name):

```lua
require("beautiful_mermaid").setup({
  mermaid = {
    options = {
      font = "JetBrains Mono",      -- or "Fira Code", "SF Mono", etc.
    },
  },
})
```

**Note:** The font must be installed on your system. For Nerd Fonts, use the base family name without weight suffixes (e.g., `"CaskaydiaMono NFP"` not `"CaskaydiaMono NFP SemiLight"`).

## Highlight Groups

The plugin defines these highlight groups that you can customize:

| Group | Default | Description |
|-------|---------|-------------|
| `MermaidPreview` | Green italic (from Directory) | Preview labels and status |
| `MermaidError` | Links to ErrorMsg | Error messages |
| `MermaidPlaceholder` | Green italic | Placeholder text while rendering |

### Customizing highlights

```lua
-- After setup, override the highlights
vim.api.nvim_set_hl(0, "MermaidPreview", { fg = "#7aa2f7", italic = true })
vim.api.nvim_set_hl(0, "MermaidError", { fg = "#f7768e", bold = true })
```

## Tmux Support

Inline SVG rendering works inside tmux with proper configuration.

### Requirements

- Tmux >= 3.3
- Terminal with Kitty graphics protocol (Kitty, Ghostty, WezTerm)

### Tmux configuration

Add to `~/.tmux.conf`:

```bash
set -g allow-passthrough on
set -g visual-activity off
set -g focus-events on
```

Reload: `tmux source-file ~/.tmux.conf`

### image.nvim configuration for tmux

Use `editor_only_render_when_focused` to prevent images from appearing in other panes/windows:

```lua
require("image").setup({
  backend = "kitty",
  editor_only_render_when_focused = true,  -- Clears images on focus loss
  integrations = { markdown = { enabled = false } },
})
```

**Note:** The `tmux_show_only_in_active_window` option has a known bug. Use `editor_only_render_when_focused` instead.

### Full tmux-compatible setup

```lua
{
  "yourname/nvim-beautiful-mermaid",
  dependencies = { "3rd/image.nvim" },
  config = function()
    require("image").setup({
      backend = "kitty",
      editor_only_render_when_focused = true,
      integrations = { markdown = { enabled = false } },
    })
    require("beautiful_mermaid").setup({
      render = { target = "in_buffer", format = "svg", backend = "image" },
    })
  end,
}
```

### Troubleshooting tmux

| Issue | Solution |
|-------|----------|
| Images appear in all windows | Set `visual-activity off` in tmux.conf |
| No images at all | Set `allow-passthrough on` in tmux.conf |
| Images flicker | Use `editor_only_render_when_focused = true` |
| Images persist after switching panes | Use `editor_only_render_when_focused = true` |

## Auto-detection

When `render.backend = "auto"` (default), the plugin auto-detects your terminal:

| Terminal | Behavior |
|----------|----------|
| Ghostty, Kitty, WezTerm | Inline SVG via image.nvim |
| Alacritty | External viewer (if configured) or ASCII |
| Other terminals | ASCII fallback |

## Treesitter

For best mermaid block detection, install the mermaid parser:

```vim
:TSInstall mermaid
```

Regex parsing is used as fallback when Treesitter is unavailable.

## Export

Export diagrams to files:

```vim
:MermaidExport ~/diagram.svg       " Export current block
:MermaidExportAll ~/diagrams/      " Export all blocks to directory
```

- If path is a directory, files are named `mermaid-1.svg`, `mermaid-2.svg`, etc.
- If path is a file, blocks are numbered: `diagram-1.svg`, `diagram-2.svg`, etc.

## Health Check

Run `:MermaidCheckHealth` or `:checkhealth beautiful_mermaid` to verify dependencies.

## License

MIT
