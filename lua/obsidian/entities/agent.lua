local api = require("obsidian.api")
local log = require("obsidian.log")
local util = require("obsidian.util")

local M = {}

local function vault_guard(vault, target)
   return table.concat({
      "You are editing an Obsidian vault.",
      "The vault root is: " .. vault,
      "Only read, write, edit, or create files inside this vault.",
      "Only modify this exact target note: " .. target,
      "Do not rename the note, modify other notes, or change configuration.",
   }, "\n")
end

local function prompt_for(kind, query, target)
   if kind == "person" then
      return table.concat({
         "Research the person named: " .. query,
         "Complete the target Obsidian note with concise, accurate information.",
         "Keep frontmatter minimal: type, image, and aliases only.",
         "The image frontmatter field is required: find a reasonably good portrait image URL, preferably from an official, institutional, agency, or reputable press source.",
         "Do not use a Wikipedia image unless no better source is available.",
         "If reliable aliases are available, add them; otherwise omit aliases rather than inventing them. Put the summary and source links in the body, not extra frontmatter. Preserve valid YAML and do not invent uncertain facts.",
         "The target note is: " .. target,
      }, "\n")
   end

   return table.concat({
      "Research the place named: " .. query,
      "Complete the target Obsidian note with concise, accurate information.",
      "Keep frontmatter limited to type, coordinates, and aliases.",
      "Add coordinates as a two-item coordinates array in [latitude, longitude] order, using quoted decimal strings. Do not add address or source fields.",
      "If reliable aliases are available, add them; otherwise omit aliases rather than inventing them. Put a short description and source links in the body when useful. Preserve valid YAML and do not invent uncertain facts.",
      "The target note is: " .. target,
   }, "\n")
end

---@param opts { kind: string, query: string, path: string, on_exit?: fun(ok: boolean, result: vim.SystemCompleted) }
function M.run(opts)
   local root = api.resolve_workspace_dir(opts.path)
   local vault = vim.fs.normalize(tostring(root))
   local target_path = vim.fs.normalize(opts.path)
   local target = assert(util.relpath(vault, target_path))

   local argv = {
      "pi",
      "--print",
      "--no-session",
      "--approve",
      "--thinking",
      "minimal",
      "--append-system-prompt",
      vault_guard(vault, target),
      "--name",
      "Obsidian entity: " .. opts.kind .. " " .. opts.query,
      "@" .. target,
      prompt_for(opts.kind, opts.query, target),
   }

   log.info("Starting Pi research for %s", target)
   vim.system(argv, { cwd = vault, text = true }, function(result)
      vim.schedule(function()
         if result.code == 0 then
            vim.cmd.checktime()
            log.info("Pi finished researching %s", target)
         else
            log.err("Pi entity research failed: %s", result.stderr or result.stdout or "unknown error")
         end
         if opts.on_exit then
            opts.on_exit(result.code == 0, result)
         end
      end)
   end)
end

return M
