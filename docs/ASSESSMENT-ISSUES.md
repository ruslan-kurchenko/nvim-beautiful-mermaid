# nvim-beautiful-mermaid - Detailed Issue List

> Generated: January 30, 2026

---

## CRITICAL Priority Issues

### CRIT-001: Buffer Context Race in Live Rendering
**Severity:** CRITICAL | **Effort:** 1-4 hours | **Impact:** Incorrect renders, user confusion

**Description:**
`live.lua` uses `vim.api.nvim_get_current_buf()` in the debounced callback. If user switches buffers before debounce fires, the wrong buffer gets rendered/cleared.

**Location:** `lua/beautiful_mermaid/live.lua:19-23`
```lua
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
    callback = function()
      local cfg = api.get_config(vim.api.nvim_get_current_buf())  -- BUG: captures current, not event buffer
      debounce(cfg.render.debounce_ms, function()
        api.render_all()  -- Uses current buffer at execution time
      end)
    end,
  })
```

**Fix:**
1. Capture `bufnr` from event args at callback time
2. Pass `bufnr` through debounce and to `render_all(bufnr)`
3. Make debounce timers per-buffer (`timers[bufnr]` or `vim.b` variables)

---

### CRIT-002: Global Debounce Timer Causes Cross-Buffer Interference
**Severity:** CRITICAL | **Effort:** 1-4 hours | **Impact:** Edits in buffer A cancel renders for buffer B

**Description:**
`live.lua` uses a single global `timer` variable. Edits in any buffer reset the timer, which can cancel pending renders for other buffers.

**Location:** `lua/beautiful_mermaid/live.lua:3-13`
```lua
local timer = nil  -- SINGLE GLOBAL TIMER

local function debounce(ms, fn)
  if timer then
    timer:stop()
    timer:close()
  end
  timer = vim.uv.new_timer()
  -- ...
end
```

**Fix:**
```lua
local timers = {}  -- Per-buffer timers

local function debounce(bufnr, ms, fn)
  if timers[bufnr] then
    timers[bufnr]:stop()
    timers[bufnr]:close()
  end
  timers[bufnr] = vim.uv.new_timer()
  -- ...
end
```

---

### CRIT-003: Multi-Block Rendering Broken (Images Clear Each Other)
**Severity:** CRITICAL | **Effort:** 1-4 hours | **Impact:** Only last block visible with `:MermaidRenderAll`

**Description:**
`in_buffer.show()` calls `M.clear(bufnr, start_row, end_row)` which in turn calls `image_backend.clear(bufnr)` - this clears ALL images for the entire buffer, not just the specific block.

**Location:** `lua/beautiful_mermaid/targets/in_buffer.lua:52, 119-126`
```lua
function M.show(block, output, cfg)
  -- ...
  M.clear(bufnr, block.range.start_row, block.range.end_row)  -- Clears ALL images!
  -- ...
end

function M.clear(bufnr, start_row, end_row)
  image_backend.clear(bufnr)  -- BUG: clears ALL images, ignores start_row/end_row
  -- ...
end
```

**Fix:**
1. Generate stable `block_id` from bufnr + range (e.g., `"bm-" .. bufnr .. "-" .. start_row`)
2. Pass block_id to image_backend and only clear that specific image
3. Use range-based clearing for the image, not buffer-wide

---

### CRIT-004: Synchronous Rasterization Freezes UI
**Severity:** CRITICAL | **Effort:** 1-2 days | **Impact:** UI hangs for seconds on large diagrams

**Description:**
`rasterizer.rasterize()` uses synchronous `vim.fn.system()` which blocks the Neovim event loop. The configured `timeout_ms` is never actually enforced.

**Location:** `lua/beautiful_mermaid/deps/rasterizer.lua:108`
```lua
function M.rasterize(svg_path, png_path, cfg, size_opts)
  -- ...
  local out = vim.fn.system(args)  -- BLOCKING CALL
  if vim.v.shell_error ~= 0 then
    return false, out
  end
  return true, nil
end
```

**Fix:**
Replace with async job:
```lua
function M.rasterize_async(svg_path, png_path, cfg, size_opts, callback)
  local args = build_args(cmd, actual_svg, png_path, opts)
  local timer = nil
  
  local job_id = vim.fn.jobstart(args, {
    on_exit = function(_, code)
      if timer then timer:stop(); timer:close() end
      if code ~= 0 then
        callback(false, "rasterizer failed with code " .. code)
      else
        callback(true, nil)
      end
    end,
  })
  
  -- Enforce timeout
  timer = vim.uv.new_timer()
  timer:start(cfg.rasterizer.timeout_ms, 0, vim.schedule_wrap(function()
    vim.fn.jobstop(job_id)
    callback(false, "rasterizer timeout")
  end))
end
```

---

## HIGH Priority Issues

### HIGH-001: LspAttach Renders Wrong Buffer
**Severity:** HIGH | **Effort:** 30 min | **Impact:** LSP attach triggers render on wrong buffer

**Description:**
`lsp.lua` calls `api.render_all()` without pinning to the attached buffer.

**Location:** `lua/beautiful_mermaid/lsp.lua:19-21`
```lua
if cfg.render.live then
  api.render_all()  -- Should be api.render_all(bufnr) or similar
end
```

---

### HIGH-002: Missing io.open Error Handling
**Severity:** HIGH | **Effort:** 1-2 hours | **Impact:** Silent failures, confusing downstream errors

**Description:**
Multiple files write to disk without checking if `io.open` succeeded.

**Locations:**
- `lua/beautiful_mermaid/targets/in_buffer.lua:65-69`
- `lua/beautiful_mermaid/targets/float.lua:172-178`
- `lua/beautiful_mermaid/targets/split.lua:89-94`
- `lua/beautiful_mermaid/targets/external.lua:10-16`

**Example (in_buffer.lua):**
```lua
local fd = io.open(paths.svg, "w")
if fd then
  fd:write(output)
  fd:close()
end
-- No error handling if fd is nil!
```

**Fix:**
```lua
local fd, err = io.open(paths.svg, "w")
if not fd then
  vim.notify("beautiful_mermaid: failed to write SVG: " .. tostring(err), vim.log.levels.ERROR)
  return
end
fd:write(output)
fd:close()
```

---

### HIGH-003: Missing mkdir Validation
**Severity:** HIGH | **Effort:** 30 min | **Impact:** Silent failures on read-only filesystems

**Description:**
`vim.fn.mkdir(dir, "p")` return value is never checked.

**Locations:**
- `lua/beautiful_mermaid/targets/in_buffer.lua:16-19` (cache_dir function)
- `lua/beautiful_mermaid/targets/float.lua:17-23`
- `lua/beautiful_mermaid/targets/split.lua:23-29`

**Fix:**
```lua
local function cache_dir()
  local dir = vim.fn.stdpath("cache") .. "/beautiful_mermaid"
  local ok = vim.fn.mkdir(dir, "p")
  if ok == 0 and vim.fn.isdirectory(dir) == 0 then
    vim.notify("beautiful_mermaid: failed to create cache directory", vim.log.levels.ERROR)
    return nil
  end
  return dir
end
```

---

### HIGH-004: No Stale Result Protection
**Severity:** HIGH | **Effort:** 1-4 hours | **Impact:** Old render results overwrite newer content

**Description:**
Async renderer callbacks are accepted unconditionally. A late callback from an older render can overwrite a newer state (especially in split/float where triggers are frequent).

**Fix:**
Implement generation-based protection:
```lua
local render_generation = {}  -- Per-buffer generation counter

local function trigger_render(bufnr)
  render_generation[bufnr] = (render_generation[bufnr] or 0) + 1
  local gen = render_generation[bufnr]
  
  renderer.render_async(content, cfg, function(result)
    -- Check if this result is still relevant
    if render_generation[bufnr] ~= gen then
      return  -- Stale result, discard
    end
    -- Process result...
  end)
end
```

---

### HIGH-005: Parser Inefficiency for Cursor-Driven Rendering
**Severity:** HIGH | **Effort:** 1-2 days | **Impact:** O(N) performance on large markdown files

**Description:**
`parser.extract_at_cursor()` calls `extract()` which parses the entire buffer every time. Split preview triggers this on every `CursorMoved` event.

**Location:** `lua/beautiful_mermaid/parser.lua:128-138`
```lua
function M.extract_at_cursor(bufnr, cfg)
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local blocks = M.extract(bufnr, cfg)  -- Parses ENTIRE buffer
  for _, block in ipairs(blocks) do
    if row >= block.range.start_row and row <= block.range.end_row then
      return block
    end
  end
  return nil
end
```

**Fix (for regex fallback):**
Search outward from cursor position:
```lua
function M.extract_at_cursor(bufnr, cfg)
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local fence = cfg.markdown.fence or "mermaid"
  
  -- Search upward for opening fence
  local start_row = nil
  for i = row, 0, -1 do
    if lines[i+1]:match("^```%s*" .. fence) then
      start_row = i
      break
    elseif lines[i+1]:match("^```%s*$") then
      break  -- Found a closing fence before opening
    end
  end
  
  if not start_row then return nil end
  
  -- Search downward for closing fence
  -- ...
end
```

---

### HIGH-006: Cache Files Never Cleaned Up
**Severity:** HIGH | **Effort:** 1-2 days | **Impact:** Disk space grows indefinitely

**Description:**
SVG and PNG files created in `stdpath("cache")/beautiful_mermaid/` are never deleted. Over time, this accumulates gigabytes of orphaned files.

**Fix:**
Implement cache cleanup policy:
1. Track created files in a manifest
2. On `setup()`, prune files older than X days
3. On `:MermaidClear`, offer to clear cache
4. Implement max-size policy

---

### HIGH-007: Memory Leak in image_backend State
**Severity:** HIGH | **Effort:** 1 hour | **Impact:** Memory grows with buffer count

**Description:**
`state.images[bufnr]` entries are never removed even after `clear()`. The table reference remains.

**Location:** `lua/beautiful_mermaid/deps/image_backend.lua:59-75`
```lua
function M.clear(bufnr, id)
  local images = state.images[bufnr]
  if not images then return end
  -- ...
  for key, image in pairs(images) do
    image:clear()
    images[key] = nil  -- Clears entries but table remains in state.images
  end
  -- state.images[bufnr] still exists as empty table!
end
```

**Fix:**
```lua
function M.clear(bufnr, id)
  local images = state.images[bufnr]
  if not images then return end
  
  if id then
    if images[id] then
      images[id]:clear()
      images[id] = nil
    end
  else
    for key, image in pairs(images) do
      image:clear()
    end
    state.images[bufnr] = nil  -- Remove empty table
  end
end
```

---

## MEDIUM Priority Issues

### MED-001: Inconsistent Function Naming
**Severity:** MEDIUM | **Effort:** 30 min | **Impact:** API confusion

**Description:**
Boolean check functions use inconsistent naming:
- `image_backend.lua`: `is_available()`
- `rasterizer.lua`: `available()`

**Fix:** Rename `rasterizer.available()` to `rasterizer.is_available()`

---

### MED-002: Inconsistent clear() Signatures
**Severity:** MEDIUM | **Effort:** 1-2 hours | **Impact:** API confusion, harder refactoring

**Description:**
`clear()` has different signatures across modules:
- `targets/init.lua`: `M.clear(bufnr)`
- `targets/in_buffer.lua`: `M.clear(bufnr, start_row, end_row)`
- `deps/image_backend.lua`: `M.clear(bufnr, id)`

**Fix:**
Standardize to `clear(bufnr, opts)` where `opts` can contain `{ range = {...}, id = "..." }`

---

### MED-003: Inconsistent Error Return Patterns
**Severity:** MEDIUM | **Effort:** 1-2 hours | **Impact:** Inconsistent error handling

**Description:**
- `rasterizer.rasterize()` returns `ok, err` tuple
- `renderer.render_async()` uses callback with `{ ok, output, error }` table

**Fix:**
Pick one pattern and use consistently. Recommend tuple for sync, table for async.

---

### MED-004: Config Normalization Has Side Effects
**Severity:** MEDIUM | **Effort:** 2-4 hours | **Impact:** Surprising mid-session mode changes

**Description:**
`config.normalize()` performs auto backend detection every time `config.get()` is called. This can lead to surprising behavior if terminal environment changes.

**Location:** `lua/beautiful_mermaid/config.lua:106-120`

**Fix:**
Cache the detected backend at `setup()` time, don't re-detect on every `get()`.

---

### MED-005: Duplicated Render Pipeline Logic
**Severity:** MEDIUM | **Effort:** 1-2 days | **Impact:** Bug surface, non-local fixes

**Description:**
`in_buffer.lua`, `float.lua`, and `split.lua` all duplicate:
- `cache_dir()` function
- `cache_paths()` function  
- PNG sizing/rasterization logic
- File I/O patterns

**Fix:**
Extract to `lua/beautiful_mermaid/deps/png_cache.lua`:
```lua
local M = {}

function M.ensure_png(svg_content, cfg, size_opts, callback)
  -- Handles: cache_dir, cache_paths, file I/O, rasterization
  -- Returns: png_path or error
end

return M
```

---

### MED-006: show_error Routes to Wrong Target
**Severity:** MEDIUM | **Effort:** 30 min | **Impact:** Inconsistent error UX

**Description:**
`targets/init.lua` always routes `show_error()` to `in_buffer`, even for float/split targets.

**Location:** `lua/beautiful_mermaid/targets/init.lua:17-19`

**Fix:**
Route errors to the appropriate target based on `cfg.render.target`.

---

### MED-007: Security - ImageMagick as Auto-Fallback
**Severity:** MEDIUM | **Effort:** 1 hour | **Impact:** Security risk with untrusted SVG

**Description:**
When `rasterizer.command = "auto"`, the plugin falls back to ImageMagick (`magick`/`convert`) which has a history of SVG parsing vulnerabilities.

**Location:** `lua/beautiful_mermaid/deps/rasterizer.lua:3-19`

**Fix:**
1. Prefer `resvg` (safest)
2. Don't auto-fallback to ImageMagick
3. Add `:checkhealth` warning if ImageMagick is being used
4. Document the security implications

---

### MED-008: Cache Key Includes Target (Unnecessary)
**Severity:** MEDIUM | **Effort:** 30 min | **Impact:** Wasted cache entries

**Description:**
Cache key includes `cfg.render.target` but renderer output doesn't depend on target.

**Location:** `lua/beautiful_mermaid/cache.lua:56-62`

**Fix:**
Remove `target` from cache key generation.

---

## LOW Priority Issues

### LOW-001: Plugin Entry Command Duplicates Health Check
**Severity:** LOW | **Effort:** 15 min

**Description:**
`plugin/beautiful_mermaid.lua` registers `:MermaidCheckHealth` which duplicates the command registered in `commands.lua`.

---

### LOW-002: preprocess-svg.js Has Hardcoded Values
**Severity:** LOW | **Effort:** 1 hour

**Description:**
Arrow sizes and font fallbacks are hardcoded in the preprocessing script.

---

### LOW-003: Test Coverage Minimal
**Severity:** LOW | **Effort:** 2-3 days

**Description:**
Only 5 basic tests in `tests/run.lua`. No coverage for:
- Async rendering paths
- Error conditions
- Edge cases (large files, special characters)
- Integration with image.nvim

---

## Testability Issues

### TEST-001: Global State Prevents Isolated Tests
**Locations:** All target modules, `image_backend.lua`, `live.lua`

Module-level `state` tables make tests non-deterministic and hard to isolate.

### TEST-002: No Dependency Injection
**Locations:** `renderer.lua`, `rasterizer.lua`

Hard dependencies on subprocess execution prevent unit testing without spawning processes.

### TEST-003: vim Global Dependencies
**Locations:** All files

Almost every function depends on `vim.*` APIs, preventing pure Lua unit tests.

---

## Summary Statistics

| Priority | Count | Estimated Total Effort |
|----------|-------|------------------------|
| CRITICAL | 4 | 2-4 days |
| HIGH | 7 | 3-5 days |
| MEDIUM | 8 | 2-3 days |
| LOW | 3 | 2-3 days |
| **TOTAL** | **22** | **9-15 days** |

---

## Appendix: Files Requiring Changes

| File | Issues | Priority |
|------|--------|----------|
| `live.lua` | CRIT-001, CRIT-002 | CRITICAL |
| `targets/in_buffer.lua` | CRIT-003, HIGH-002, HIGH-003, MED-005 | CRITICAL |
| `deps/rasterizer.lua` | CRIT-004, MED-007 | CRITICAL |
| `deps/image_backend.lua` | CRIT-003, HIGH-007 | HIGH |
| `lsp.lua` | HIGH-001 | HIGH |
| `targets/float.lua` | HIGH-002, HIGH-003, MED-005 | HIGH |
| `targets/split.lua` | HIGH-002, HIGH-003, MED-005 | HIGH |
| `parser.lua` | HIGH-005 | HIGH |
| `cache.lua` | HIGH-006, MED-008 | HIGH |
| `targets/init.lua` | MED-006 | MEDIUM |
| `config.lua` | MED-004 | MEDIUM |
