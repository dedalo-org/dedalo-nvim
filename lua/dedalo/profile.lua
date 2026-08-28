--- What the last annotation cost, in milliseconds.
---
--- The plugin shells out three or four times per attach, and "is it slow" is a
--- question the README should answer with a number rather than with a
--- reassurance. This records what the last attach actually took, so anybody
--- can produce that number on their own repository instead of trusting ours.
---
--- Recording is unconditional and costs one `hrtime()` per stage — cheaper
--- than the branch that would decide whether to record.
local M = {}

---@class dedalo.Timing
---@field stage string
---@field ms number
---@field cached boolean Whether the stage was answered from cache.

---@type dedalo.Timing[]
local timings = {}

--- Start a new attach. Drops whatever the previous one recorded.
function M.reset()
  timings = {}
end

--- Time `work`, an asynchronous stage that calls back exactly once.
---
--- Wrapping rather than bracketing because every stage here is a subprocess
--- with a callback: `hrtime()` on either side of the *call* would measure how
--- long it took to spawn, which is not the question.
---@generic T
---@param stage string
---@param work fun(finish: fun(...): nil)
---@param on_done fun(...): nil
function M.stage(stage, work, on_done)
  local started = vim.uv.hrtime()
  work(function(...)
    timings[#timings + 1] = {
      stage = stage,
      ms = (vim.uv.hrtime() - started) / 1e6,
      cached = false,
    }
    on_done(...)
  end)
end

--- Record a stage that was answered from cache, without timing it.
---
--- A cache hit that showed up as `0.02 ms` would read as "this stage is free",
--- which is the wrong lesson: it is free *this time*.
---@param stage string
function M.cached(stage)
  timings[#timings + 1] = { stage = stage, ms = 0, cached = true }
end

--- Everything recorded for the last attach.
---@return dedalo.Timing[]
function M.last()
  return vim.deepcopy(timings)
end

--- The last attach as lines, for `:Dedalo profile` and `:checkhealth`.
---@return string[]
function M.report()
  if #timings == 0 then
    return { "nothing recorded yet — run `:Dedalo attach` first" }
  end

  local lines = {}
  local total = 0
  for _, timing in ipairs(timings) do
    if timing.cached then
      lines[#lines + 1] = ("%-28s %s"):format(timing.stage, "cached")
    else
      total = total + timing.ms
      lines[#lines + 1] = ("%-28s %8.1f ms"):format(timing.stage, timing.ms)
    end
  end
  lines[#lines + 1] = ("%-28s %8.1f ms"):format("total", total)
  return lines
end

return M
