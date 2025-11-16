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
o.updatetime = 300

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
-- o.clipboard = vim.env.SSH_TTY and "" or "unnamedplus" -- Sync with system clipboard

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
o.spellfile = vim.fs.joinpath(vim.fn.stdpath("config"), "spell", "en.utf-8.add")

vim.cmd([[set completeopt+=menuone,noselect,popup]])

vim.diagnostic.config({
   signs = {
      text = {
         [vim.diagnostic.severity.ERROR] = " ",
         [vim.diagnostic.severity.WARN] = " ",
         [vim.diagnostic.severity.INFO] = "󰌶 ",
      },
   },
})
