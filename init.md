## dmtrKovalenko/fff.nvim

- build: `cargo build --release`

```lua
require("fff").setup({})
```

# vim

## folke/which-key.nvim

- config: true

## tommcdo/vim-lion

- `glip=`
- `3gLi(,`

# APPs

## neet-007/rfc-view.nvim

- build: `cd go && build main.go`

```lua
local rfcview = require("rfcview")
rfcview.setup({})

vim.keymap.set("n", "<leader>ro", rfcview.open_rfc)
vim.keymap.set("n", "<leader>rc", rfcview.close_rfc)
```

## pwntester/octo.nvim

- config: true

# ibhagwan/fzf-lua

# nvim-telescope/telescope.nvim

# monaqa/dial.nvim

```lua
require("_dial")
```

# saghen/blink.cmp

- version: `1.*`

```lua
require("_blink")
```

# catppuccin/nvim

```lua
vim.cmd("colorscheme catppuccin-mocha")
```

# nvim-lua/plenary.nvim

# NeogitOrg/neogit

- keys: `<leader>gg`
- cmd: `Neogit`

```lua
require("neogit").setup({})
vim.keymap.set("n", "<leader>gg", "<cmd>Neogit<cr>")
```

# lewis6991/gitsigns.nvim

```lua
require("gitsigns").setup({
   signs = {
      add = { text = "▎" },
      change = { text = "▎" },
      delete = { text = "" },
      topdelete = { text = "" },
      changedelete = { text = "▎" },
      untracked = { text = "▎" },
   },
   signs_staged = {
      add = { text = "▎" },
      change = { text = "▎" },
      delete = { text = "" },
      topdelete = { text = "" },
      changedelete = { text = "▎" },
   },
   on_attach = function(buffer)
      local gs = package.loaded.gitsigns

      local function map(mode, l, r, desc)
         vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
      end

    -- stylua: ignore start
    map("n", "]c", function()
      if vim.wo.diff then
        vim.cmd.normal({ "]h", bang = true })
      else
        gs.nav_hunk("next")
      end
    end, "Next Hunk")
    map("n", "[c", function()
      if vim.wo.diff then
        vim.cmd.normal({ "[h", bang = true })
      else
        gs.nav_hunk("prev")
      end
    end, "Prev Hunk")
    map({ "n", "v" }, "<leader>ghs", ":Gitsigns stage_hunk<CR>", "Stage Hunk")
    map({ "n", "v" }, "<leader>ghr", ":Gitsigns reset_hunk<CR>", "Reset Hunk")
    map("n", "<leader>ghS", gs.stage_buffer, "Stage Buffer")
    map("n", "<leader>ghu", gs.undo_stage_hunk, "Undo Stage Hunk")
    map("n", "<leader>ghR", gs.reset_buffer, "Reset Buffer")
    map("n", "<leader>ghp", gs.preview_hunk_inline, "Preview Hunk Inline")
    map("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, "Blame Line")
    map("n", "<leader>ghB", function() gs.blame() end, "Blame Buffer")
    map("n", "<leader>ghd", gs.diffthis, "Diff This")
    map("n", "<leader>ghD", function() gs.diffthis("~") end, "Diff This ~")
    map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "GitSigns Select Hunk")
   end,
})
```

# folke/snacks.nvim

```lua
require("snacks").setup({
   scroll = { enabled = true },
   image = {
      enabled = true,
      resolve = function(path, src)
         if require("obsidian.api").path_is_note(path) then
            return require("obsidian.api").resolve_image_path(src)
         end
      end,
      wo = {
         winhighlight = "FloatBorder:WhichKeyBorder",
      },
      doc = {
         inline = false,
         max_width = 45,
         max_height = 20,
      },
   },
   -- bigfile = { enabled = true },
   input = { enabled = true },
   picker = {
      enabled = true,
   },
   statuscolumn = { enabled = true },
   styles = {
      notification = {
         wo = { wrap = true },
      },
      snacks_image = {
         relative = "editor",
         col = -1,
      },
   },
   notifier = {
      enabled = true,
      timeout = 3000,
   },
   scope = { enabled = true },
})
```

# stevearc/oil.nvim

```lua
require("oil").setup({
   delete_to_trash = true,
   view_options = {
      show_hidden = true,
   },
})
vim.keymap.set("n", "-", "<cmd>Oil<cr>")
```

# stevearc/conform.nvim

```lua
require("conform").setup({
   format_on_save = {
      timeout_ms = 500,
      lsp_format = "fallback",
   },
   formatters_by_ft = {
      c = { "astyle" },
      nix = { "nixfmt" },
      lua = { "stylua" },
      markdown = { "prettier", "injected" },
      html = { "prettier" },
      javascript = { "prettier" },
      typescript = { "prettier" },
      json = { "jq" },
   },
})
```

# UI

## sj2tpgk/nvim-eldoc

```lua
require("nvim-eldoc").setup({})
```

## nvim-treesitter/nvim-treesitter

- version: `main`

```lua
local nts = require("nvim-treesitter")
nts.install({
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
})
```

## nvim-treesitter/nvim-treesitter-context

```lua
require("treesitter-context").setup({})
```

## echasnovski/mini.icons

```lua
require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons()
```

## rasulomaroff/reactive.nvim

```lua
require("reactive").setup({
   builtin = {
      cursorline = true,
      cursor = true,
      modemsg = true,
   },
})
```

# Markdown

## MeanderingProgrammer/render-markdown.nvim

```lua
require("render-markdown").setup({
   -- heading = {
   --    enabled = false,
   -- },
   checkbox = {
      custom = {
         right_arrow = {
            raw = "[>]",
            rendered = " ",
            highlight = "ObsidianRightArrow",
         },
         tilde = { raw = "[~]", rendered = "󰰱 ", highlight = "ObsidianTilde" },
         important = { raw = "[!]", rendered = " ", highlight = "ObsidianImportant" },
      },
   },
})
```

## bullets-vim/bullets.vim

## jmbuhr/otter.nvim

```lua
require("otter").setup({})
```

# Utilities

## echasnovski/mini.test

```lua
require("mini.test").setup({})
```

## echasnovski/mini.surround

```lua
require("mini.surround").setup({})
```

## folke/lazydev.nvim

```lua
require("lazydev").setup({
   library = {
      { path = "${3rd}/luv/library", words = { "vim%.uv" } },
   },
})
```

## andrewferrier/debugprint.nvim

- `g?p`/`g?P`
- `Debugprint qflist`

```lua
require("debugprint").setup({})
```

# LSP

## smjonas/inc-rename.nvim

```lua
require("inc_rename").setup({})
```

# Fun

## davidgranstrom/scnvim

```lua
require("scnvim").setup({
   sclang = {
      cmd = "/mnt/d/install/sclang.exe",
   },
})
```
