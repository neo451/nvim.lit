local mediaDB = require("obsidian.media-db")

mediaDB.setup({
   apis = {
      omdb = { key = "debaf6f7" },
      -- giant_bomb = { key = "0d3deb61eeed923a919def933ceeb4d168fa3f64" },
      spotify = {
         id = os.getenv("SPOTIFY_CLIENT_ID"),
         secret = os.getenv("SPOTIFY_CLIENT_SECRET"),
      },
      open_library = { enabled = false },
      google_books = { key = "AIzaSyBiJEfKGhJ8PMrb2lSrFMSNgYUbvqZdBaM" },
   },
   media_types = {
      movie = {
         field_mappings = {
            director = { format = "[[%s]]" },
            actors = { format = "[[%s]]" },
         },
      },
      music = {
         field_mappings = {
            artists = { format = "[[%s]]" },
         },
         template = "music.md",
      },
   },
})

mediaDB.register_action("rym", function(model, _ctx)
   local title = model.title or ""
   local artist = (model.artists and model.artists[1]) or ""
   local q = vim.uri_encode(title .. " " .. artist)
   vim.ui.open("https://rateyourmusic.com/search?searchterm=" .. q)
end)

vim.keymap.set("n", "<leader>ry", function()
   mediaDB.run_action("rym", { selecter = "type" })
end)
