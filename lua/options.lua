vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.node_host_prog = vim.fn.exepath("neovim-node-host")

vim.g.node_host_prog = vim.fn.exepath("neovim-node-host")
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.loader.enable(true)

local opt = vim.opt
local o = vim.o

-- ui
o.cmdheight = 0
o.number = true
o.relativenumber = true
o.breakindent = true
o.showmode = false
o.cursorline = true
o.list = true
opt.listchars = {
   tab = "  ",
   trail = "·",
   nbsp = "␣",
}

o.iskeyword = "@,48-57,_,192-255,-" -- Treat dash as `word` textobject part

-- builtin completion
o.complete = ".,w,b,kspell" -- Use less sources
o.completeopt = "menuone,noselect,fuzzy,nosort" -- Use custom behavior

-- search
o.ignorecase = true

-- term
o.shell = "fish"

-- typing
o.expandtab = true
o.tabstop = 2 -- Number of spaces tabs count for
o.shiftwidth = 2

-- window manage
o.splitright = true
o.splitbelow = true

-- editing
o.autowrite = true
o.clipboard = vim.env.SSH_TTY and "" or "unnamedplus" -- Sync with system clipboard

-- completion
o.completeopt = "menu,menuone"
o.wildmode = "longest:full,full" -- Command-line completion mode

-- undo
o.undofile = true
o.undolevels = 10000
o.updatetime = 200 -- Save swap file and trigger CursorHold

o.formatoptions = "jcroqlnt" -- Format options

-- writing
o.spelllang = "en,cjk"

-- diagnostic

-- See `:h vim.diagnostic` and `:h vim.diagnostic.config()`.
local diagnostic_opts = {
   -- -- Show signs on top of any other sign, but only for warnings and errors
   -- signs = { priority = 9999, severity = { min = "WARN", max = "ERROR" } },
   --
   -- -- Show all diagnostics as underline (for their messages type `<Leader>ld`)
   -- underline = { severity = { min = "HINT", max = "ERROR" } },

   -- Show more details immediately for errors on the current line
   virtual_lines = false,
   virtual_text = {
      current_line = true,
      severity = { min = "ERROR", max = "ERROR" },
   },

   -- Don't update diagnostics when typing
   update_in_insert = false,
}

vim.diagnostic.config(diagnostic_opts)
