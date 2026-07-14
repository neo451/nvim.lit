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
      -- listennotes = { key = "3c4135a0486e48acab4fb5afdb5df944" },
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
