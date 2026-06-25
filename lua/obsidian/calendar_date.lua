local popup = require("calendar.app.popup")
local Date = require("calendar.date")
local daily = require("obsidian.daily")

local daily_hl = "ObsidianCalendarDaily"
vim.cmd("highlight default link " .. daily_hl .. " DiagnosticOk")

---@param timestamp integer|nil
---@return Calendar.date
local function date_from_timestamp(timestamp)
   if not timestamp then
      return Date.today()
   end

   local t = os.date("*t", timestamp)
   return Date.new({
      year = t.year,
      month = t.month,
      day = t.day,
   })
end

---@param cal Calendar
local function mark_existing_dailies(cal)
   cal.day_hl = {}

   local first = cal.date:start_of("month")
   local last = cal.date:end_of("month")
   for _, day in ipairs(first:get_range_until(last)) do
      local path = daily.daily_note_path(day.timestamp)
      if path:exists() then
         cal.day_hl[day:format("%Y-%m-%d")] = daily_hl
      end
   end
end

---@param cal Calendar
local function add_daily_markers(cal)
   local render = cal.render
   cal.render = function(self)
      mark_existing_dailies(self)
      return render(self)
   end
   cal:render()
end

---@param ctx obsidian.resolver.DateCtx
---@param done fun(result: obsidian.resolver.DateResult|?, err: string|?)
return function(ctx, done)
   local cal = popup.open({
      date = date_from_timestamp(ctx.default_timestamp),
      callback = function(date)
         if not date then
            done(nil)
            return
         end

         done({
            timestamp = date.timestamp,
            precision = "day",
         })
      end,
   })

   add_daily_markers(cal)

   local function cancel(self)
      self:close()
      done(nil)
   end

   cal:map("n", "q", cancel)
   cal:map("n", "<Esc>", cancel)
end
