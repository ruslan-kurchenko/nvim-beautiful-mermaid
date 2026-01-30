# nvim-beautiful-mermaid Architecture

## Purpose
Provide a Neovim plugin that renders Mermaid diagrams using Beautiful Mermaid. Primary render target is in-buffer (starting with markdown code fences) with configurable targets for floating windows or external viewers. Scope includes live preview, export, LSP integration, and Treesitter integration.

## Goals
- Neovim >=0.9 support.
- In-buffer rendering as default target; allow switching to floating window or external viewer.
- First-class support for Mermaid fenced blocks in markdown; design for future non-markdown sources.
- Async, non-blocking rendering pipeline.
- Clear configuration schema and predictable behavior.
- Minimal dependencies; reuse Beautiful Mermaid library.

## Non-Goals
- Full markdown parser implementation in Lua.
- Immediate support for every filetype beyond markdown (planned expansion).
- Built-in Mermaid language server implementation (integration only).

## External Dependencies
- Beautiful Mermaid library:
  - renderMermaid(text, options?) -> Promise<string> (SVG)
  - renderMermaidAscii(text, options?)
  - Options include colors, font, spacing, padding, transparent background
- Neovim runtime:
  - job control, timers (vim.uv), extmarks, virtual text, autocmds

## High-Level Architecture

### Components
- Core: plugin entry and configuration management
- Parser: extracts Mermaid blocks from buffers (markdown fences first)
- Renderer: bridges to Beautiful Mermaid (Node/Bun process)
- Targets: render output into buffer, float, or external viewer
- Cache: memoizes render results keyed by content + options
- Integrations: Treesitter injection, LSP wiring, health checks

### Data Flow (Render Pipeline)
1. Detect Mermaid blocks in buffer (markdown fence, Treesitter or regex fallback)
2. Normalize content (strip fence, trim, ensure "mermaid" header if required)
3. Build render request (content + render options)
4. Check cache (hash of content + options + target)
5. If miss, dispatch async job to renderer (Node/Bun)
6. Receive SVG (or ASCII) result
7. Update target (in-buffer virtual text/extmark overlay or float/external)
8. Store cache entry

## Module Layout (Proposed)
- lua/beautiful_mermaid/init.lua
- lua/beautiful_mermaid/config.lua
- lua/beautiful_mermaid/parser.lua
- lua/beautiful_mermaid/renderer.lua
- lua/beautiful_mermaid/targets/in_buffer.lua
- lua/beautiful_mermaid/targets/float.lua
- lua/beautiful_mermaid/targets/external.lua
- lua/beautiful_mermaid/cache.lua
- lua/beautiful_mermaid/health.lua
- plugin/beautiful_mermaid.lua (autoload entrypoint)
- doc/beautiful-mermaid.txt (help file, later)
- docs/architecture.md (this document)

## Configuration Schema (Draft)
```lua
require("beautiful_mermaid").setup({
  render = {
    target = "in_buffer", -- in_buffer | float | external
    format = "svg", -- svg | ascii
    live = true,
    debounce_ms = 200,
  },
  mermaid = {
    theme = "default", -- maps to Beautiful Mermaid theme
    options = {
      bg = nil,
      fg = nil,
      line = nil,
      accent = nil,
      muted = nil,
      surface = nil,
      border = nil,
      font = nil,
      padding = 8,
      nodeSpacing = 30,
      layerSpacing = 40,
      transparent = false,
    },
  },
  markdown = {
    enabled = true,
    fence = "mermaid",
  },
  external = {
    command = "", -- user-provided viewer command
  },
  lsp = {
    enable = true,
    server = "mermaid", -- depends on user LSP config
  },
  treesitter = {
    enable = true,
    injection_lang = "mermaid",
  },
})
```

## Rendering Targets

### In-Buffer (Primary)
- Use extmarks + virtual text or concealed lines to show a preview placeholder.
- For SVG, store in buffer-local cache and render via image backend in a later phase.
- For ASCII, replace/overlay content directly in buffer.
- Keep original Mermaid fenced block intact to avoid destructive edits.

### Floating Window
- Render SVG or ASCII into a dedicated floating window.
- Sync float with cursor or block bounds.

### External Viewer
- Write SVG to temp file and open with user command.
- Support manual refresh and auto-refresh.

## Parser Strategy
- Primary: Treesitter injection for markdown and mermaid fences.
- Fallback: regex-based fence detection.
- Initial scope: markdown fenced code blocks with "mermaid" tag.
- Future: allow non-markdown buffers via user-defined regex or Treesitter queries.

## Live Preview
- Autocmds on TextChanged, TextChangedI, BufEnter, BufWritePost.
- Debounce using vim.uv timer to avoid rapid re-renders.
- Only re-render blocks that changed (track extmark ranges + hashes).

## Export
- Export current block or all blocks.
- Formats: SVG (default), ASCII.
- Output: write to file path chosen by user.

## LSP Integration
- Provide optional helpers for mermaid LSP setup (no built-in server).
- Respect user LSP config and allow opt-out.
- Use buffer-local commands or autocmds to toggle preview based on LSP attach.

## Treesitter Integration
- Recommend installation of tree-sitter-mermaid grammar.
- Support markdown injections for mermaid fences.
- Use Treesitter queries to locate fenced blocks reliably.

## Health Checks
- :checkhealth integration via lua/beautiful_mermaid/health.lua.
- Validate:
  - Neovim version >=0.9
  - Node/Bun availability for renderer
  - tree-sitter-mermaid present (if enabled)
  - External viewer command (if configured)

## Error Handling
- Surface renderer failures as notifications with actionable messages.
- Keep stale render output if new render fails.
- Avoid hard failure on missing Treesitter; fallback to regex.

## Caching
- Cache key = hash(mermaid_text + render_options + target + format).
- Buffer-local cache for speed; global LRU optional for reuse across buffers.
- Invalidate cache on config changes or theme changes.

## Async Job Strategy
- Renderer runs as external process (bun) to call Beautiful Mermaid.
- Use jobstart + stdin/stdout JSON protocol:
  - Request: { text, options, format }
  - Response: { svg, error }
- Enforce timeout and size limits to prevent hanging jobs.
- Keep renderer process warm if possible; restart on crash.

## Implementation Plan

### Phase 0: Codebase Analysis
- Audit existing files and conventions (repo is currently empty).
- Confirm Neovim version and available runtime dependencies.
- Acceptance: architecture doc aligns with confirmed requirements.

### Phase 1: Skeleton + Configuration
- Create module layout and entrypoints.
- Implement setup() with config schema and defaults.
- Acceptance: plugin loads without errors and exposes setup.
- Verification: :checkhealth reports expected checks (even if they fail gracefully).

### Phase 2: Parser + Renderer Bridge
- Markdown fence extraction (regex fallback).
- Renderer job protocol and process management.
- Acceptance: rendering a sample block returns SVG text.
- Verification: run a minimal buffer test and confirm output.

### Phase 3: In-Buffer Target + Live Preview
- Extmarks and buffer overlays.
- Debounced autocmds and incremental updates.
- Acceptance: editing a Mermaid block updates preview in <= 300ms.
- Verification: manual edit and observe update without blocking input.

### Phase 4: Export + External Targets
- Implement float and external viewer.
- Export current or all blocks.
- Acceptance: exported SVG writes to file and opens in viewer.

### Phase 5: LSP + Treesitter Integration
- Treesitter queries for markdown injection.
- Optional LSP helpers and on_attach integration.
- Acceptance: Treesitter detects blocks; LSP helper does not conflict with user config.

### Phase 6: Docs + Tests
- README usage and examples.
- Minimal tests for parser and renderer protocol.
- Acceptance: documented install steps for lazy.nvim, packer.nvim, vim-plug, rocks.nvim.

## Plugin Manager Installation

### lazy.nvim
```lua
{
  "yourname/nvim-beautiful-mermaid",
  opts = {},
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

### vim-plug
```vim
Plug 'yourname/nvim-beautiful-mermaid'
lua << EOF
require("beautiful_mermaid").setup({})
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

## Verification Checklist
- Neovim >=0.9 detected
- Renderer process available (bun)
- Markdown fence parsing works for mermaid blocks
- In-buffer rendering does not modify source text
- Live preview is debounced and non-blocking
- Export writes SVG successfully
- Treesitter integration optional and safe
- LSP integration optional and safe

## References
- Neovim health: https://neovim.io/doc/user/health.html
- Neovim job control: https://neovim.io/doc/user/job_control.html
- Neovim API/extmarks: https://neovim.io/doc/user/api.html
- Neovim Treesitter: https://neovim.io/doc/user/treesitter.html
- lazy.nvim spec: https://lazy.folke.io/spec
- vim-plug: https://junegunn.github.io/vim-plug/getting-started
- rocks.nvim: https://github.com/lumen-oss/rocks.nvim
- tree-sitter-mermaid: https://github.com/monaqa/tree-sitter-mermaid
- nvim-treesitter markdown injections: https://github.com/nvim-treesitter/nvim-treesitter/blob/master/queries/markdown/injections.scm
