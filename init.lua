vim.loader.enable()

vim.pack.add({
   "https://github.com/MagicDuck/grug-far.nvim",
   "https://github.com/igorlfs/nvim-lsp-file-operations",

   "https://github.com/lumen-oss/lz.n",
   "https://github.com/folke/snacks.nvim",
   "https://github.com/rafamadriz/friendly-snippets",
   "https://github.com/archie-judd/blink-cmp-words",
   {
      src = "https://github.com/saghen/blink.cmp",
      version = vim.version.range("1.*"),
   },
   "https://github.com/nvim-mini/mini.nvim",
   "https://github.com/carlos-algms/agentic.nvim",
   "https://github.com/stevearc/quicker.nvim",
   "https://github.com/stevearc/oil.nvim",
   "https://github.com/folke/tokyonight.nvim",
   "https://github.com/edeneast/nightfox.nvim",
   "https://github.com/catppuccin/nvim",

   -- writing
   -- "https://github.com/MeanderingProgrammer/render-markdown.nvim",
   "https://github.com/techwizrd/render-latex.nvim",
   "https://github.com/OXY2DEV/markview.nvim",
   "https://github.com/YousefHadder/markdown-plus.nvim",
   "https://github.com/jmbuhr/otter.nvim",
   "https://github.com/quarto-dev/quarto-nvim",
   "https://github.com/jalvesaq/zotcite",

   -- language
   "https://github.com/atusy/budoux.lua",
   "https://github.com/Imngzx/jisho.nvim",

   --- db
   "https://github.com/kkharji/sqlite.lua",

   -- git
   "https://github.com/esmuellert/codediff.nvim",

   -- ui
   "https://github.com/shortcuts/no-neck-pain.nvim",
   "https://github.com/rachartier/tiny-code-action.nvim",

   -- treesitter
   {
      src = "https://github.com/nvim-treesitter/nvim-treesitter",
      version = "main",
   },

   -- lib
   "https://github.com/ibhagwan/fzf-lua",

   -- jj
   "https://github.com/NicholasZolton/neojj",

   -- lib
   "https://github.com/monok-robeto/nvim.sfx_player",
   "https://github.com/nvim-lua/plenary.nvim",
   "https://github.com/nvim-telescope/telescope.nvim",
}, { load = false })

-- jieba.nvim's plugin script installs global mappings. Expose only its Lua
-- modules (not its plugin directory); Markdown installs buffer-local mappings
-- in after/ftplugin/markdown.lua instead.
vim.pack.add({
   { src = "https://github.com/neo451/jieba.nvim", name = "jieba.nvim" },
}, {
   load = function(plugin)
      local path = vim.fs.joinpath(plugin.path, "lua")
      package.path = package.path .. ";" .. path .. "/?.lua;" .. path .. "/?/init.lua"
   end,
})

require("_mini")
require("_treesitter")
require("snacks").setup({
   -- picker = { enabled = true },
   notifier = { enabled = true, timeout = 3000 },
   input = { enabled = true },
   statuscolumn = { enabled = true },
})

require("lz.n").load({
   {
      "obsidian.nvim",
      ft = "markdown",
      cmd = "Obsidian",
      after = function()
         require("_obsidian")
      end,
   },
   {
      "tiny-code-action.nvim",
      after = function()
         require("tiny-code-action").setup({
            picker = "snacks",
         })
      end,
   },
   {
      "agentic.nvim",
      filetypes = { "lua", "markdown" },
      after = function()
         ---@diagnostic disable-next-line: param-type-mismatch, missing-fields
         require("agentic").setup({ provider = "pi-acp" })
      end,
      keys = {
         {
            "<C-\\>",
            function()
               require("agentic").toggle()
            end,
            mode = { "n", "v", "i" },
            desc = "Toggle Agentic Chat",
         },
         {
            "<C-'>",
            function()
               require("agentic").add_selection_or_file_to_context()
            end,
            mode = { "n", "v" },
            desc = "Add file or selection to Agentic to Context",
         },
         {
            "<A-i>r", -- ai Restore
            function()
               require("agentic").restore_session()
            end,
            desc = "Agentic Restore session",
            silent = true,
            mode = { "n", "v", "i" },
         },
         {
            "<leader>ad", -- ai Diagnostics

            function()
               require("agentic").add_current_line_diagnostics()
            end,
            desc = "Add current line diagnostic to Agentic",
            mode = { "n" },
         },
         {
            "<leader>aD", -- ai all Diagnostics
            function()
               require("agentic").add_buffer_diagnostics()
            end,
            desc = "Add all buffer diagnostics to Agentic",
            mode = { "n" },
         },
      },
   },
   {
      "blink.cmp",
      event = "InsertEnter",
      after = function()
         require("_blink")
      end,
   },
   {
      "jisho.nvim",
      after = function()
         require("jisho").setup({})
      end,
   },
   {
      "quicker.nvim",
      ft = "qf",
      after = function()
         require("quicker").setup({
            keys = {
               {
                  ">",
                  function()
                     require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
                  end,
                  desc = "Expand quickfix context",
               },
               {
                  "<",
                  function()
                     require("quicker").collapse()
                  end,
                  desc = "Collapse quickfix context",
               },
            },
         })
      end,
   },
   {
      "oil.nvim",
      after = function()
         require("oil").setup({
            skip_confirm_for_simple_edits = true,
            win_options = {
               signcolumn = "yes:2",
            },
            view_options = {
               show_hidden = true,
            },
         })
         vim.keymap.set("n", "-", "<cmd>Oil<cr>")

         vim.keymap.set("n", "_", function()
            local dir = tostring(Obsidian.workspace.root):gsub(" ", "\\ ")
            return "<cmd>Oil " .. dir .. "<cr>"
         end, { expr = true })
      end,
   },
   {
      "jisho",
      cmd = "Jisho",
      after = function()
         require("jisho").setup()

         -- Setup keymaps
         vim.keymap.set("n", "<leader>tj", function()
            require("jisho").search()
         end, { desc = "Jisho (Word under cursor)" })
         vim.keymap.set("v", "<leader>tj", function()
            local start_pos = vim.fn.getpos("v")
            local end_pos = vim.fn.getpos(".")
            local lines = vim.fn.getregion(start_pos, end_pos)
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
            require("jisho").search(table.concat(lines, " "))
         end, { desc = "Jisho (Selection)" })
      end,
   },
   {
      "codediff.nvim",
      after = function()
         require("codediff").setup({})
      end,
   },
})

vim.opt.rtp:append("~/Plugins/feed.nvim/")
require("_feed")

vim.cmd("packadd nvim.undotree")
vim.cmd("packadd nvim.difftool")
vim.cmd("packadd nvim.tohtml")
vim.cmd("packadd nohlsearch")
vim.cmd("packadd cfilter")

-- require("lsp-file-operations").setup({})

require("options")
require("experiments")

vim.lsp.enable({
   "gopls",
   "nixd",
   "ruff",
   "ts_ls",
   "copilot",
   -- "pyright",
   -- "markdown_oxide"
   -- "marksman",
   -- "harper_ls",
})

require("autocmds")
require("pomodoro").setup()
require("keymaps")

-- vim.opt.statusline = "%!v:lua.require'ui.statusline'.render()"

require("vim._core.ui2").enable({
   msg = {
      targets = "msg",
   },
})

-- vim.cmd.colorscheme("lauds")
vim.cmd.colorscheme("tokyonight")
-- vim.cmd.colorscheme("luna")
