---
id: nvim_archived
tags: []
---

## aikhe/wrapped.nvim

```lua
require("wrapped").setup({})
```

## nvim-orgmode/orgmode

```lua
-- Setup orgmode
require("orgmode").setup({
   org_agenda_files = "~/orgfiles/**/*",
   org_default_notes_file = "~/orgfiles/refile.org",
})

-- Experimental LSP support
vim.lsp.enable("org")
```

### OXY2DEV/markview.nvim

### mrcjkb/haskell-tools.nvim

### samjwill/nvim-unception

- cmd: `GistCreate`

```lua
vim.g.unception_block_while_host_edits = true
```

### Rawnly/gist.nvim

- cmd: `GistCreate`

<!-- ### jbuck95/recollect.nvim! -->

### catppuccin/nvim

```lua
vim.cmd.colorscheme("catppuccin-mocha")
```

## neotest

### antoinemadec/FixCursorHold.nvim

- event: `BufReadPre spec/*.lua`

### nvim-neotest/nvim-nio

- event: `BufReadPre spec/*.lua`

### MisanthropicBit/neotest-busted

- event: `BufReadPre spec/*.lua`

### nvim-neotest/neotest

- event: `BufReadPre spec/*.lua`

```lua
require("neotest").setup({
   adapters = {
      require("neotest-busted")({ busted_command = "busted", no_nvim = true }),
   },
})
```

## Fun

### davidgranstrom/scnvim

- ft: `supercollider`

```lua
local scnvim = require("scnvim")
local map = scnvim.map
local map_expr = scnvim.map_expr
require("scnvim").setup({
   keymaps = {
      ["<C-l>"] = map("editor.send_line", { "i", "n" }),
      ["<C-e>"] = {
         map("editor.send_block", { "i", "n" }),
         map("editor.send_selection", "x"),
      },
      ["<CR>"] = map("postwin.toggle"),
      ["<M-CR>"] = map("postwin.toggle", "i"),
      ["<M-L>"] = map("postwin.clear", { "n", "i" }),
      ["<C-k>"] = map("signature.show", { "n", "i" }),
      ["<C-.>"] = map("sclang.hard_stop", { "n", "x", "i" }),
      ["<leader>st"] = map("sclang.start"),
      ["<leader>sk"] = map("sclang.recompile"),
      ["<F1>"] = map_expr("s.boot"),
      ["<F2>"] = map_expr("s.meter"),
   },
   editor = {
      highlight = {
         color = "IncSearch",
      },
   },
   postwin = {
      float = {
         enabled = true,
      },
   },
})

vim.api.nvim_create_autocmd("BufEnter", {
   pattern = "*.scd",
   callback = function()
      vim.cmd("SCNvimStart")
   end,
})
```

### nvim-orgmode/orgmode

- ft: `org`
- cmd: `Org`

```lua
require("orgmode").setup({
   org_agenda_files = "~/orgfiles/**/*",
   org_default_notes_file = "~/orgfiles/refile.org",
})
```

### chrisbra/Recover.vim

### stevearc/overseer.nvim

- cmd: `OverseerRun`

```lua
require("overseer").setup({})
```

### folke/trouble.nvim!

### tommcdo/vim-lion

- `glip=` -> `gl`(operator) + `ip`(textobj) + `=`(seperator)
- `3gLi(,` -> `3`(num_sperator) + `gL`(operator-right) `i(`(textobj) + `,`(seperator)

### L3MON4D3/LuaSnip

```lua
local ls = require("luasnip")

ls.config.set_config({
   history = true, -- keep around last snippet local to jump back
   enable_autosnippets = true,
})
require("luasnip.loaders.from_vscode").lazy_load({ paths = "~/.config/nvim/snippets" })
```

### tamerlang/gh-actions-lsp.nvim!

### copilotlsp-nvim/copilot-lsp

```lua
vim.g.copilot_nes_debounce = 500
vim.lsp.enable("copilot_ls")
vim.keymap.set("n", "<tab>", function()
   local bufnr = vim.api.nvim_get_current_buf()
   local state = vim.b[bufnr].nes_state
   if state then
      -- Try to jump to the start of the suggestion edit.
      -- If already at the start, then apply the pending suggestion and jump to the end of the edit.
      local _ = require("copilot-lsp.nes").walk_cursor_start_edit()
         or (require("copilot-lsp.nes").apply_pending_nes() and require("copilot-lsp.nes").walk_cursor_end_edit())
      return nil
   else
      -- Resolving the terminal's inability to distinguish between `TAB` and `<C-i>` in normal mode
      return "<C-i>"
   end
end)

-- Clear copilot suggestion with Esc if visible, otherwise preserve default Esc behavior
vim.keymap.set("n", "<esc>", function()
   if not require("copilot-lsp.nes").clear() then
      -- fallback to other functionality
   end
end, { desc = "Clear Copilot suggestion or fallback" })
```

### EdenEast/nightfox.nvim

### pebeto/dookie.nvim

### catppuccin/nvim

## Try later

### jmbuhr/otter.nvim

### asmodeus812/nvim-fuzzymatch

```lua
-- require("fuzzy").setup({})
```

### MeanderingProgrammer/render-markdown.nvim

- enabled: false

```lua
require("render-markdown").setup({
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

## AI

### ravitemer/mcphub.nvim

```lua
vim.g.mcphub = {
   -- Required options
   port = 3000, -- Port for MCP Hub server
   config = vim.fn.expand("~/.config/nvim/mcpservers.json"), -- Absolute path to config file

   use_bundled_binary = true, -- Use bundled mcp-hub binary

   -- Optional options
   on_ready = function(hub)
      -- Called when hub is ready
   end,
   on_error = function(err)
      -- Called on errors
   end,
   shutdown_delay = 0, -- Wait 0ms before shutting down server after last client exits
   log = {
      level = vim.log.levels.WARN,
      to_file = false,
      file_path = nil,
      prefix = "MCPHub",
   },
}
```

### olimorris/codecompanion.nvim

### moyiz/blink-emoji.nvim

### archie-judd/blink-cmp-words

### ColinKennedy/mega.cmdparse

### ColinKennedy/mega.logging

### fvalenza/vaultview.nvim

```lua
vim.g.vaultview_configuration = {
   vault = {
      path = "~/Vaults/1 Notes/",
      name = "1 Notes", -- name of the Vault as seen by Obsidian. Used to build uri path for Obsidian
   },
   display_tabs_hint = true, -- whether to display hint about board navigation in the UI
   boards = {
      {
         name = "dailyBoard", -- name of the board as printed in the top of UI
         parser = "daily", -- parser used to retrieve information to display in the view -> currently supported parsers: "daily", "moc"
         viewlayout = "carousel", -- how information is displayed in the view -> currently supported layouts: "carousel", "columns"
         input_selector = "yyyy-mm-dd.md", -- rule to select files to be included in the board. Can be a built-in selector or a user-defined one
         subfolder = "dailynotes", -- optional subfolder inside vault to limit the scope of the input files
         content_selector = "h2", -- rule to select content inside each file to be displayed in the view. Can be a built-in selector or a user-defined one
      },
   },
   initial_board_idx = 1, -- index of the board to be displayed when opening the vaultview. Optional.
}
```

### zenarvus/md-agenda.nvim

```lua
require("md-agenda").setup({
   agendaFiles = {
      "~/Documents/Notes/agenda.md",
      -- "~/notes/habits.md", -- Single Files
      -- "~/notes/agendafiles/", -- Folders
   },
})
```

### Kamyil/markdown-agenda.nvim

<!-- TODO -->

### dhruvasagar/vim-table-mode

- ft: `markdown`
