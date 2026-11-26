vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.loader.enable(true)

local opt = vim.opt
local o = vim.o

-- ui
o.cmdheight = 0 -- works with :h ui2
o.number = true
o.relativenumber = true
o.cursorline = true
o.splitright = true
o.splitbelow = true

-- text
o.list = true
---@diagnostic disable-next-line: missing-fields
opt.fillchars = {
   foldopen = "",
   foldclose = "",
   fold = " ",
   foldsep = " ",
   diff = "╱",
   eob = " ",
}

o.updatetime = 300
o.iskeyword = "@,48-57,_,192-255,-" -- Treat dash as `word` textobject part

-- search
o.ignorecase = true -- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
o.smartcase = true

-- term
o.shell = "fish"

-- typing
o.expandtab = true
o.tabstop = 2 -- Number of spaces tabs count for
o.shiftwidth = 2
o.formatoptions = "jcroqlnt" -- Format options

-- completion
o.complete = ".,w,b,kspell" -- Use less sources
o.completeopt = "menu,menuone,noselect,popup,fuzzy"
-- o.wildmode = "longest:full,full" -- Command-line completion mode
vim.cmd([[set wildmode=noselect:lastused,full]])

-- undo
o.undofile = true
o.undolevels = 10000

-- Obsidian Headless watches the vault and can capture Neovim's transient
-- `filename~` write-back files as real notes.
o.backup = false
o.writebackup = false

-- writing
o.spelllang = "en,cjk"
o.spellfile = vim.fs.joinpath(vim.fn.stdpath("config"), "spell", "en.utf-8.add")
vim.g.spell_aff = vim.fs.joinpath(vim.fn.stdpath("config"), "spell", "en.utf-8.aff")

-- vim.diagnostic.config({
--    -- virtual_text = {
--    virtual_lines = {
--       current_line = true,
--    },
-- })
