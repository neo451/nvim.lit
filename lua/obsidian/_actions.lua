local obsidian = require("obsidian")

local function delete_to_trash()
   local note = obsidian.api.current_note()
   if not note or not note.path then
      return
   end
   local note_path = tostring(note.path) -- from path object to string
   local dest_path_obj = Obsidian.workspace.root / ".trash"

   if not dest_path_obj:is_dir() then
      dest_path_obj:mk_dir()
   end

   local out = vim.system({ "mv", note_path, tostring(dest_path_obj) }):wait() -- make this a sync operation

   if out.code ~= 0 then
      vim.notify("Failed to delete to .trash")
   else
      vim.notify("File deleted to .trash")
   end
end

local function move_note_to_folder()
   local root = tostring(Obsidian.workspace.root)
   local choices = { {
      filename = root,
      text = "/",
   } }

   -- TODO: nested
   for path, t in vim.fs.dir(root, {}) do
      if t == "directory" then
         choices[#choices + 1] = {
            filename = vim.fs.joinpath(root, path),
            text = path,
         }
      end
   end

   Obsidian.picker.pick(choices, { callback = print })
end

pcall(function()
   obsidian.code_action.add({
      name = "delete_to_trash",
      title = "Delete note to trash folder",
      fn = delete_to_trash,
   })

   obsidian.code_action.add({
      name = "move_to_folder",
      title = "Move note to another folder",
      fn = move_note_to_folder,
   })
   -- obsidian.code_action.del("rename")
   -- obsidian.code_action.del("add_property")
   --
   require("obsidian").code_action.add({
      name = "insert tag",
      title = "Insert an existing tag",
      fn = require("obsidian.actions").insert_tag,
   })
end)
