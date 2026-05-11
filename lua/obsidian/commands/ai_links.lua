-- Ask agent to suggest wiki-link candidates for current paragraph / selection / buffer.
-- Pick via vim.ui.select, insert as [[Name]] at cursor.
-- lua/obsidian/ai.lua — core:
-- - ai.context.{paragraph, buffer, selection, position} — context builders
-- - ai.run({ prompt, flags, dir }, cb) — dispatch to _opencode
-- - ai.parse_list(stdout) — JSON array or bullet-line fallback
--
-- lua/obsidian/commands/ai_links.lua — use case. Grabs selection→paragraph→buffer, runs agent in
-- vault dir w/ prompt instructing filename scan, vim.ui.select shows options, pick inserts
-- [[Name]] at cursor. Arg = max count (default 8).
--
-- Registered as :Obsidian ai_links [N].
--
-- Plain-text flow (e.g. rewrite paragraph): ai.run(..., function(stdout) replace_lines(s, e,
-- stdout) end) — same primitives, different callback. Add as new command when needed.
--
-- <https://www.reddit.com/r/ObsidianMD/comments/1ste620/day_2_of_obsidian_built_a_contextaware_link/>
local ai = require("obsidian.ai")
local log = require("obsidian.log")

local PROMPT = [[
You are helping build Obsidian wiki-links.

Vault dir: %s

Text:
---
%s
---

Task: scan the vault (ls recursively, ignore .git, .obsidian, .trash) to
find note filenames (without .md) that are topically relevant to the text.
Return ONLY a JSON array of up to %d filename strings, no prose, no code fence.
Example: ["Note A", "Folder/Note B"]
]]

local function get_text()
   local v = ai.context.selection()
   if v then
      return v, "selection"
   end
   local para = ai.context.paragraph()
   if para and para ~= "" then
      return para, "paragraph"
   end
   return ai.context.buffer(), "buffer"
end

return function(data)
   local limit = tonumber(data and data.args) or 8
   local text, scope = get_text()
   local vault = tostring(Obsidian.dir)
   local prompt = PROMPT:format(vault, text, limit)

   log.info("ai_links: querying agent for %s ...", scope)

   ai.run({ prompt = prompt, dir = vault, flags = { model = "opencode/grok-code" } }, function(stdout)
      local items = ai.parse_list(stdout)
      if vim.tbl_isempty(items) then
         log.warn("ai_links: no suggestions")
         return
      end
      vim.ui.select(items, { prompt = "Insert link:" }, function(choice)
         if not choice then
            return
         end
         local link = "[[" .. choice .. "]]"
         vim.api.nvim_put({ link }, "c", true, true)
      end)
   end)
end
