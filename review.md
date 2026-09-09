## 🟠 Security — committed secrets

Move to env vars / a non-git file, and **rotate** these:

- `lua/_feed.lua:146` — tt-rss password `"123"`
- `lua/_feed.lua:151` — FreshRSS password `"6295141.3"`
- `lua/_feed.lua:152` — FreshRSS auth token
- `lua/_obsidian_media_db.lua:12` — Google Books API key
- `lua/_obsidian_media_db.lua:5` — OMDB key

## 🟡 Dead code

| File                              | Status                                             |
| --------------------------------- | -------------------------------------------------- |
| `lua/ARCHIVE.lua`                 | not `require`d (and broken if loaded — see bug #6) |
| `lua/spotify.lua`                 | not `require`d                                     |
| `lua/_feed.lua` + `lua/feeds.lua` | `require("_feed")` commented out in `init.lua`     |
| `lua/obsidian/_agenda.lua`        | all content commented out; not required            |
| `lua/obsidian/calendar_date.lua`  | only a commented reference in `_obsidian.lua`      |
| `lsp/dummy_ls.lua`                | config exists, name commented out in `servers`     |
| `lsp/harper_ls.lua`               | config exists, name commented out in `servers`     |
| `lsp/markdown-oxide.lua`          | config exists, name commented out in `servers`     |
| `lsp/marksman.lua`                | config exists, name commented out in `servers`     |

## 🟢 Architecture / correctness notes

### `lua/_blink.lua` internal API

`transform_items` uses `require("blink.cmp.types")` — internal, unstable.

## 💡 Improvement notes (not yet actioned)

- `lua/pangu.lua` — hand-rolled UTF-8 decoder could be replaced with
  `vim.fn.strcharpart`/`utf8` helpers, but it works as-is.
