local M = {}

local function build_command(cfg)
  if cfg.renderer and cfg.renderer.command then
    return cfg.renderer.command
  end
  if vim.fn.executable("bun") == 1 then
    return "bun"
  end
  return nil
end

local function script_path(cfg)
  if cfg.renderer and cfg.renderer.script then
    return cfg.renderer.script
  end
  local root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h:h")
  return root .. "/scripts/renderer.js"
end

function M.script_path(cfg)
  return script_path(cfg)
end

local function encode_request(source, cfg)
  return vim.fn.json_encode({
    text = source,
    format = cfg.render.format,
    theme = cfg.mermaid.theme,
    options = cfg.mermaid.options,
  })
end

function M.render_async(source, cfg, cb)
  local cmd = build_command(cfg)
  if not cmd then
    cb({ ok = false, error = "beautiful_mermaid: bun not found" })
    return
  end

  local script = script_path(cfg)
  local stdout = {}
  local stderr = {}

  local done = false
  local timer
  local function decode_error_payload(text)
    if not text or text == "" then
      return nil
    end
    local ok, decoded = pcall(vim.fn.json_decode, text)
    if not ok or type(decoded) ~= "table" then
      return nil
    end
    if decoded.error and decoded.error ~= "" then
      return decoded.error
    end
    return nil
  end
  local function finalize(result)
    if done then
      return
    end
    done = true
    if timer then
      timer:stop()
      timer:close()
    end
    cb(result)
  end

  local job_id = vim.fn.jobstart({ cmd, script }, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stdout, line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stderr, line)
          end
        end
      end
    end,
    on_exit = function(_, code)
      local out = table.concat(stdout, "")
      local err = table.concat(stderr, "\n")
      if code ~= 0 then
        local msg = err
        if msg == "" then
          msg = decode_error_payload(out) or out
        end
        if msg == "" then
          msg = ("beautiful_mermaid: renderer exited with code %d"):format(code)
        end
        finalize({ ok = false, error = msg })
        return
      end
      local ok, decoded = pcall(vim.fn.json_decode, out)
      if not ok or not decoded then
        local msg = decode_error_payload(out) or err
        if msg == "" then
          msg = "beautiful_mermaid: invalid renderer response"
        end
        finalize({ ok = false, error = msg })
        return
      end
      if decoded.error then
        finalize({ ok = false, error = decoded.error })
        return
      end
      finalize({ ok = true, output = decoded.output })
    end,
  })

  if job_id <= 0 then
    finalize({ ok = false, error = "beautiful_mermaid: failed to start renderer" })
    return
  end

  if cfg.renderer.timeout_ms and cfg.renderer.timeout_ms > 0 then
    timer = vim.uv.new_timer()
    timer:start(cfg.renderer.timeout_ms, 0, vim.schedule_wrap(function()
      if vim.fn.jobwait({ job_id }, 0)[1] == -1 then
        vim.fn.jobstop(job_id)
        finalize({ ok = false, error = "beautiful_mermaid: renderer timeout" })
      end
    end))
  end

  vim.fn.chansend(job_id, encode_request(source, cfg))
  vim.fn.chanclose(job_id, "stdin")
end

function M.is_available(cfg)
  return build_command(cfg) ~= nil
end

return M
