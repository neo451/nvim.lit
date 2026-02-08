local obsidian = require("obsidian")
local log = obsidian.log

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
      log.err("Failed to delete to .trash")
   else
      log.err("File deleted to .trash")
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

local function new_spinner(bufnr, row, col)
   local id = string.format("extmark-spinner-%d-%d-%d", bufnr, row, col)
   require("spinner").config(id, {
      kind = "extmark",
      bufnr = bufnr, -- must be provided
      row = row, -- must be provided, which line, 0-based
      col = col, -- must be provided, which col, 0-based

      ns = vim.api.nvim_create_namespace("ext-spinner"), -- namespace, optional
      hl_group = "Spinner", -- hl_group for text, optional
   })
   return id
end

local function extract_text()
   local spinner = require("spinner")

   -- TODO: after link parsing recognize embeds, check if is image
   local link = obsidian.api.cursor_link()
   if not link then
      log.err("Not on a link")
      return
   end
   local locaction = obsidian.util.parse_link(link)
   local path = obsidian.api.resolve_attachment_path(locaction)
   if not path then
      return
   end
   -- you can call any ai tool here
   local cmds = { "ollama", "run", "qwen3-vl:2b", path, "extract_text", "--hidethinking" }
   -- local cmds = { "tesseract", path, "stdout", "-l", "chi_sim" }

   local row, col = unpack(vim.api.nvim_win_get_cursor(0))
   row = row - 1 -- 0-based
   local id = new_spinner(vim.api.nvim_get_current_buf(), row, col)
   spinner.start(id)

   vim.system(
      cmds,
      {},
      vim.schedule_wrap(function(out)
         if out.code ~= 0 then
            log.err("Failed to extract text:", out.stderr)
            return
         end
         spinner.stop(id)
         vim.fn.setreg('"', out.stdout)
         log.info('text extracted to register "')
      end)
   )
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

   require("obsidian").code_action.add({
      name = "insert_tag",
      title = "Insert an existing tag",
      fn = require("obsidian.actions").insert_tag,
   })

   require("obsidian").code_action.add({
      name = "extract_text_from_image",
      title = "Extract text from image",
      fn = extract_text,
   })
end)

return {
   extract_text = extract_text,
}
