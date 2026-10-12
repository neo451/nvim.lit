local Model = require("pomodoro.model")

local M = {}

local defaults = {
   focus_minutes = 25,
   short_break_minutes = 5,
   long_break_minutes = 15,
   long_break_every = 4,
   notify = {
      nvim = true,
      system = false,
   },
}

local options
local model
local timer

local function now()
   -- Wall time advances across system sleep, unlike a process-local countdown.
   return os.time()
end

local function validate_options(opts)
   for _, key in ipairs({ "focus_minutes", "short_break_minutes", "long_break_minutes", "long_break_every" }) do
      assert(type(opts[key]) == "number" and opts[key] > 0 and opts[key] % 1 == 0, key .. " must be a positive integer")
   end

   assert(type(opts.notify.nvim) == "boolean", "notify.nvim must be a boolean")
   assert(type(opts.notify.system) == "boolean", "notify.system must be a boolean")
end

local function close_timer()
   if timer then
      timer:stop()
      timer:close()
      timer = nil
   end
end

local function ps_utf16le_ascii(text)
   local bytes = {}
   for index = 1, #text do
      bytes[#bytes + 1] = text:sub(index, index)
      bytes[#bytes + 1] = "\0"
   end
   return table.concat(bytes)
end

local function notify_windows(title, message)
   if vim.fn.executable("powershell.exe") ~= 1 then
      vim.notify("powershell.exe is unavailable; Windows notification was not sent", vim.log.levels.WARN, {
         title = "Pomodoro",
      })
      return
   end

   -- Keep user-visible text out of PowerShell source; pass only base64 payloads.
   local title_b64 = vim.base64.encode(title)
   local message_b64 = vim.base64.encode(message)
   local script = ([[$ErrorActionPreference = 'Stop'
Import-Module BurntToast -ErrorAction Stop
$title = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('%s'))
$message = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('%s'))
New-BurntToastNotification -Text $title, $message]]):format(title_b64, message_b64)
   local encoded_script = vim.base64.encode(ps_utf16le_ascii(script))

   local ok, process = pcall(vim.system, {
      "powershell.exe",
      "-NoLogo",
      "-NoProfile",
      "-NonInteractive",
      "-EncodedCommand",
      encoded_script,
   }, { text = true }, function(result)
      if result.code ~= 0 then
         vim.schedule(function()
            vim.notify(
               "Windows notification failed. Install BurntToast in Windows PowerShell with:\n"
                  .. "Install-Module BurntToast -Scope CurrentUser",
               vim.log.levels.WARN,
               { title = "Pomodoro" }
            )
         end)
      end
   end)

   if not ok then
      vim.notify("Could not start powershell.exe: " .. tostring(process), vim.log.levels.WARN, {
         title = "Pomodoro",
      })
   end
end

local function notify_completion(event)
   local message = ("%s complete. %s starts (%dm)."):format(
      event.completed.name,
      event.next.name,
      event.next.duration / 60
   )

   if options.notify.nvim then
      vim.notify(message, vim.log.levels.INFO, { title = "Pomodoro" })
   end
   if options.notify.system then
      notify_windows("Pomodoro", message)
   end
end

local function update()
   if not model then
      return
   end

   for _, event in ipairs(model:advance(now())) do
      notify_completion(event)
   end
end

local function start_timer()
   close_timer()
   timer = vim.uv.new_timer()
   timer:start(1000, 1000, vim.schedule_wrap(update))
end

local function format_time(seconds)
   seconds = math.max(0, seconds or 0)
   local minutes = math.floor(seconds / 60)
   local remainder = seconds % 60
   return ("%02d:%02d"):format(minutes, remainder)
end

local function command_error(message)
   vim.notify(message, vim.log.levels.WARN, { title = "Pomodoro" })
end

local function status_message()
   local status = M.get_status()
   if not status.phase then
      return "Pomodoro " .. status.status
   end

   local phase = status.phase
   return ("Pomodoro %s — %s %s"):format(status.status, phase.name, format_time(status.remaining_seconds))
end

function M.start()
   if not model:start(now()) then
      command_error("A Pomodoro cycle is already active; stop it before starting over")
      return false
   end

   start_timer()
   return true
end

function M.pause()
   update()
   if not model:pause(now()) then
      command_error("There is no running Pomodoro cycle to pause")
      return false
   end

   close_timer()
   return true
end

function M.resume()
   if not model:resume(now()) then
      command_error("There is no paused Pomodoro cycle to resume")
      return false
   end

   start_timer()
   return true
end

function M.stop()
   close_timer()
   if not model:stop() then
      command_error("There is no active Pomodoro cycle to stop")
      return false
   end
   return true
end

function M.get_status()
   update()
   return model:get_status(now())
end

local subcommands = {
   start = M.start,
   pause = M.pause,
   resume = M.resume,
   stop = M.stop,
   status = function()
      vim.notify(status_message(), vim.log.levels.INFO, { title = "Pomodoro" })
   end,
}

local function setup_command()
   vim.api.nvim_create_user_command("Pomodoro", function(args)
      local action = args.args == "" and "status" or vim.trim(args.args):lower()
      local callback = subcommands[action]
      if not callback then
         command_error("Usage: :Pomodoro start|pause|resume|stop|status")
         return
      end
      callback()
   end, {
      nargs = "?",
      complete = function()
         return { "start", "pause", "resume", "stop", "status" }
      end,
      desc = "Control the Pomodoro focus/break cycle",
      force = true,
   })
end

function M.setup(opts)
   close_timer()
   options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
   validate_options(options)
   model = Model.new(options)
   setup_command()

   local group = vim.api.nvim_create_augroup("Pomodoro", { clear = true })
   vim.api.nvim_create_autocmd("VimLeavePre", {
      group = group,
      desc = "Close the Pomodoro timer when Neovim exits",
      callback = close_timer,
   })
end

return M
