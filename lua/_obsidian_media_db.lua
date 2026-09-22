local mediaDB = require("obsidian.media-db")
local secrets = require("secrets")

mediaDB.setup({
   apis = {
      omdb = { key = "debaf6f7" },
      spotify = {
         id = os.getenv("SPOTIFY_CLIENT_ID"),
         secret = os.getenv("SPOTIFY_CLIENT_SECRET"),
      },
      open_library = { enabled = false },
      google_books = { key = secrets.get("google_books") },
      -- listennotes = { key = "3c4135a0486e48acab4fb5afdb5df944" },
      -- giant_bomb = { key = "0d3deb61eeed923a919def933ceeb4d168fa3f64" },
   },
   media_types = {
      music = {
         template = "music-media-db.md",
      },
   },
})
