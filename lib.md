## neovim/nvim-lspconfig

## hrsh7th/cmp-nvim-lsp

## hrsh7th/nvim-cmp

```lua
if true then
   return
end
local cmp = require("cmp")
cmp.setup({
   completion = {
      completeopt = "menu,menuone,noinsert",
   },
   mapping = cmp.mapping.preset.insert({
      ["<C-n>"] = cmp.mapping.select_next_item(),
      ["<C-p>"] = cmp.mapping.select_prev_item(),
      ["<C-b>"] = cmp.mapping.scroll_docs(-4),
      ["<C-f>"] = cmp.mapping.scroll_docs(4),
      ["<C-x>"] = cmp.mapping.complete({}),
      ["<Tab>"] = cmp.mapping.confirm({
         behavior = cmp.ConfirmBehavior.Insert,
         select = true,
      }),
   }),
   sources = {
      { name = "nvim_lsp" },
   },

   performance = {
      max_view_entries = 7,
   },
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
   -- "markdown",
   -- "markdown_inline",
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
