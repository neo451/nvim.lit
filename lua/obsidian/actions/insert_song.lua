-- TODO: song source

require("obsidian").code_action.add({
   name = "insert_song",
   title = "Insert Song",
   fn = function()
      require("obsidian.media-db.actions").search_by_media_type({
         types = { "music_track" },
         on_select = function(model)
            vim.api.nvim_put({ ("> %s - %s (%s)"):format(model.artists[1], model.title, model.year) }, "c", true, false)
            -- vim.print(model)
         end,
      })
   end,
})
