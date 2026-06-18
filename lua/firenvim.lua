-- Mode tailored for firenvim browser textareas.
-- Loaded only when vim.g.started_by_firenvim is truthy (set via --cmd by firenvim).

local M = {}

M.active = vim.g.started_by_firenvim == true or vim.g.started_by_firenvim == 1

-- Plugin names (matches spec.name from vim.pack.add) to skip in browser context.
M.skip = {
   ["no-neck-pain.nvim"] = true,
   ["tiny-cmdline.nvim"] = true,
   ["tiny-code-action.nvim"] = true,
   ["render-markdown.nvim"] = true,
   ["markdown-plus.nvim"] = true,
   ["quarto-nvim"] = true,
   ["snacks.nvim"] = true,
   ["oil.nvim"] = true,
   ["quicker.nvim"] = true,
   ["image.nvim"] = true,
   ["telescope.nvim"] = true,
   ["fzf-lua"] = true,
   ["vim-dadbod"] = true,
   ["vim-dadbod-ui"] = true,
   ["vim-dadbod-completion"] = true,
   ["sqlite.lua"] = true,
   ["kanban.nvim"] = true,
   ["neojj"] = true,
   ["codediff.nvim"] = true,
   ["resolved.nvim"] = true,
   ["agentic.nvim"] = true,
   ["debugprint.nvim"] = true,
   ["conform.nvim"] = true,
   ["blink.cmp"] = true,
   ["blink-cmp-words"] = true,
   ["friendly-snippets"] = true,
   ["nvim-lspconfig"] = true,
   ["nvim-lsp-file-operations"] = true,
   ["spinner.nvim"] = true,
   ["budoux.lua"] = true,
   ["jisho.nvim"] = true,
   ["jieba-lua"] = true,
   ["jieba.nvim"] = true,
   ["zotcite"] = true,
   ["coop.nvim"] = true,
}

function M.ui_setup()
   local o, wo = vim.opt, vim.wo
   o.laststatus = 0
   o.showtabline = 0
   o.cmdheight = 1
   o.showmode = false
   o.showcmd = false
   o.ruler = false
   o.number = false
   o.relativenumber = false
   o.signcolumn = "no"
   o.colorcolumn = ""
   o.foldcolumn = "0"
   o.wrap = true
   o.linebreak = true
   o.spell = true
   o.list = false
   o.cursorline = false
   wo.winbar = ""
   o.statusline = " "
   pcall(vim.cmd.colorscheme, "habamax")
end

function M.plugin_setup()
   vim.g.firenvim_config = {
      globalSettings = { alt = "all" },
      localSettings = {
         [".*"] = {
            cmdline = "neovim",
            content = "text",
            priority = 0,
            selector = "textarea, div[role='textbox']",
            takeover = "never",
         },
      },
   }
end

function M.attach_autocmds()
   local grp = vim.api.nvim_create_augroup("firenvim_mode", { clear = true })

   vim.api.nvim_create_autocmd("UIEnter", {
      group = grp,
      callback = function()
         local chan = vim.v.event.chan
         if not chan or chan == 0 then return end
         local ok, info = pcall(vim.api.nvim_get_chan_info, chan)
         if not ok then return end
         local client = info.client or {}
         if client.name ~= "Firenvim" then return end
         M.ui_setup()
      end,
   })
end

return M
