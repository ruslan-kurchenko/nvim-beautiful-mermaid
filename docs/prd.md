# Product Requirements Document (PRD)
# nvim-beautiful-mermaid

## Summary
Neovim plugin that renders Mermaid diagrams using Beautiful Mermaid. Primary target is in-buffer rendering for Mermaid fenced blocks in markdown, with configurable targets for floating window or external viewer. Scope includes live preview, export, LSP integration, and Treesitter integration. Neovim >=0.9.

## Problem Statement
Mermaid diagrams in Neovim are hard to preview inline while editing. Users want fast, non-blocking previews directly in the buffer, with options to render elsewhere and export artifacts.

## Goals
- In-buffer preview for Mermaid fenced blocks in markdown.
- Configurable render targets: in-buffer (default), floating window, external viewer.
- Live preview with debounced updates.
- Export diagrams to SVG or ASCII.
- Optional Treesitter and LSP integration.
- Async rendering via external process, no UI blocking.

## Non-Goals
- Full markdown parsing in Lua.
- Immediate support for all filetypes beyond markdown.
- Shipping a Mermaid language server (integration only).

## Users and Use Cases
- Neovim users writing markdown docs with Mermaid diagrams.
- Developers who want quick visual feedback while editing diagrams.
- Users who need exportable SVGs for docs or presentations.

## User Stories
- As a user, I can see Mermaid previews inline without leaving the buffer.
- As a user, I can switch preview target to a floating window or external viewer.
- As a user, previews update automatically as I edit a Mermaid block.
- As a user, I can export a diagram to SVG or ASCII.
- As a user, I can enable Treesitter-based detection for more reliable parsing.
- As a user, I can integrate with my existing Mermaid LSP setup.

## Functional Requirements
- Detect Mermaid fenced blocks in markdown (Treesitter preferred, regex fallback).
- Render Mermaid to SVG or ASCII using Beautiful Mermaid (renderMermaid / renderMermaidAscii).
- Provide buffer-local preview without modifying source text.
- Live preview via autocmds with debounce.
- Export current block or all blocks to file.
- Support floating window and external viewer targets.
- Cache render results by content + options + target.
- Provide :checkhealth integration for dependencies.

## Non-Functional Requirements
- Non-blocking UI: rendering happens in async job.
- Debounced updates to avoid thrashing.
- Graceful failure: errors surfaced without breaking editing.
- Minimal dependencies and clear configuration defaults.
- Compatibility with Neovim >=0.9.

## Scope
In scope:
- Core plugin structure, config, renderer bridge, parser, targets.
- Live preview, export, caching, health checks.
- Optional Treesitter and LSP integration.
- Documentation for installation and usage.

Out of scope:
- Full markdown parser.
- Non-markdown filetype support beyond initial hooks.
- Bundled Mermaid LSP server.

## Success Criteria
- Preview updates within 300ms after editing a Mermaid block (debounced).
- No UI freeze during render operations.
- Export produces valid SVG/ASCII files.
- checkhealth reports actionable diagnostics.
- Works with default config on Neovim >=0.9.

## Risks and Mitigations
- External renderer dependency missing: use checkhealth and clear error messages.
- Treesitter not installed: fallback to regex.
- Large diagrams slow to render: caching and debounce.
- Target rendering inconsistencies: keep in-buffer as source of truth and avoid destructive edits.

## Dependencies
- Neovim >=0.9 runtime (job control, timers, extmarks).
- Bun for renderer bridge.
- Optional: tree-sitter-mermaid grammar.

## Task Breakdown

Task IDs are referenced in dependencies. Complexity is 0-10.

### Core Foundations
- T1: Project skeleton, module layout, entrypoint files. Complexity: 3. Dependencies: none.
  - Define Lua module tree and plugin entrypoint.
  - Provide minimal init that loads config and core modules.
  - Ensure load order works with common plugin managers.
- T2: Configuration schema, defaults, validation. Complexity: 4. Dependencies: T1.
  - Define public setup() API and default config.
  - Validate render target/format enums and user options.
  - Allow per-buffer overrides when needed.
- T3: Renderer bridge (jobstart, JSON protocol). Complexity: 6. Dependencies: T1, T2.
  - Implement job lifecycle (spawn, restart, shutdown).
  - Define request/response JSON schema and error mapping.
  - Support svg and ascii outputs from Beautiful Mermaid.
- T4: Mermaid block parser (Treesitter + regex fallback). Complexity: 5. Dependencies: T1.
  - Identify fenced blocks and extract content ranges.
  - Provide fallback regex for environments without Treesitter.
  - Preserve accurate ranges for updates and cache keys.
- T5: Cache layer (buffer-local + optional global LRU). Complexity: 4. Dependencies: T1.
  - Hash content + options + target + format.
  - Invalidate on config/theme change.
  - Limit cache size to avoid memory growth.

Acceptance criteria:
- Plugin loads with setup() and defaults without errors.
- Renderer bridge can return SVG for a sample diagram.
- Parser finds Mermaid fences in markdown.

### Rendering Targets and Live Preview
- T6: In-buffer target (extmarks/virtual text). Complexity: 7. Dependencies: T3, T4, T5.
  - Render placeholder/preview without modifying source text.
  - Map previews to block ranges for partial updates.
  - Handle buffer edits and stale extmarks cleanly.
- T7: Live preview autocmds + debounce. Complexity: 6. Dependencies: T6.
  - Wire TextChanged/TextChangedI/BufWritePost events.
  - Debounce with vim.uv timers and cancel in-flight renders.
  - Re-render only changed blocks.
- T8: Floating window target. Complexity: 5. Dependencies: T3, T4.
  - Show preview for current block with cursor tracking.
  - Provide commands or keymaps for toggling.
  - Respect window lifecycle and close conditions.
- T9: External viewer target. Complexity: 4. Dependencies: T3.
  - Write output to temp file and invoke user command.
  - Support manual refresh and auto-refresh options.
  - Avoid blocking the editor during open/refresh.

Acceptance criteria:
- In-buffer previews render without modifying source text.
- Live preview updates reliably and does not block input.
- Float and external targets can be toggled via config.

### Export and Integration
- T10: Export current/all blocks to SVG or ASCII. Complexity: 4. Dependencies: T3, T4.
  - Provide commands for export target path selection.
  - Support single block or all blocks in buffer.
  - Return clear errors on write failures.
- T11: Treesitter integration and injection guidance. Complexity: 5. Dependencies: T4.
  - Detect mermaid injections in markdown queries.
  - Document required Treesitter grammar install.
  - Ensure safe fallback behavior without Treesitter.
- T12: LSP integration helpers (optional). Complexity: 3. Dependencies: T1.
  - Provide setup helper or toggles tied to LSP attach.
  - Avoid overriding user LSP config.
  - Keep integration optional and default-off if needed.

Acceptance criteria:
- Export writes valid files to user-specified path.
- Treesitter integration improves block detection when enabled.
- LSP helpers do not override user configs.

### Health Checks and Documentation
- T13: :checkhealth module (runtime checks). Complexity: 3. Dependencies: T1.
  - Check Neovim version and renderer availability.
  - Report Treesitter availability when enabled.
  - Report external viewer command validity.
- T14: Plugin manager install docs (lazy.nvim, packer.nvim, vim-plug, rocks.nvim). Complexity: 2. Dependencies: T1.
  - Provide minimal install + setup snippets.
  - Note Neovim version requirement.
- Mention optional dependencies (bun, Treesitter).
- T15: Usage docs and examples. Complexity: 3. Dependencies: T2, T6, T7, T10.
  - Document basic workflow and commands.
  - Include configuration examples for targets.
  - Add export examples for svg/ascii.
- T16: Minimal tests (parser + renderer protocol). Complexity: 5. Dependencies: T3, T4.
  - Parser unit tests for fenced blocks.
  - Renderer protocol tests for success/error paths.
  - Ensure tests do not require GUI or network.

Acceptance criteria:
- checkhealth reports missing deps with actionable messages.
- Docs cover installation, configuration, and export.
- Tests cover core parser and renderer bridge.

## Open Questions
- Which image backend (if any) should be recommended for SVG display in-buffer?
- Should ASCII be default fallback when SVG rendering is not supported?
