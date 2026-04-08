- [[archived]]
- [[lib]]

## carlos-algms/agentic.nvim

```lua
require("agentic").setup({
   provider = "opencode-acp",
})

vim.keymap.set({ "n", "v", "i" }, "<leader>A", function()
   require("agentic").toggle()
end, { desc = "Toggle Agentic Chat" })

vim.keymap.set({ "n", "v" }, "<leader>aa", function()
   require("agentic").add_selection_or_file_to_context()
end, { desc = "Add file or selection to Agentic to Context" })

vim.keymap.set({ "n", "v", "i" }, "<leader>an", function()
   require("agentic").new_session()
end, { desc = "[N]ew Agentic Session" })

vim.keymap.set({ "n", "v", "i" }, "<leader>as", function()
   require("agentic").restore_session()
end, { desc = "Agentic Restore session", silent = true })

vim.keymap.set("n", "<leader>ad", function()
   require("agentic").add_current_line_diagnostics()
end, { desc = "Add current line diagnostic to Agentic" })

vim.keymap.set("n", "<leader>aD", function()
   require("agentic").add_buffer_diagnostics()
end, { desc = "Add all buffer diagnostics to Agentic" })
```

## nvim-lualine/lualine.nvim

```lua
local ok, sync = pcall(require, "obsidian.sync.status")
require("lualine").setup({
   options = {
      component_separators = "",
      section_separators = "",
   },
   sections = {
      lualine_x = {
         {
            "g:obsidian_sync_status_icon",
            color = ok and sync.color or nil,
         },
         {
            "g:obsidian_spaced_repetition_status",
         },
      },
   },
})
```

## Utilities

### 2kabhishek/nerdy.nvim!

- cmd: `Nerdy`

## alex-popov-tech/store.nvim!

## shortcuts/no-neck-pain.nvim

## quarto-dev/quarto-nvim

## xieyonn/spinner.nvim

```lua
require("spinner").setup({})
```

## jbuck95/recollect.nvim

## juansalvatore/git-dashboard-nvim

## DB

### tpope/vim-dadbod

### kristijanhusak/vim-dadbod-ui

### kristijanhusak/vim-dadbod-completion

### kkharji/sqlite.lua

## Vim Enhancement

<!-- ### neo451/jieba-lua -->
<!---->
<!-- ### neo451/jieba.nvim -->
<!---->

### stevearc/quicker.nvim!

- ft: `qf`

### monaqa/dial.nvim

- keys: `{ "<C-a>", "<C-x>", "g<C-a>", "g<C-x>" }`

```lua
local augend = require("dial.augend")

require("dial.config").augends:register_group({
   default = {
      augend.date.alias["%Y/%m/%d"], -- date (2022/02/19, etc.)
      augend.date.alias["%m/%d/%Y"], -- date (02/19/2022, etc.)
      augend.constant.alias.bool, -- boolean value (true <-> false)
      augend.integer.alias.decimal, -- nonnegative decimal number (0, 1, 2, 3, ...)
   },
})

vim.keymap.set("n", "<C-a>", function()
   require("dial.map").manipulate("increment", "normal")
end)
vim.keymap.set("n", "<C-x>", function()
   require("dial.map").manipulate("decrement", "normal")
end)
vim.keymap.set("v", "g<C-a>", function()
   require("dial.map").manipulate("increment", "gvisual")
end)
vim.keymap.set("v", "g<C-x>", function()
   require("dial.map").manipulate("decrement", "gvisual")
end)
```

### andrewferrier/debugprint.nvim!

- keys: `g?v`
- cmd: `Debugprint`

- `g?p`/`g?P`
- `g?v`
- `Debugprint qflist`

## Git

### noamsto/resolved.nvim!

## stevearc/oil.nvim

```lua
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
```

## UI

### folke/tokyonight.nvim

```lua
vim.cmd.colorscheme("tokyonight")
```

### folke/todo-comments.nvim

```lua
require("todo-comments").setup({})
```

## mistweaverco/kulala.nvim

- ft: `{ "http", "rest" }`
- keys: `{ "<leader>Rs", "<leader>Ra", "<leader>Rb" }`

```lua
require("kulala").setup({
   global_keymaps = true,
})
```

## Bib

### krissen/blink-cmp-bibtex

- ft: `markdown`

```lua
require("blink-cmp-bibtex").setup({
   filetypes = { "markdown" },
   files = { vim.fn.expand("$REF") },
})
```

### krissen/snacks-bibtex.nvim

- ft: `markdown`

```lua
require("snacks-bibtex").setup({
   global_files = {
      vim.fn.expand("$REF"),
   },
})
vim.keymap.set("n", "<leader>bc", function()
   require("snacks-bibtex").bibtex()
end, {
   desc = "BibTeX citations (Snacks)",
})
```

## Markdown

### hasansujon786/super-kanban.nvim!

### MeanderingProgrammer/render-markdown.nvim

- ft: `markdown`

```lua
require("render-markdown").setup({
   html = {
      comment = { conceal = false },
   },
})
```

### YousefHadder/markdown-plus.nvim

- ft: `markdown`

```lua
require("markdown-plus").setup({})
```

### bngarren/checkmate.nvim!

- ft: `markdown`

works for `todo.md` `TODO.md`

<!-- ### numEricL/table.vim -->

## LSP

### rachartier/tiny-code-action.nvim!

- event: `LspAttach`

## Completion

### rafamadriz/friendly-snippets

### archie-judd/blink-cmp-words

### saghen/blink.cmp

- event: `{ "InsertEnter", "CmdlineEnter" }`
- version: `1.*`

```lua
require("blink.cmp").setup({
   -- keymap = { preset = "default" },
   completion = {
      menu = {
         draw = {
            columns = {
               { "label", "label_description", gap = 3 },
               { "kind" },
            },
         },
      },
      documentation = { auto_show = true },
   },

   cmdline = {
      enabled = false,
   },

   sources = {
      default = {
         "lsp",
         "path",
         "snippets",
         "buffer",
      },
      per_filetype = {
         markdown = {
            "bibtex",
            -- "obsidian",
            "dictionary",
         },
         sql = { "snippets", "dadbod", "buffer" },
      },
      providers = {
         lsp = {
            transform_items = function(_, items)
               -- the default transformer will do this
               for _, item in ipairs(items) do
                  if item.kind == require("blink.cmp.types").CompletionItemKind.Snippet then
                     item.score_offset = item.score_offset - 3
                  end
               end
               -- you can define your own filter for rime item
               return items
            end,
         },
         dadbod = {
            name = "Dadbod",
            module = "vim_dadbod_completion.blink",
         },
         bibtex = {
            module = "blink-cmp-bibtex",
            name = "BibTeX",
            min_keyword_length = 2,
            score_offset = 10,
            async = true,
            opts = {},
            -- provider-level overrides (optional)
         },
         -- Use the thesaurus source
         thesaurus = {
            name = "blink-cmp-words",
            module = "blink-cmp-words.thesaurus",
            -- All available options
            opts = {
               -- A score offset applied to returned items.
               -- By default the highest score is 0 (item 1 has a score of -1, item 2 of -2 etc..).
               score_offset = 0,

               -- Default pointers define the lexical relations listed under each definition,
               -- see Pointer Symbols below.
               -- Default is as below ("antonyms", "similar to" and "also see").
               definition_pointers = { "!", "&", "^" },

               -- The pointers that are considered similar words when using the thesaurus,
               -- see Pointer Symbols below.
               -- Default is as below ("similar to", "also see" }
               similarity_pointers = { "&", "^" },

               -- The depth of similar words to recurse when collecting synonyms. 1 is similar words,
               -- 2 is similar words of similar words, etc. Increasing this may slow results.
               similarity_depth = 2,
            },
         },

         -- Use the dictionary source
         dictionary = {
            name = "blink-cmp-words",
            module = "blink-cmp-words.dictionary",
            -- All available options
            opts = {
               -- The number of characters required to trigger completion.
               -- Set this higher if completion is slow, 3 is default.
               dictionary_search_threshold = 3,
               -- See above
               score_offset = 0,
               -- See above
               definition_pointers = { "!", "&", "^" },
            },
         },
      },
   },
})
```

## nvim-mini/mini.nvim

vip followed by gh / gH applies/resets hunks inside current paragraph. Same can be achieved in operator form ghip / gHip, which has the advantage of being dot-repeatable.
gh* / gH* applies/resets current line (even if it is not a full hunk).
ghgh / gHgh applies/resets hunk range under cursor.
dgh deletes hunk range under cursor.
`[H` / `[h` / `]h` / `]H` navigate cursor to the first / previous / next / last hunk range of the current buffer.

```lua
local miniclue = require("mini.clue")
miniclue.setup({
   -- Define which clues to show. By default shows only clues for custom mappings
   -- (uses `desc` field from the mapping; takes precedence over custom clue).
   clues = {
      -- _G.Config.leader_group_clues,
      {
         { mode = "n", keys = "<Leader>b", desc = "+Buffer" },
         { mode = "n", keys = "<Leader>e", desc = "+Explore/Edit" },
         { mode = "n", keys = "<Leader>f", desc = "+Find" },
         { mode = "n", keys = "<Leader>t", desc = "+Terminal" },
         { mode = "n", keys = "<Leader>g", desc = "+Git" },
         { mode = "n", keys = "<Leader>u", desc = "+UI" },
         { mode = "n", keys = "<Leader>o", desc = "+Obsidian" },
         { mode = "n", keys = "<Leader><Leader>", desc = "+Other" },
      },
      miniclue.gen_clues.builtin_completion(),
      miniclue.gen_clues.g(),
      miniclue.gen_clues.marks(),
      miniclue.gen_clues.registers(),
      miniclue.gen_clues.z(),
   },
   window = {
      config = {
         width = 50,
      },
   },
   -- Explicitly opt-in for set of common keys to trigger clue window
   triggers = {
      { mode = "n", keys = "<Leader>" }, -- Leader triggers
      { mode = "x", keys = "<Leader>" },
      { mode = "n", keys = "\\" }, -- mini.basics
      { mode = "n", keys = "[" }, -- mini.bracketed
      { mode = "n", keys = "]" },
      { mode = "x", keys = "[" },
      { mode = "x", keys = "]" },
      { mode = "i", keys = "<C-x>" }, -- Built-in completion
      { mode = "n", keys = "g" }, -- `g` key
      { mode = "x", keys = "g" },
      { mode = "n", keys = "'" }, -- Marks
      { mode = "n", keys = "`" },
      { mode = "x", keys = "'" },
      { mode = "x", keys = "`" },
      { mode = "n", keys = '"' }, -- Registers
      { mode = "x", keys = '"' },
      { mode = "i", keys = "<C-r>" },
      { mode = "c", keys = "<C-r>" },
      { mode = "n", keys = "<C-w>" }, -- Window commands
      { mode = "n", keys = "z" }, -- `z` key
      { mode = "x", keys = "z" },
   },
})
require("mini.ai").setup({})
require("mini.diff").setup({})
require("mini.git").setup({})
require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons()
require("mini.surround").setup({})
require("mini.test").setup({})
require("mini.pick").setup({})
require("mini.extra").setup({})
```

## folke/snacks.nvim

```lua

local api = require("obsidian.api")
local util = require("obsidian.util")

local cache = {}

local function resovle_image(path, src)
   local is_uri, scheme = util.is_uri(src)
   if not api.path_is_note(path) then
      return
   end

   if is_uri and scheme == "https" then
      -- if cache[src] then
      --    return cache[src]
      -- end
      -- local tmp = vim.fn.tempname() .. ".png" -- TODO: get suffix
      -- local cmd = { "curl", "-L", "-o", tmp, src }
      -- local result = vim.system(cmd):wait()
      -- if result.code == 0 then
      --    cache[src] = tmp
      --    print(tmp)
      --    return tmp
      -- else
      --    vim.notify("Failed to download image: " .. result.stderr, vim.log.levels.ERROR)
      --    return nil
      -- end
   else
      return api.resolve_attachment_path(src)
   end
end

require("snacks").setup({
   lazygit = {},
   gitbrowse = { enabled = true },
   scroll = { enabled = true },
   image = {
      enabled = vim.fn.executable("convert") == 1,
      resolve = resovle_image,
      -- wo = { winhighlight = "FloatBorder:WhichKeyBorder" },
      doc = {
         inline = true,
         max_width = 45,
         max_height = 20,
      },
   },
   input = { enabled = true },
   picker = { enabled = true },
   statuscolumn = { enabled = true },
   styles = {
      notification = {
         wo = { wrap = true },
      },
   },
   notifier = {
      enabled = true,
      timeout = 3000,
   },
})
```

## esmuellert/codediff.nvim

- cmd: `CodeDiff`

## stevearc/conform.nvim

```lua
require("conform").setup({
   format_on_save = function(bufnr)
      local bufname = vim.api.nvim_buf_get_name(bufnr)

      -- List of path patterns to exclude from formatting
      local exclude_patterns = {
         "/Templates/",
      }

      for _, pattern in ipairs(exclude_patterns) do
         if bufname:match(pattern) then
            return -- returning nil skips formatting
         end
      end

      return { timeout_ms = 500, lsp_format = "fallback" }
   end,
   formatters_by_ft = {
      nix = { "alejandra" },
      lua = { "stylua" },
      markdown = { "prettier", "injected" },
      quarto = { "prettier" },
      qml = { "qmlformat" },
      json = { "jq" },
   },
})
```
