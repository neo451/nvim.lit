local M = {}

-- TODO: lock commit if not finished pulling
-- local check if in git repo
-- if theres things in staging area, commit them on vim exist
-- if delete, stage that?
-- add progress spinner
--
-- obsidian-git
-- 🔄 Changes
--     List changed files: Lists all changes in a modal
--     Open diff view: Open diff view for the current file
--     Stage current file
--     Unstage current file
--     Discard all changes: Discard all changes in the repository
-- ✅ Commit
--     Commit: If files are staged only commits those, otherwise commits only files that have been staged
--     Commit with specific message: Same as above, but with a custom message
--     Commit all changes: Commits all changes without pushing
--     Commit all changes with specific message: Same as above, but with a custom message
-- 🔀 Commit-and-sync
--     Commit-and-sync: With default settings, this will commit all changes, pull, and push
--     Commit-and-sync with specific message: Same as above, but with a custom message
--     Commit-and-sync and close: Same as Commit-and-sync, but if running on desktop, will close the Obsidian window. Will not exit Obsidian app on mobile.
-- 🌐 Remote
--     Push, Pull
--     Edit remotes: Add new remotes or edit existing remotes
--     Remove remote
--     Clone an existing remote repo: Opens dialog that will prompt for URL and authentication to clone a remote repo
--     Open file on GitHub: Open the file view of the current file on GitHub in a browser window. Note: only works on desktop
--     Open file history on GitHub: Open the file history of the current file on GitHub in a browser window. Note: only works on desktop
-- 🏠 Manage local repository
--     Initialize a new repo
--     Create new branch
--     Delete branch
--     CAUTION: Delete repository
-- 🧪 Miscellaneous
--     Open source control view: Opens side pane displaying Source control view
--     Open history view: Opens side pane displaying History view
--     Edit .gitignore
--     Add file to .gitignore: Add current file to .gitignore

local mes = {
   push = { ok = "pushed ", err = "failed to push" },
   pull = { ok = "pulled ", err = "failed to pull" },
   add = { ok = "added ", err = "failed to add" },
   commit = { ok = "commited ", err = "failed to commit" },
}

--- runs a git cmd in the current vault root
---@param cmds string[]
---@param callback? fun(obj: vim.SystemCompleted)
function M.run(cmds, callback)
   local cmd = cmds[2]

   -- TODO: signify start operation
   -- vim.notify(msgs.ok, vim.log.levels.INFO, { title = "Obsidian" })
   vim.system(
      cmds,
      { cwd = tostring(Obsidian.dir) },
      vim.schedule_wrap(function(obj)
         local msgs = mes[cmd]
         if obj.code == 0 then
            vim.notify(msgs.ok, vim.log.levels.INFO, { title = "Obsidian" })
         else
            vim.notify(msgs.err, vim.log.levels.ERROR, { title = "Obsidian" })
            print(obj.stderr)
         end
         if callback then
            callback(obj)
         end
      end)
   )
end

local opts

opts = {
   message = function()
      return os.date("%Y-%m-%d %H:%M:%S")
   end,

   stage_tracked = function()
      M.run({ "git", "add", "-u" })
   end,

   pull = function(ev)
      M.run({ "git", "pull" }, function()
         if not ev then
            return
         end
         local file = ev.data.note.path.filename
         -- TODO: infinately pulling here...
         if not vim.b[ev.buf].pulled_once then
            vim.cmd.e(file)
            vim.b[ev.buf].pulled_once = true
         end
      end)
   end,

   add = function(ev)
      local file = ev.data.note.path.filename
      M.run({ "git", "add", file })
   end,

   commit = function()
      local msg = opts.message()
      M.run({ "git", "commit", "-m", msg })
   end,

   push = function()
      M.run({ "git", "push" })
   end,
}

local group_id = vim.api.nvim_create_augroup("obsidian-git", { clear = true })

local setup_autocmd = function(pattern, callbacks)
   local callback

   if type(callbacks) == "table" then
      callback = function(ev)
         for _, cb in ipairs(callbacks) do
            cb(ev)
         end
      end
   else
      callback = callbacks
   end

   vim.api.nvim_create_autocmd("User", {
      pattern = pattern,
      callback = callback,
      group = group_id,
   })
end

function M.setup(user_opts)
   opts = vim.tbl_extend("keep", user_opts, opts)
   if opts.pull_on_startup then
      opts.stage_tracked()
      opts.pull()
   end

   -- setup_autocmd("ObsidianNoteEnter", opts.pull)
   -- setup_autocmd("ObsidianNoteWritePost", { opts.add, opts.commit, opts.push })
end

return M
