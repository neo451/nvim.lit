local new_set, eq = MiniTest.new_set, MiniTest.expect.equality
local Model = require("pomodoro.model")

local T = new_set()

local function model(opts)
   return Model.new(vim.tbl_extend("force", {
      focus_minutes = 1,
      short_break_minutes = 1,
      long_break_minutes = 2,
      long_break_every = 2,
   }, opts or {}))
end

T["starts with a focus phase"] = function()
   local timer = model()

   eq(true, timer:start(100))
   eq({
      status = "running",
      phase = { name = "Focus", kind = "focus", duration = 60, index = 1 },
      remaining_seconds = 60,
   }, timer:get_status(100))
   eq({}, timer:advance(159))
end

T["advances through short and long breaks and repeats"] = function()
   local timer = model()
   timer:start(100)

   local first = timer:advance(160)
   eq(1, #first)
   eq("Focus", first[1].completed.name)
   eq("Short Break", first[1].next.name)

   local later = timer:advance(400)
   eq(3, #later)
   eq("Short Break", later[1].completed.name)
   eq("Long Break", later[3].completed.name)
   eq("Focus", later[3].next.name)
   eq(60, timer:get_status(400).remaining_seconds)
end

T["pause preserves remaining time and resume creates a new deadline"] = function()
   local timer = model()
   timer:start(100)

   eq(true, timer:pause(120))
   eq("paused", timer:get_status(500).status)
   eq(40, timer:get_status(500).remaining_seconds)
   eq(true, timer:resume(1000))
   eq(40, timer:get_status(1000).remaining_seconds)
   eq({}, timer:advance(1039))
   eq(1, #timer:advance(1040))
end

T["stop clears the active phase"] = function()
   local timer = model()
   timer:start(100)

   eq(true, timer:stop())
   eq({ status = "stopped", phase = nil, remaining_seconds = nil }, timer:get_status(200))
   eq({}, timer:advance(1000))
end

return T
