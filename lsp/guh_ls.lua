local ms = vim.lsp.protocol.Methods
local action_command = "guh.runKeymap"
local agentic_command = "guh.addIssueContextToAgentic"
local issues_by_repo = {}
local pending_issues = {}

-- Keep these aligned with guh.nvim's `guh.util.set_default_keymaps()`.
local actions = {
   { key = "g?", desc = "Show guh-mappings help" },
   { key = "-", desc = 'Go "up"' },
   { key = "R", desc = "Refresh this guh:// buffer" },
   { key = "gX", desc = "Open this view in web browser" },
   { key = "dd", desc = "View the PR diff" },
   { key = "dz", desc = "Toggle resolved threads in the PR diff" },
   { key = "dl", desc = "View the CI logs for this PR" },
   { key = "]]", desc = "Jump to next diff-file heading or comment" },
   { key = "[[", desc = "Jump to previous diff-file heading or comment" },
   { key = "]f", desc = "View the next PR commit / CI job" },
   { key = "[f", desc = "View the previous PR commit / CI job" },
   { key = "cI", desc = "Rerun CI jobs" },
   { key = "cC", desc = "Comment on PR/issue overview" },
   { key = "c:", desc = "Edit PR/issue properties" },
   { key = "cM", desc = "Merge PR" },
   { key = "cV", desc = "Mark PR/issue notification as read" },
   { key = "cR", desc = "Review PR" },
   { key = "<Enter>", desc = "Open :Guh target at cursor" },
   { key = "o", desc = "Open :Guh target at cursor in a split" },
   { key = "cc", desc = "Comment on PR or diff" },
   { key = "c", mode = "x", desc = "Comment on selected PR/diff lines" },
   { key = "gf", desc = "Open the file at cursor, at current commit" },
   { key = "cr", desc = "Reply to / resolve a comment thread" },
   { key = "cv", desc = 'Toggle "Viewed" on the diff-file at cursor' },
}

local action_by_key = {}
for _, action in ipairs(actions) do
   action_by_key[action.key] = action
end

local function buffer_for_uri(uri)
   local bufnr = vim.fn.bufnr(uri)
   return bufnr > 0 and bufnr or nil
end

local function code_actions(bufnr)
   local result = {}
   for _, action in ipairs(actions) do
      local title = ("%s — %s"):format(action.key, action.desc)
      result[#result + 1] = {
         title = title,
         command = {
            title = title,
            command = action_command,
            arguments = { action.key, action.mode or "n" },
         },
      }
   end

   local feat = (vim.b[bufnr].guh or {}).feat
   if feat == "issue" or feat == "pr" then
      local title = "Send issue/PR context to Agentic"
      result[#result + 1] = {
         title = title,
         command = { title = title, command = agentic_command, arguments = { bufnr } },
      }
   end
   return result
end

local function fuzzy_match(query, text)
   local next_pos = 1
   for i = 1, #query do
      local found = text:find(query:sub(i, i), next_pos, true)
      if not found then
         return false
      end
      next_pos = found + 1
   end
   return true
end

local function completion_context(params)
   local bufnr = buffer_for_uri(params.textDocument.uri)
   if not bufnr or (vim.b[bufnr].guh or {}).feat ~= "comment" then
      return
   end

   local position = params.position
   local line = vim.api.nvim_buf_get_lines(bufnr, position.line, position.line + 1, false)[1] or ""
   local byte_col = vim.str_byteindex(line, position.character, true)
   local before = line:sub(1, byte_col)
   local hash_start, query = before:match(".*()#([^#]*)$")
   if not hash_start then
      return
   end

   local _, start_character = vim.str_utfindex(line, hash_start - 1, true)
   return {
      repo = (vim.b[bufnr].guh or {}).repo,
      line = position.line,
      end_character = position.character,
      start_character = start_character,
      query = query:lower(),
   }
end

local function completion_items(issues, context)
   local result = {}
   for _, issue in ipairs(issues) do
      local number = tostring(issue.number)
      local title = issue.title or ""
      local filter_text = (number .. " " .. title):lower()
      if fuzzy_match(context.query, filter_text) then
         result[#result + 1] = {
            label = ("#%s — %s"):format(number, title),
            filterText = number .. " " .. title,
            kind = vim.lsp.protocol.CompletionItemKind.Reference,
            textEdit = {
               range = {
                  start = { line = context.line, character = context.start_character },
                  ["end"] = { line = context.line, character = context.end_character },
               },
               newText = "#" .. number,
            },
         }
      end
   end
   return result
end

local function load_issues(repo, callback)
   if issues_by_repo[repo] then
      callback(issues_by_repo[repo])
      return
   end

   pending_issues[repo] = pending_issues[repo] or {}
   table.insert(pending_issues[repo], callback)
   if #pending_issues[repo] > 1 then
      return
   end

   local command = {
      "gh",
      "issue",
      "list",
      "--repo",
      repo,
      "--state",
      "all",
      "--limit",
      "1000",
      "--json",
      "number,title",
   }
   local ok = pcall(vim.system, command, { text = true }, function(result)
      vim.schedule(function()
         local issues = {}
         local decoded_ok, decoded = pcall(vim.json.decode, result.stdout or "")
         if result.code == 0 and decoded_ok and type(decoded) == "table" then
            issues = decoded
            issues_by_repo[repo] = issues
         end

         local callbacks = pending_issues[repo]
         pending_issues[repo] = nil
         for _, respond in ipairs(callbacks) do
            respond(issues)
         end
      end)
   end)
   if not ok then
      local callbacks = pending_issues[repo]
      pending_issues[repo] = nil
      for _, respond in ipairs(callbacks) do
         respond({})
      end
   end
end

local function complete(params, handler)
   local context = completion_context(params)
   if not context or not context.repo then
      handler(nil, {})
      return
   end

   load_issues(context.repo, function(issues)
      handler(nil, completion_items(issues, context))
   end)
end

return {
   name = "guh_ls",
   cmd = function()
      local closing = false
      return {
         request = function(method, params, handler)
            if method == ms.initialize then
               handler(nil, {
                  capabilities = {
                     textDocumentSync = { openClose = true, change = 0 },
                     codeActionProvider = { resolveProvider = false },
                     completionProvider = { triggerCharacters = { "#" }, resolveProvider = false },
                  },
                  serverInfo = { name = "guh_ls", version = "0.1.0" },
               })
            elseif method == ms.textDocument_codeAction then
               local bufnr = buffer_for_uri(params.textDocument.uri)
               handler(nil, bufnr and code_actions(bufnr) or {})
            elseif method == ms.textDocument_completion then
               complete(params, handler)
            else
               handler(nil, nil)
            end
            return true
         end,
         notify = function(method)
            if method == ms.exit then
               closing = true
            end
            return true
         end,
         is_closing = function()
            return closing
         end,
         terminate = function()
            closing = true
         end,
      }
   end,
   commands = {
      [agentic_command] = function(command, context)
         local bufnr = (command.arguments or {})[1] or context.bufnr
         if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
            return
         end

         local feat = (vim.b[bufnr].guh or {}).feat
         if feat ~= "issue" and feat ~= "pr" then
            return
         end

         vim.api.nvim_buf_call(bufnr, function()
            vim.cmd.normal({ bang = true, args = { "ggVG" } })
            require("agentic").add_selection()
         end)
      end,
      [action_command] = function(command, context)
         local key, mode = unpack(command.arguments or {})
         local bufnr = context.bufnr
         local action = action_by_key[key]
         if not action or (action.mode or "n") ~= mode or not vim.api.nvim_buf_is_valid(bufnr) then
            return
         end

         local name = vim.api.nvim_buf_get_name(bufnr)
         if not vim.startswith(name, "guh://") then
            return
         end

         vim.api.nvim_buf_call(bufnr, function()
            if mode == "x" then
               vim.cmd.normal({ bang = true, args = { "gv" } })
            end
            local keys = vim.api.nvim_replace_termcodes(key, true, false, true)
            vim.api.nvim_feedkeys(keys, "mx", false)
         end)
      end,
   },
}
