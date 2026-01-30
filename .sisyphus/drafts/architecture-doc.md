# Draft: Architecture Doc Plan

## Requirements (confirmed)
- "Produce a structured plan to deliver /docs/architecture.md for a Neovim plugin that integrates Beautiful Mermaid"
- "Phased plan with tasks, dependencies, verification steps, and recommended delegation categories + skills per task"
- "Include steps for codebase analysis, plugin manager requirements audit, architecture doc sections, and implementation plan with acceptance criteria"
- "Deliverable is /docs/architecture.md"
- "Need lazy.nvim, packer.nvim, vim-plug, rocks.nvim coverage; Neovim >=0.9"
- Render target: in-buffer rendering as primary, configurable to switch targets; alternative targets include floating window or external viewer
- Scope IN: live preview, export, LSP integration, Treesitter integration
- Repo path confirmed for analysis: /Users/ruslan.kurchenko_1/Projects/personal/beautiful-mermaid

## Technical Decisions
- Minimum Neovim version: >=0.9
- Render target strategy: in-buffer primary with configurable alternative targets (floating window, external viewer)
- Scope includes live preview, export, LSP integration, Treesitter integration

## Research Findings
- System-designer skill loaded to guide architecture documentation patterns (C4 model and rationale-first documentation)

## Open Questions
- None outstanding

## Scope Boundaries
- INCLUDE: architecture doc sections for plugin, plugin manager coverage (lazy.nvim, packer.nvim, vim-plug, rocks.nvim)
- EXCLUDE: implementation work, code changes
