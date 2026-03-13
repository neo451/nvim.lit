---
id: lib
tags: []
---

## neovim/nvim-lspconfig

## hrsh7th/nvim-cmp

```lua
-- if true then
--    return
-- end
local cmp = require("cmp")
cmp.setup({
   mapping = cmp.mapping.preset.insert({
      ["<C-e>"] = cmp.mapping.abort(),
      ["<C-y>"] = cmp.mapping.confirm({ select = true }),
   }),
})
```

## nvzone/volt

- lazy: `true`

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
   "lua",
   "luadoc",
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
