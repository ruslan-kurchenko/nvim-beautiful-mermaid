# nvim-beautiful-mermaid Architecture

Developer reference for the plugin architecture and module structure.

## Overview

This plugin renders Mermaid diagrams inline in Neovim using:
- **Beautiful Mermaid** library for SVG/ASCII generation
- **image.nvim** for inline image display
- **resvg** (or alternatives) for SVG-to-PNG rasterization

## Module Layout

```
lua/beautiful_mermaid/
  init.lua              # Main API, setup(), keymaps
  config.lua            # Configuration schema and normalization
  commands.lua          # User command registration
  parser.lua            # Mermaid block extraction (Treesitter + regex)
  cache.lua             # Render result caching
  live.lua              # Live preview autocmds
  lsp.lua               # LSP integration helpers
  health.lua            # :checkhealth module
  terminal.lua          # Terminal detection (Kitty graphics support)
  deps/
    renderer.lua        # Beautiful Mermaid bridge (Bun process)
    rasterizer.lua      # SVG to PNG conversion
    image_backend.lua   # image.nvim wrapper
  targets/
    init.lua            # Target dispatcher
    in_buffer.lua       # Inline extmark rendering
    float.lua           # Floating window preview
    split.lua           # Side-by-side live preview
    external.lua        # External viewer + export
scripts/
  render-mermaid.js     # Bun script for Beautiful Mermaid
  preprocess-svg.js     # SVG post-processing (arrow visibility)
  vendor/
    beautiful-mermaid.bundle.cjs  # Bundled Beautiful Mermaid
plugin/
  beautiful_mermaid.lua # Autoload entrypoint
```

## Data Flow

### Render Pipeline

```
1. Detect mermaid blocks (parser.lua)
   - Treesitter query for markdown fences
   - Regex fallback if Treesitter unavailable

2. Check cache (cache.lua)
   - Key = hash(content + options + format)
   - Return cached result if available

3. Render via Bun process (deps/renderer.lua)
   - Spawn: bun scripts/render-mermaid.js
   - Input: JSON { text, options, format }
   - Output: JSON { svg, error }

4. Post-process SVG (scripts/preprocess-svg.js)
   - Increase stroke widths for visibility
   - Enlarge arrowheads

5. Rasterize to PNG (deps/rasterizer.lua)
   - resvg, rsvg-convert, or ImageMagick
   - Optional: custom width/height for sizing

6. Display via image.nvim (deps/image_backend.lua)
   - Kitty graphics protocol
   - Extmark positioning

7. Cache result (cache.lua)
```

### Target Types

| Target | Module | Description |
|--------|--------|-------------|
| `in_buffer` | `targets/in_buffer.lua` | Renders image at block location using extmarks |
| `float` | `targets/float.lua` | Shows diagram in floating window |
| `split` | `targets/split.lua` | Side-by-side live editing view |
| `external` | `targets/external.lua` | Opens in external viewer or exports to file |

## Key Modules

### config.lua

- Defines default configuration schema
- Validates and normalizes user options
- Auto-detects terminal capabilities (`render.backend = "auto"`)
- Supports per-buffer config overrides

### parser.lua

- Extracts mermaid fenced code blocks from markdown
- Primary: Treesitter query for `fenced_code_block` with mermaid info string
- Fallback: Regex pattern matching
- Returns: `{ content, start_row, end_row, hash }`

### deps/renderer.lua

- Manages Bun subprocess for Beautiful Mermaid
- JSON protocol: request/response over stdin/stdout
- Async rendering with callback
- Timeout handling and error propagation

### deps/rasterizer.lua

- Converts SVG to PNG for image.nvim display
- Auto-detects available tool: resvg > rsvg-convert > magick
- Supports custom DPI and dimensions
- Synchronous (blocking) - runs via `vim.fn.system()`

### deps/image_backend.lua

- Wrapper around image.nvim API
- Handles image creation, positioning, clearing
- Manages image lifecycle tied to buffer/window

### targets/split.lua

- Creates vertical split with preview buffer
- Tracks source buffer cursor position
- Debounced updates (500ms) on text/cursor change
- Auto-closes when source buffer is wiped

## Configuration Flow

```lua
setup(user_opts)
  |
  v
config.normalize(user_opts)
  |-- Merge with defaults
  |-- Validate enums (target, format, backend)
  |-- Auto-detect backend if "auto"
  |-- Validate numeric fields
  v
state.config = normalized_config
  |
  v
setup_highlights()    -- MermaidPreview, MermaidError, MermaidPlaceholder
setup_keymaps()       -- Register key mappings
commands.setup()      -- Register user commands
lsp.setup()           -- LSP integration (optional)
live.enable/disable() -- Live preview autocmds
```

## Error Handling

- **Renderer failures**: Surfaced via `vim.notify()`, cached stale output preserved
- **Rasterizer failures**: Error shown in preview, fallback to placeholder
- **Missing dependencies**: Detected by `:checkhealth`, graceful degradation
- **Treesitter unavailable**: Falls back to regex parsing

## Caching Strategy

- **Key generation**: SHA256 hash of content + render options
- **Buffer-local storage**: Tied to buffer lifecycle
- **Size limit**: Configurable `cache.max_entries` (default 200)
- **Invalidation**: On config changes or explicit clear

## External Dependencies

| Dependency | Purpose | Required |
|------------|---------|----------|
| Bun | JavaScript runtime for Beautiful Mermaid | Yes |
| image.nvim | Inline image display | Yes (for SVG) |
| resvg/rsvg-convert/magick | SVG rasterization | Yes (for SVG) |
| Treesitter (mermaid) | Block detection | No (regex fallback) |

## References

- [Neovim API](https://neovim.io/doc/user/api.html)
- [image.nvim](https://github.com/3rd/image.nvim)
- [Beautiful Mermaid](https://github.com/lukilabs/beautiful-mermaid)
- [Kitty Graphics Protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/)
