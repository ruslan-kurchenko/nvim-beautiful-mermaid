# nvim-beautiful-mermaid - Critical Assessment

> Assessment Date: January 30, 2026
> Reviewer: AI Architecture Review Team (Oracle + Explore Agents)
> Overall Health: **NEEDS ATTENTION** - Several critical issues identified

## Executive Summary

This Neovim plugin for rendering Mermaid diagrams has a solid foundation but contains **several production-grade correctness and scale problems** that will affect real users:

1. **Multi-block rendering is broken** for image backend (each block clears all images)
2. **"Live" rendering can render the wrong buffer** due to current-buffer usage + global debounce
3. **SVG-to-PNG rasterization is synchronous** with no real timeout enforcement (UI freezes)
4. **Cache files accumulate indefinitely** with no cleanup mechanism

### Impact Assessment

| Severity | Count | User Impact |
|----------|-------|-------------|
| CRITICAL | 4 | UI freezes, incorrect renders, data loss |
| HIGH | 7 | Performance degradation, confusing errors |
| MEDIUM | 8 | Code maintainability, inconsistent UX |
| LOW | 3 | Minor polish issues |

## Top Priority Fixes (Action Required)

### 1. Fix Buffer Context Races (CRITICAL)
**Effort: 1-4 hours**

Stop using "current buffer" in async/autocmd paths. The debounce timer and LspAttach handler can render the wrong buffer if user switches buffers.

**Files affected:**
- `lua/beautiful_mermaid/live.lua`
- `lua/beautiful_mermaid/lsp.lua`

### 2. Fix Multi-Block Rendering (CRITICAL)
**Effort: 1-4 hours**

`in_buffer.lua` calls `image_backend.clear(bufnr)` which clears ALL images for the buffer. With async completion order variance, whichever block renders last wipes previously rendered images.

**Files affected:**
- `lua/beautiful_mermaid/targets/in_buffer.lua`
- `lua/beautiful_mermaid/deps/image_backend.lua`

### 3. Make Rasterization Non-Blocking (CRITICAL)
**Effort: 1-2 days**

Replace synchronous `vim.fn.system()` with async `jobstart()`/`vim.system()` and enforce timeout. Currently UI freezes on large diagrams.

**Files affected:**
- `lua/beautiful_mermaid/deps/rasterizer.lua`

### 4. Add Stale Result Protection (HIGH)
**Effort: 1-4 hours**

Tag render requests with generation number. Drop callbacks if generation changed to prevent stale diagrams overwriting newer content.

## Architecture Score

| Category | Score | Notes |
|----------|-------|-------|
| **Code Organization** | 7/10 | Good module separation, some duplication |
| **Error Handling** | 5/10 | pcall used well, but io.open/mkdir unchecked |
| **Performance** | 4/10 | Sync rasterizer, no cursor optimization |
| **Testability** | 3/10 | Global state, hard vim dependencies |
| **Security** | 5/10 | ImageMagick as fallback is risky |
| **API Design** | 6/10 | Inconsistent signatures and naming |

## Recommended Upgrade Path

### Phase 1: Critical Fixes (Week 1)
- [ ] Fix buffer pinning in deferred work
- [ ] Fix per-block image identity
- [ ] Make rasterizer async with timeout
- [ ] Add generation-based stale-result dropping

### Phase 2: Quality Improvements (Week 2)
- [ ] Implement disk cache cleanup policy
- [ ] Optimize `extract_at_cursor()` for large files
- [ ] Normalize module interfaces and error patterns
- [ ] Security: prefer resvg over ImageMagick

### Phase 3: Polish (Week 3+)
- [ ] Add comprehensive tests
- [ ] Improve error messages for users
- [ ] Documentation updates
- [ ] Performance profiling and optimization

## Detailed Issues

See [ASSESSMENT-ISSUES.md](./ASSESSMENT-ISSUES.md) for the complete issue list with code references and fix suggestions.
