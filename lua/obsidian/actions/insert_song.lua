local function insert_song_highlight()
   require("obsidian.media-db.actions").search_by_media_type({
      types = { "music_track" },
      on_select = function(model)
         vim.api.nvim_put({ ("> %s - %s (%s)"):format(model.artists[1], model.title, model.year) }, "c", true, false)
         -- vim.print(model)
      end,
   })
end

local function insert_song_link()
   require("obsidian.media-db.actions").search_by_media_type({
      types = { "music_track" },
      apis = { "Spotify" },
      on_select = function(model)
         vim.api.nvim_put(
            { ("[%s - %s (%s)](%s)"):format(table.concat(model.artists, ","), model.title, model.year, model.url) },
            "c",
            true,
            false
         )
      end,
   })
end

require("obsidian").code_action.add({
   name = "insert_song",
   title = "Insert Song",
   fn = insert_song_highlight,
})

return {
   insert_song_hl = insert_song_highlight,
   insert_song_link = insert_song_link,
}
