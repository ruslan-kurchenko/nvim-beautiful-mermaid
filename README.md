# nvim-beautiful-mermaid

Neovim plugin to render Mermaid diagrams using Beautiful Mermaid.

## Requirements
- Neovim 0.9+
- Bun
- bundled beautiful-mermaid (included in this plugin)

## Setup
### lazy.nvim
```lua
{
  "yourname/nvim-beautiful-mermaid",
  opts = {},
}
```

### lazy.nvim (with image.nvim for inline SVG)
```lua
{
  "yourname/nvim-beautiful-mermaid",
  dependencies = { "3rd/image.nvim" },
  config = function()
    require("image").setup({
      backend = "kitty",
      integrations = {
        markdown = { enabled = false },
      },
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
  config = function()
    require("beautiful_mermaid").setup({})
  end,
})
```

### packer.nvim (with image.nvim for inline SVG)
```lua
use({
  "yourname/nvim-beautiful-mermaid",
  requires = { "3rd/image.nvim" },
  config = function()
    require("image").setup({
      backend = "kitty",
      integrations = {
        markdown = { enabled = false },
      },
    })
    require("beautiful_mermaid").setup({
      render = { target = "in_buffer", format = "svg", backend = "image" },
    })
  end,
})
```

### vim-plug
```vim
Plug 'yourname/nvim-beautiful-mermaid'
lua << EOF
require("beautiful_mermaid").setup({})
EOF
```

### vim-plug (with image.nvim for inline SVG)
```vim
Plug '3rd/image.nvim'
Plug 'yourname/nvim-beautiful-mermaid'
lua << EOF
require("image").setup({
  backend = "kitty",
  integrations = {
    markdown = { enabled = false },
  },
})
require("beautiful_mermaid").setup({
  render = { target = "in_buffer", format = "svg", backend = "image" },
})
EOF
```

### rocks.nvim
```lua
require("rocks").setup({
  rocks = {
    "nvim-beautiful-mermaid",
  },
})
```

### rocks.nvim (with image.nvim for inline SVG)
```lua
require("rocks").setup({
  rocks = {
    "image.nvim",
    "nvim-beautiful-mermaid",
  },
})
require("image").setup({
  backend = "kitty",
  integrations = {
    markdown = { enabled = false },
  },
})
require("beautiful_mermaid").setup({
  render = { target = "in_buffer", format = "svg", backend = "image" },
})
```

### Basic configuration
```lua
require("beautiful_mermaid").setup({})
```

### Example configuration
```lua
require("beautiful_mermaid").setup({
  render = {
    target = "in_buffer",
    format = "ascii",
    backend = "auto",
    live = true,
    debounce_ms = 200,
  },
  mermaid = {
    theme = "default",
    options = {
      padding = 8,
      nodeSpacing = 30,
      layerSpacing = 40,
      transparent = false,
    },
  },
  external = {
    command = "open",
  },
  lsp = {
    enable = true,
    server = "mermaid",
  },
  treesitter = {
    enable = true,
    injection_lang = "mermaid",
  },
})
```

## Commands
- :MermaidRender
- :MermaidRenderAll
- :MermaidExport [path]
- :MermaidExportAll [path]
- :MermaidCheckHealth

## Export paths
- If path is a directory, exports are written as `mermaid-N.svg` (or `.txt`).
- If path is a file, exports are written as `path-N.svg` (or `.txt`).

## Rendering notes
- In-buffer rendering uses ASCII for visibility.
- For SVG, set `render.target = "external"` and provide `external.command` (e.g. "open").
- Inline SVG rendering is available when `image.nvim` and a rasterizer are installed.

## Auto-switching by terminal
Default behavior for `render.backend = "auto"`:
- Ghostty/Kitty/WezTerm: inline SVG via `image.nvim` (Kitty graphics protocol)
- Alacritty: external SVG if `external.command` is set; otherwise ASCII
- Other terminals: ASCII

You can override by setting `render.backend` explicitly.

## Inline SVG rendering (optional)
To render SVGs inline with images:
- Install `image.nvim` and configure your terminal backend.
- Install a rasterizer: `resvg`, `rsvg-convert`, or ImageMagick (`magick`/`convert`).
- Set:
```lua
require("beautiful_mermaid").setup({
  render = { target = "in_buffer", format = "svg", backend = "image" },
})
```

## Tmux support

Inline SVG rendering works inside tmux with proper configuration.

### Requirements
- Tmux >= 3.3
- Terminal that supports Kitty graphics protocol (Kitty, Ghostty, WezTerm)

### Tmux configuration
Add these lines to your `~/.tmux.conf`:
```bash
set -g allow-passthrough on
set -g visual-activity off
```

Then reload tmux: `tmux source-file ~/.tmux.conf`

### image.nvim configuration
To prevent images from leaking to other tmux windows/panes:
```lua
require("image").setup({
  backend = "kitty",
  tmux_show_only_in_active_window = true,
  integrations = {
    markdown = { enabled = false },
  },
})
```

### Full tmux-compatible setup (lazy.nvim)
```lua
{
  "yourname/nvim-beautiful-mermaid",
  dependencies = { "3rd/image.nvim" },
  config = function()
    require("image").setup({
      backend = "kitty",
      tmux_show_only_in_active_window = true,
      integrations = {
        markdown = { enabled = false },
      },
    })
    require("beautiful_mermaid").setup({
      render = { target = "in_buffer", format = "svg", backend = "image" },
    })
  end,
}
```

### Troubleshooting tmux images
- **Images appear in all tmux windows**: Ensure `visual-activity off` is set in tmux.conf
- **No images at all**: Ensure `allow-passthrough on` is set in tmux.conf
- **Images flicker**: Try setting `editor_only_render_when_focused = true` in image.nvim

## Treesitter
- Install `tree-sitter-mermaid` for best block detection.
- Regex parsing is used as fallback when Treesitter is unavailable.

## LSP
- If you use a Mermaid LSP, set `lsp.server` to its client name.
- The plugin will render on LspAttach when enabled.
