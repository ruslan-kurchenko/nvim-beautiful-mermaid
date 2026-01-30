local M = {}

local function find_command(cmd)
  if cmd and cmd ~= "auto" then
    return vim.fn.executable(cmd) == 1 and cmd or nil
  end
  if vim.fn.executable("resvg") == 1 then
    return "resvg"
  end
  if vim.fn.executable("rsvg-convert") == 1 then
    return "rsvg-convert"
  end
  if vim.fn.executable("magick") == 1 then
    return "magick"
  end
  if vim.fn.executable("convert") == 1 then
    return "convert"
  end
  return nil
end

local function build_args(cmd, svg_path, png_path, opts)
  local dpi = opts.dpi or 144
  local width = opts.width
  local height = opts.height

  if cmd == "resvg" then
    local args = { "resvg", svg_path, png_path }
    if width then
      table.insert(args, "-w")
      table.insert(args, tostring(width))
    else
      table.insert(args, "--dpi")
      table.insert(args, tostring(dpi))
    end
    return args
  end
  if cmd == "rsvg-convert" then
    if width and height then
      return { "rsvg-convert", "-w", tostring(width), "-h", tostring(height), "-a", "-o", png_path, svg_path }
    end
    return { "rsvg-convert", "-d", tostring(dpi), "-p", tostring(dpi), "-o", png_path, svg_path }
  end
  if cmd == "magick" then
    if width and height then
      return { "magick", svg_path, "-resize", width .. "x" .. height, png_path }
    end
    return { "magick", "-density", tostring(dpi), svg_path, png_path }
  end
  if cmd == "convert" then
    if width and height then
      return { "convert", svg_path, "-resize", width .. "x" .. height, png_path }
    end
    return { "convert", "-density", tostring(dpi), svg_path, png_path }
  end
  return nil
end

local function get_plugin_root()
  local info = debug.getinfo(1, "S")
  local path = info.source:sub(2)
  return vim.fn.fnamemodify(path, ":h:h:h:h")
end

local function preprocess_svg(svg_path)
  local preprocessed_path = svg_path:gsub("%.svg$", ".preprocessed.svg")
  local plugin_root = get_plugin_root()
  local script = plugin_root .. "/scripts/preprocess-svg.js"

  if vim.fn.filereadable(script) ~= 1 then
    return svg_path
  end

  local bun = vim.fn.executable("bun") == 1 and "bun" or nil
  local node = vim.fn.executable("node") == 1 and "node" or nil
  local runner = bun or node
  if not runner then
    return svg_path
  end

  local out = vim.fn.system({ runner, script, svg_path, preprocessed_path })
  if vim.v.shell_error ~= 0 then
    return svg_path
  end

  return preprocessed_path
end

---@deprecated Use rasterize_async instead.
function M.rasterize(svg_path, png_path, cfg, size_opts)
  local cmd = find_command(cfg.rasterizer.command)
  if not cmd then
    return false, "no rasterizer command available"
  end

  local actual_svg = preprocess_svg(svg_path)

  local opts = {
    dpi = cfg.rasterizer.dpi,
    width = size_opts and size_opts.width,
    height = size_opts and size_opts.height,
  }

  local args = build_args(cmd, actual_svg, png_path, opts)
  if not args then
    return false, "failed to build rasterizer args"
  end

  local out = vim.fn.system(args)
  if vim.v.shell_error ~= 0 then
    return false, out
  end
  return true, nil
end

function M.rasterize_async(svg_path, png_path, cfg, size_opts, callback)
  local cmd = find_command(cfg.rasterizer.command)
  if not cmd then
    callback(false, "no rasterizer command available")
    return
  end

  local actual_svg = preprocess_svg(svg_path)

  local opts = {
    dpi = cfg.rasterizer.dpi,
    width = size_opts and size_opts.width,
    height = size_opts and size_opts.height,
  }

  local args = build_args(cmd, actual_svg, png_path, opts)
  if not args then
    callback(false, "failed to build rasterizer args")
    return
  end

  local completed = false
  local timeout_timer
  local function finalize(ok, err)
    if completed then
      return
    end
    completed = true
    if timeout_timer then
      timeout_timer:stop()
      timeout_timer:close()
    end
    callback(ok, err)
  end

  local job_id = vim.fn.jobstart(args, {
    on_exit = function(_, code)
      if completed then
        return
      end
      if code ~= 0 then
        finalize(false, "rasterizer exited with code " .. code)
        return
      end
      finalize(true, nil)
    end,
  })

  if job_id <= 0 then
    finalize(false, "failed to start rasterizer job")
    return
  end

  local timeout_ms = cfg.rasterizer.timeout_ms or 3000
  if timeout_ms > 0 then
    timeout_timer = vim.uv.new_timer()
    timeout_timer:start(timeout_ms, 0, vim.schedule_wrap(function()
      if completed then
        return
      end
      if vim.fn.jobwait({ job_id }, 0)[1] == -1 then
        vim.fn.jobstop(job_id)
        finalize(false, "rasterizer timeout after " .. timeout_ms .. "ms")
      end
    end))
  end
end

function M.is_available(cfg)
  return find_command(cfg.rasterizer.command) ~= nil
end

function M.get_command(cfg)
  return find_command(cfg.rasterizer.command)
end

return M
