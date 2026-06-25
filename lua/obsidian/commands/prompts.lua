local api = require("obsidian.api")
local log = require("obsidian.log")
local util = require("obsidian.util")

local M = {}

M.presets = {
   {
      id = "clean",
      label = "Clean up current note",
      prompt = table.concat({
         "Clean up the current note for clarity and structure.",
         "Preserve meaning. Improve headings, lists, wording, and Obsidian links where useful.",
      }, "\n"),
   },
   {
      id = "links",
      label = "Find and add related links",
      prompt = table.concat({
         "Find notes in this vault related to the current note.",
         "Add useful Obsidian links/backlinks and short context where it improves navigation.",
      }, "\n"),
   },
   {
      id = "expand",
      label = "Expand into structured note",
      prompt = table.concat({
         "Expand the current note into a more useful, structured note.",
         "Keep it concise, add missing sections, and preserve any source material or citations.",
      }, "\n"),
   },
   {
      id = "tasks",
      label = "Extract and organize tasks",
      prompt = table.concat({
         "Review the current note for action items.",
         "Create or update markdown task lists in the right place in this vault.",
      }, "\n"),
   },
   {
      id = "frontmatter",
      label = "Fix frontmatter, tags, aliases",
      prompt = table.concat({
         "Review and improve the current note's frontmatter, tags, and aliases.",
         "Keep existing metadata that is still useful and follow the vault's conventions.",
      }, "\n"),
   },
   {
      id = "custom",
      label = "Custom prompt...",
   },
}

local function trim(s)
   return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function find_preset(id)
   id = trim(id)
   if id == "" then
      return nil
   end

   for _, preset in ipairs(M.presets) do
      if preset.id == id or preset.label == id then
         return preset
      end
   end
end

local function current_context()
   local file = vim.api.nvim_buf_get_name(0)
   if file == "" then
      log.err("Current buffer has no file")
      return nil
   end

   file = vim.fs.normalize(file)
   local vault = vim.fs.normalize(tostring(api.resolve_workspace_dir(file)))
   if not util.is_subpath(file, vault) then
      log.err("Current file is not in the current Obsidian vault")
      return nil
   end

   if vim.bo.modified then
      vim.cmd.write()
   end

   return {
      file = file,
      vault = vault,
      relpath = assert(util.relpath(vault, file)),
   }
end

local function vault_guard_prompt(ctx)
   return table.concat({
      "Obsidian vault guard:",
      "- Your current working directory is the vault root: " .. ctx.vault,
      "- Only read, write, edit, create, delete, or run commands inside this vault.",
      "- Do not cd outside the vault or use absolute paths outside it.",
      "- If a task requires outside-vault access, stop and ask first.",
   }, "\n")
end

local function build_prompt(ctx, preset)
   return table.concat({
      "Current Obsidian file: " .. ctx.relpath,
      "You may inspect and edit other files in this vault if needed, but stay inside the vault.",
      "",
      assert(preset.prompt),
   }, "\n")
end

local function open_pi(ctx, preset)
   local argv = {
      "pi",
      "--append-system-prompt",
      vault_guard_prompt(ctx),
      "--name",
      "Obsidian: " .. preset.id .. " " .. vim.fs.basename(ctx.file),
      "@" .. ctx.relpath,
      build_prompt(ctx, preset),
   }

   vim.cmd("botright split")
   vim.cmd("resize 20")
   vim.cmd("enew")

   local job = vim.fn.jobstart(argv, {
      cwd = ctx.vault,
      term = true,
   })

   if job <= 0 then
      vim.cmd.close()
      log.err("Failed to start pi")
      return
   end

   vim.cmd.startinsert()
end

local function run_preset(preset)
   local ctx = current_context()
   if not ctx then
      return
   end

   if preset.id == "custom" then
      local prompt = api.input("Pi prompt", {})
      prompt = trim(prompt)
      if prompt == "" then
         log.info("Aborted")
         return
      end
      preset = {
         id = "custom",
         prompt = prompt,
      }
   end

   open_pi(ctx, preset)
end

function M.command(data)
   local arg = trim(data.args)
   if arg ~= "" then
      run_preset(find_preset(arg) or {
         id = "custom",
         prompt = arg,
      })
      return
   end

   vim.ui.select(M.presets, {
      prompt = "Pi prompt",
      format_item = function(item)
         return item.label
      end,
   }, function(item)
      if not item then
         log.info("Aborted")
         return
      end
      run_preset(item)
   end)
end

function M.complete(arg_lead)
   local completions = {}
   for _, preset in ipairs(M.presets) do
      if vim.startswith(preset.id, arg_lead) then
         completions[#completions + 1] = preset.id
      end
   end
   return completions
end

return setmetatable(M, {
   __call = function(_, data)
      return M.command(data)
   end,
})
