vim.loader.enable()

-- cppjieba is distributed as a LuaRock; expose its Lua wrapper and native
-- module without adding the rock's plugin directory (which creates global
-- word-motion mappings).
local rocks = vim.fs.joinpath(vim.fn.stdpath("data"), "rocks")
local rocks_lua = vim.fs.joinpath(rocks, "share", "lua", "5.1")
local rocks_lib = vim.fs.joinpath(rocks, "lib", "lua", "5.1")
package.path = rocks_lua .. "/?.lua;" .. rocks_lua .. "/?/init.lua;" .. package.path
package.cpath = rocks_lib .. "/?.so;" .. package.cpath

-- Binary rocks cannot discover libstdc++ through Nix's dynamic linker path.
if vim.env.NIX_LD_LIBRARY_PATH then
   package.loadlib(vim.fs.joinpath(vim.env.NIX_LD_LIBRARY_PATH, "libstdc++.so.6"), "*")
end

vim.pack.add({
   -- try
   "https://github.com/jrop/morph.nvim",
   "https://github.com/viniciusteixeiradias/kanban.nvim",

   "https://github.com/MagicDuck/grug-far.nvim",

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
   -- "https://github.com/MeanderingProgrammer/render-markdown.nvim",
   "https://github.com/techwizrd/render-latex.nvim",
   -- "https://github.com/pxwg/math-conceal.nvim",
   -- "https://github.com/OXY2DEV/markview.nvim",
   "https://github.com/YousefHadder/markdown-plus.nvim",
   "https://github.com/jmbuhr/otter.nvim",
   "https://github.com/quarto-dev/quarto-nvim",
   "https://github.com/lervag/vimtex",

   -- "https://github.com/jalvesaq/zotcite",

   -- language
   "https://github.com/atusy/budoux.lua",
   "https://github.com/Imngzx/jisho.nvim",

   --- db
   "https://github.com/tpope/vim-dadbod",
   "https://github.com/kristijanhusak/vim-dadbod-ui",
   "https://github.com/kristijanhusak/vim-dadbod-completion",
   "https://github.com/kkharji/sqlite.lua",

   -- git
   "https://github.com/esmuellert/codediff.nvim",
   "https://github.com/noamsto/resolved.nvim",

   -- ui
   "https://github.com/shortcuts/no-neck-pain.nvim",
   "https://github.com/rachartier/tiny-code-action.nvim",

   "https://github.com/andrewferrier/debugprint.nvim",

   -- treesitter
   {
      src = "https://github.com/nvim-treesitter/nvim-treesitter",
      version = "main",
   },

   -- image
   "https://github.com/3rd/image.nvim",

   -- lib
   "https://github.com/gregorias/coop.nvim",
   "https://github.com/ibhagwan/fzf-lua",

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

-- vim.opt.rtp:append("~/Plugins/irc.nvim")

require("_mini")
require("_treesitter")

require("lz.n").load({
   {
      "fzf-lua",
      after = function()
         -- require("fzf-lua").setup({
         --    "fzf-tmux",
         --    files = {
         --       previewer = false,
         --       fzf_opts = {
         --          ["--tmux"] = "center",
         --          ["--keep-right"] = "",
         --       },
         --    },
         -- })
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
      "snacks.nvim",
      keys = {
         -- {
         --    "<leader>T",
         --    function()
         --       ---@diagnostic disable-next-line: undefined-global
         --       Snacks.terminal()
         --    end,
         -- },
      },
      after = function()
         require("snacks").setup({
            input = { enabled = true },
            statuscolumn = { enabled = true },
            styles = {
               notification = { wo = { wrap = true } },
            },
            -- picker = { enabled = true },
            notifier = { enabled = true, timeout = 3000 },
            image = { enabled = true },
         })
      end,
   },
   {
      "agentic.nvim",
      keys = {
         { "<localleader>A", desc = "Toggle Agentic Chat" },
         { "<localleader>aa", mode = { "n", "v" }, desc = "Add file or selection to Agentic to Context" },
         { "<localleader>an", mode = { "n", "v", "i" }, desc = "[N]ew Agentic Session" },
         { "<localleader>as", mode = { "n", "v" }, desc = "Agentic Restore session" },
         { "<localleader>ad", desc = "Add current line diagnostic to Agentic" },
         { "<localleader>aD", desc = "Add all buffer diagnostics to Agentic" },
      },
      after = function()
         require("_agentic")
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
      "debugprint.nvim",
      keys = { "g?v" },
      after = function()
         require("debugprint").setup({})
      end,
   },
   {
      "jisho.nvim",
      -- cmd = "Jisho",
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
      "tokyonight.nvim",
      after = function()
         vim.cmd.colorscheme("tokyonight")
      end,
   },
   -- {
   --    "nvim",
   --    after = function()
   --       vim.cmd.colorscheme("catppuccin")
   --    end,
   -- },
   -- {
   --    "nightfox.nvim",
   --    after = function()
   --       vim.cmd.colorscheme("duskfox")
   --    end,
   -- },
   {
      "render-markdown.nvim",

      after = function()
         require("render-markdown").setup({
            html = {
               comment = { conceal = false },
            },
            latex = { enabled = false },
         })
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
   {
      "image.nvim",
      after = function()
         -- require("image").setup({})
      end,
   },
})

require("_obsidian")

-- vim.opt.rtp:append("~/Plugins/feed.nvim/")
-- vim.cmd.packadd("feed.nvim")
-- require("_feed")

vim.schedule(function()
   vim.cmd("packadd nvim.undotree")
   vim.cmd("packadd nvim.difftool")
   vim.cmd("packadd nvim.tohtml")
   vim.cmd("packadd nohlsearch")
   vim.cmd("packadd cfilter")

   vim.pack.add({
      "https://github.com/xieyonn/spinner.nvim",
      "https://github.com/neovim/nvim-lspconfig",
      "https://github.com/igorlfs/nvim-lsp-file-operations",
   })

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

   -- vim.cmd("packadd coop.nvim")

   -- vim.opt.rtp:append("~/Plugins/diy.nvim/")
   -- vim.opt.rtp:append("~/Plugins/nldates.nvim/")
   -- vim.opt.rtp:append("~/Plugins/templater.nvim/")
   -- vim.opt.rtp:append("~/Plugins/dict-lsp.nvim/")
   -- require("dict-lsp")
   -- vim.opt.rtp:append("~/Plugins/obpilot/")
   -- require("obpilot")
   -- vim.opt.rtp:append("~/Plugins/calendar.nvim/")
   -- vim.opt.rtp:append("~/Plugins/nvim-treesitter/")
end)

require("options")
require("experiments")

local servers = {
   "rime_ls",
   -- "lua_ls",
   "emmylua_ls",
   "gopls",
   "nixd",
   "zls",
   "qmlls",
   "ruff",
   "ts_ls",
   "copilot",
   -- "pyright",
   -- "markdown_oxide"
   -- "marksman",
   -- "dummy_ls",
   -- "harper_ls",
}

-- require("lspconfig").setup({})

for _, name in ipairs(servers) do
   local _, err = pcall(vim.lsp.enable, name)
   if err ~= nil then
      vim.notify(err)
   end
end

--- TODO: lazy and other capabilities

require("autocmds")
require("keymaps")

vim.opt.statusline = "%!v:lua.require'ui.statusline'.render()"

require("vim._core.ui2").enable({
   msg = {
      targets = "msg",
   },
})
