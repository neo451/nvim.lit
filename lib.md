---
id: lib
tags: []
---

## gregorias/coop.nvim

- lazy: `true`

## nvim-lua/plenary.nvim

- lazy: `true`

## nvim-telescope/telescope.nvim

- lazy: `true`

## ibhagwan/fzf-lua

- lazy: `true`

## MunifTanjim/nui.nvim

- lazy: `true`

## nvim-treesitter/nvim-treesitter

- version: `main`

```lua
local nts = require("nvim-treesitter")
nts.install({
   "bash",
   "nix",
   "go",
   "xml",
   "yaml",
   "markdown",
   "markdown_inline",
   "rust",
   "zig",
   "bash",
   "fish",
   "gitcommit",
   "diff",
   "sql",
   "html",
   "css",
   "python",
   "toml",
   "elixir",
   "qmljs",
   "javascript",
   "supercollider",
})
```
