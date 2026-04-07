local M = {}
local opencode = require("_opencode")

local prompts = {
   commit = [[Run `git diff --cached` to see the staged changes. If empty, fall back to `git diff HEAD`.
Based on that diff, generate a single conventional commit message.
Format: type(scope): description
Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- Scope is optional, use only when changes are clearly focused on one area
- Keep the subject line under 72 characters
- Be specific and concise
- Output ONLY the raw commit message, no markdown fences, no explanation, no extra text]],

   pr = [[Run `git diff --cached` to see the staged changes. If empty, fall back to `git diff HEAD`.
Based on that diff, generate a detailed conventional commit message suitable for a PR merge commit.
Format:
type(scope): short description

- bullet point explaining a change
- another bullet point
- ...

BREAKING CHANGE: description (only if applicable)

Rules:
- Use conventional commit types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- Scope is optional
- Keep subject line under 72 characters
- Wrap body lines at 72 characters
- Use bullet points (- ) for each logical change
- Include BREAKING CHANGE footer only if there are breaking changes
- Output ONLY the raw commit message, no markdown fences, no explanation, no extra text]],
}

--- Strip markdown code fences that models tend to wrap around output.
---@param text string
---@return string
local function strip_fences(text)
   -- remove leading ```<lang>\n and trailing \n```
   text = text:gsub("^%s*```[^\n]*\n", "")
   text = text:gsub("\n```%s*$", "")
   -- also handle the case where the whole thing is fenced on one line
   text = text:gsub("^%s*```(.-)```%s*$", "%1")
   return vim.trim(text)
end

local function insert_message(message, bufnr)
   if not vim.api.nvim_buf_is_valid(bufnr) then
      vim.notify("Buffer no longer valid", vim.log.levels.ERROR, { title = "AI Commit" })
      return
   end
   local lines = vim.split(message, "\n", { plain = true })
   -- find the first comment line (starts with #) to know where to insert
   local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
   local insert_end = 0
   for i, line in ipairs(buf_lines) do
      if line:match("^#") then
         insert_end = i - 1
         break
      end
      insert_end = i
   end
   -- replace everything before the first comment line
   vim.api.nvim_buf_set_lines(bufnr, 0, insert_end, false, lines)
end

--- Core generation function.
---@param style "commit"|"pr"
---@param hint? string
local function generate(style, hint)
   local prompt = prompts[style] or prompts.commit
   if hint and hint ~= "" then
      prompt = prompt .. "\n\nAdditional context: " .. hint
   end

   local bufnr = vim.api.nvim_get_current_buf()

   vim.notify("Generating commit message...", vim.log.levels.INFO, { title = "AI Commit" })

   opencode(prompt, function(output)
      output = strip_fences(output)

      if output == "" then
         vim.notify("AI returned an empty response", vim.log.levels.WARN, { title = "AI Commit" })
         return
      end

      insert_message(output, bufnr)
   end)
end

--- Setup the buffer-local :AICommit command.
function M.setup()
   vim.api.nvim_buf_create_user_command(0, "AICommit", function(opts)
      local arg = vim.trim(opts.args or "")

      if arg == "commit" then
         generate("commit")
      elseif arg == "pr" then
         generate("pr")
      elseif arg ~= "" then
         -- anything else is treated as a custom hint
         generate("commit", arg)
      else
         -- no argument: interactive select
         vim.ui.select({ "commit", "pr", "custom..." }, {
            prompt = "Commit message style:",
         }, function(choice)
            if not choice then
               return
            end
            if choice == "custom..." then
               vim.ui.input({ prompt = "Hint: " }, function(input)
                  if input and input ~= "" then
                     generate("commit", input)
                  end
               end)
            else
               generate(choice)
            end
         end)
      end
   end, {
      nargs = "?",
      desc = "Generate a conventional commit message with AI (opencode)",
      complete = function()
         return { "commit", "pr" }
      end,
   })
end

return M
