vim.loader.enable()

vim.pack.add({
   "https://github.com/MagicDuck/grug-far.nvim",
   "https://github.com/neovim/nvim-lspconfig",
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
   "https://github.com/stevearc/conform.nvim",
   "https://github.com/stevearc/oil.nvim",
   "https://github.com/folke/tokyonight.nvim",
   "https://github.com/edeneast/nightfox.nvim",
   "https://github.com/catppuccin/nvim",

   -- writing
   "https://github.com/MeanderingProgrammer/render-markdown.nvim",
   "https://github.com/techwizrd/render-latex.nvim",
   -- "https://github.com/OXY2DEV/markview.nvim",
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
   "https://github.com/xieyonn/spinner.nvim",

   -- jj
   "https://github.com/NicholasZolton/neojj",

   "https://github.com/nvim-lua/plenary.nvim",
   "https://github.com/nvim-telescope/telescope.nvim",

   -- lib
   "https://github.com/monok-robeto/nvim.sfx_player",

   -- "https://github.com/glacambre/firenvim",
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
   { "render-markdown.nvim" },
   {
      "tiny-code-action.nvim",
      after = function()
         require("tiny-code-action").setup({
            picker = "snacks",
         })
      end,
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
      "conform.nvim",
      event = "BufEnter",
      after = function()
         require("_conform")
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

require("_obsidian")

vim.opt.rtp:append("~/Plugins/feed.nvim/")
require("_feed")

vim.cmd("packadd nvim.undotree")
vim.cmd("packadd nvim.difftool")
vim.cmd("packadd nvim.tohtml")
vim.cmd("packadd nohlsearch")
vim.cmd("packadd cfilter")

-- require("lsp-file-operations").setup({})
--
-- local lspconfig = require("lspconfig")
--
-- -- Set global defaults for all servers
-- lspconfig.util.default_config = vim.tbl_extend("force", lspconfig.util.default_config, {
--    capabilities = vim.tbl_deep_extend(
--       "force",
--       vim.lsp.protocol.make_client_capabilities(),
--       -- returns configured operations if setup() was already called
--       -- or default operations if not
--       require("lsp-file-operations").default_capabilities()
--    ),
-- })

require("options")
require("experiments")

vim.lsp.enable("rime_ls")
vim.lsp.enable("emmylua_ls")
vim.lsp.enable("pele")

local servers = {
   "gopls",
   "nixd",
   "ruff",
   "ts_ls",
   "copilot",
   -- "pyright",
   -- "markdown_oxide"
   -- "marksman",
   -- "harper_ls",
}

for _, name in ipairs(servers) do
   local _, err = pcall(vim.lsp.enable, name)
   if err ~= nil then
      vim.notify(err)
   end
end

require("autocmds")
require("pomodoro").setup()
require("keymaps")

-- vim.opt.statusline = "%!v:lua.require'ui.statusline'.render()"

require("vim._core.ui2").enable({
   msg = {
      targets = "msg",
   },
})

-- vim.cmd.colorscheme("duskfox")
-- vim.cmd.colorscheme("tokyonight")
vim.cmd.colorscheme("catppuccin")
