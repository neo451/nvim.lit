local Model = {}
Model.__index = Model

local function make_schedule(opts)
   local schedule = {}

   for index = 1, opts.long_break_every do
      schedule[#schedule + 1] = {
         name = "Focus",
         kind = "focus",
         duration = opts.focus_minutes * 60,
      }

      local is_long_break = index == opts.long_break_every
      schedule[#schedule + 1] = {
         name = is_long_break and "Long Break" or "Short Break",
         kind = "break",
         duration = (is_long_break and opts.long_break_minutes or opts.short_break_minutes) * 60,
      }
   end

   return schedule
end

local function phase_copy(phase, index)
   if not phase then
      return nil
   end

   return {
      name = phase.name,
      kind = phase.kind,
      duration = phase.duration,
      index = index,
   }
end

function Model.new(opts)
   return setmetatable({
      schedule = make_schedule(opts),
      status = "idle",
      index = nil,
      deadline = nil,
      remaining = nil,
   }, Model)
end

function Model:start(now)
   if self.status == "running" or self.status == "paused" then
      return false
   end

   self.status = "running"
   self.index = 1
   self.deadline = now + self.schedule[self.index].duration
   self.remaining = nil
   return true
end

function Model:pause(now)
   if self.status ~= "running" then
      return false
   end

   self.remaining = math.max(0, self.deadline - now)
   self.deadline = nil
   self.status = "paused"
   return true
end

function Model:resume(now)
   if self.status ~= "paused" then
      return false
   end

   self.deadline = now + self.remaining
   self.remaining = nil
   self.status = "running"
   return true
end

function Model:stop()
   if self.status == "idle" or self.status == "stopped" then
      return false
   end

   self.status = "stopped"
   self.index = nil
   self.deadline = nil
   self.remaining = nil
   return true
end

-- Advance against absolute deadlines so delayed callbacks and system sleep do
-- not add drift. Return every phase transition crossed by `now`.
function Model:advance(now)
   local events = {}
   if self.status ~= "running" then
      return events
   end

   while now >= self.deadline do
      local completed_index = self.index
      local completed = self.schedule[completed_index]
      self.index = completed_index % #self.schedule + 1
      local next_phase = self.schedule[self.index]

      events[#events + 1] = {
         completed = phase_copy(completed, completed_index),
         next = phase_copy(next_phase, self.index),
      }
      self.deadline = self.deadline + next_phase.duration
   end

   return events
end

function Model:get_status(now)
   local phase = self.schedule[self.index]
   local remaining

   if self.status == "running" then
      remaining = math.max(0, self.deadline - now)
   elseif self.status == "paused" then
      remaining = self.remaining
   end

   return {
      status = self.status,
      phase = phase_copy(phase, self.index),
      remaining_seconds = remaining,
   }
end

return Model
