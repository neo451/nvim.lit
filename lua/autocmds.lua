local function augroup(name)
   return vim.api.nvim_create_augroup("auto_" .. name, { clear = true })
end

-- Check if we need to reload the file when it changed
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
   group = augroup("checktime"),
   callback = function()
      if vim.o.buftype ~= "nofile" then
         vim.cmd("checktime")
      end
   end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
   group = augroup("highlight_yank"),
   callback = function()
      (vim.hl or vim.highlight).on_yank()
   end,
})

-- resize splits if window got resized
vim.api.nvim_create_autocmd({ "VimResized" }, {
   group = augroup("resize_splits"),
   callback = function()
      local current_tab = vim.fn.tabpagenr()
      vim.cmd("tabdo wincmd =")
      vim.cmd("tabnext " .. current_tab)
   end,
})

-- go to last loc when opening a buffer
vim.api.nvim_create_autocmd("BufReadPost", {
   group = augroup("last_loc"),
   callback = function(event)
      local exclude = { "gitcommit" }
      local buf = event.buf
      if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].lazyvim_last_loc then
         return
      end
      vim.b[buf].lazyvim_last_loc = true
      local mark = vim.api.nvim_buf_get_mark(buf, '"')
      local lcount = vim.api.nvim_buf_line_count(buf)
      if mark[1] > 0 and mark[1] <= lcount then
         pcall(vim.api.nvim_win_set_cursor, 0, mark)
      end
   end,
})

-- close some filetypes with <q>
vim.api.nvim_create_autocmd("FileType", {
   group = augroup("close_with_q"),
   pattern = {
      "query",
      "PlenaryTestPopup",
      "checkhealth",
      "dbout",
      "gitsigns-blame",
      "grug-far",
      "help",
      "lspinfo",
      "neotest-output",
      "neotest-output-panel",
      "neotest-summary",
      "notify",
      "qf",
      "spectre_panel",
      "startuptime",
      "tsplayground",
      "codecompanion",
      "2048Game",
   },
   callback = function(event)
      vim.bo[event.buf].buflisted = false
      vim.schedule(function()
         pcall(function()
            vim.keymap.set("n", "q", function()
               vim.cmd("close")
               pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
            end, {
               buffer = event.buf,
               silent = true,
               desc = "Quit buffer",
            })
         end)
      end)
   end,
})

-- make it easier to close man-files when opened inline
vim.api.nvim_create_autocmd("FileType", {
   group = augroup("man_unlisted"),
   pattern = { "man" },
   callback = function(event)
      vim.bo[event.buf].buflisted = false
   end,
})

-- Fix conceallevel for json files
vim.api.nvim_create_autocmd({ "FileType" }, {
   group = augroup("json_conceal"),
   pattern = { "json", "jsonc", "json5" },
   callback = function()
      vim.opt_local.conceallevel = 0
   end,
})

-- Auto create dir when saving a file, in case some intermediate directory does not exist
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
   group = augroup("auto_create_dir"),
   callback = function(event)
      if event.match:match("^%w%w+:[\\/][\\/]") then
         return
      end
      local file = vim.uv.fs_realpath(event.match) or event.match
      vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
   end,
})

vim.api.nvim_create_autocmd("LspAttach", {
   desc = "Attach lsp stuff",
   callback = function(ev)
      local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))

      vim.keymap.set({ "n", "x" }, "gra", function()
         local ok, tiny = pcall(require, "tiny-code-action")
         if ok then
            tiny.code_action({})
         else
            vim.lsp.buf.code_action()
         end
      end, { buffer = ev.buf })

      -- vim.keymap.set({ "n", "x" }, "grn", function()
      --    local ok, inc = pcall(require, "inc_rename")
      --    if ok and inc then
      --       return ":IncRename " .. vim.fn.expand("<cword>")
      --    else
      --       return ":lua vim.lsp.buf.rename()"
      --    end
      -- end, { buffer = ev.buf, expr = true })

      vim.keymap.set("n", "<leader>D", function()
         vim.lsp.buf.workspace_diagnostics()
      end, { buffer = ev.buf })
   end,
})

vim.api.nvim_create_autocmd("FileType", {
   desc = "Start treesitter",
   callback = function(ev)
      pcall(vim.treesitter.start, ev.buf)
   end,
})
--
-- _G.Config.new_autocmd("BufReadPre", nil, "Install missing parser", function()
--    require("nvim-treesitter").install({ vim.treesitter.language.get_lang(vim.bo.filetype) })
-- end)
--
-- _G.Config.new_autocmd("User", "ObsidianNoteWritePre", "Note metadata", function(ev)
--    local note = require("obsidian.note").from_buffer(ev.buf)
--    note:add_field("modified", os.date("%Y-%m-%d %H:%M"))
-- end)

-- _G.Config.new_autocmd("CursorMoved", nil, "Highlight references under cursor", function(ev)
--    if vim.bo.filetype == "markdown" then
--       return
--    end
--
--    if vim.fn.mode == "i" then
--       return
--    end
--
--    local current_word = vim.fn.expand("<cword>")
--    if vim.b.current_word and vim.b.current_word == current_word then
--       return
--    end
--
--    vim.b.current_word = current_word
--
--    local clients = vim.lsp.get_clients({ buffer = ev.buf, method = "textDocument/documentHighlight" })
--    if #clients == 0 then
--       return
--    end
--
--    vim.lsp.buf.clear_references()
--    vim.lsp.buf.document_highlight()
-- end)

vim.api.nvim_create_autocmd("BufWritePre", {
   pattern = "*",
   callback = function(args)
      if pcall(require, "conform") then
         require("conform").format({ bufnr = args.buf })
      end
   end,
})

--- MPLS Focus Handler
local function create_debounced_mpls_sender(delay)
   delay = delay or 300
   local timer = nil

   return function()
      if timer then
         timer:close()
         timer = nil
      end

      ---@diagnostic disable-next-line: undefined-field
      timer = vim.uv.new_timer()
      if not timer then
         vim.notify("Failed to create timer for MPLS focus", vim.log.levels.ERROR)
         return
      end

      timer:start(
         delay,
         0,
         vim.schedule_wrap(function()
            local bufnr = vim.api.nvim_get_current_buf()

            local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
            if filetype ~= "markdown" then
               return
            end

            local clients = vim.lsp.get_clients({ name = "mpls" })

            if #clients == 0 then
               return
            end

            local client = clients[1]
            local params = { uri = vim.uri_from_bufnr(bufnr) }

            ---@diagnostic disable-next-line: param-type-mismatch
            client:notify("mpls/editorDidChangeFocus", params)

            if timer then
               timer:close()
               timer = nil
            end
         end)
      )
   end
end

-- -- CodeLens: auto-refresh + keymaps
-- vim.api.nvim_create_autocmd("LspAttach", {
--    group = vim.api.nvim_create_augroup("my-lsp-codelens", { clear = true }),
--    callback = function(args)
--       local bufnr = args.buf
--       local client = vim.lsp.get_client_by_id(args.data.client_id)
--       if not client or not client.server_capabilities.codeLensProvider then
--          return
--       end
--
--       -- Refresh once on attach (async request -> will display when it returns)
--       vim.lsp.codelens.refresh({ bufnr = bufnr })
--
--       -- Keep lenses updated
--       local aug = vim.api.nvim_create_augroup("my-lsp-codelens-" .. bufnr, { clear = true })
--       vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave", "BufWritePost" }, {
--          group = aug,
--          buffer = bufnr,
--          callback = function()
--             -- Important: pass bufnr so Neovim doesn't try other buffers/clients.
--             vim.lsp.codelens.refresh({ bufnr = bufnr })
--          end,
--       })
--
--       -- Keymaps
--       vim.keymap.set("n", "<leader>cl", function()
--          vim.lsp.codelens.refresh({ bufnr = bufnr })
--       end, { buffer = bufnr, desc = "LSP CodeLens: refresh" })
--
--       vim.keymap.set("n", "<leader>cr", function()
--          vim.lsp.codelens.run()
--       end, { buffer = bufnr, desc = "LSP CodeLens: run on line" })
--    end,
-- })

-- -- Enable LSP inlay hints when the server supports them.
-- vim.api.nvim_create_autocmd("LspAttach", {
--    group = vim.api.nvim_create_augroup("my-lsp-inlayhints", { clear = true }),
--    callback = function(args)
--       local bufnr = args.buf
--       local client = vim.lsp.get_client_by_id(args.data.client_id)
--       if not client then
--          return
--       end
--
--       -- Capability guard (different servers/ft)
--       if not client.server_capabilities.inlayHintProvider then
--          return
--       end
--
--       -- Neovim API has changed names across versions; handle both.
--       local ih = vim.lsp.inlay_hint
--       ih.enable(true, { bufnr = bufnr })
--    end,
-- })

vim.api.nvim_create_autocmd("User", {
   pattern = "TSUpdate",
   callback = function()
      vim.fn.setenv("EXTENSION_TAGS", "1")
      vim.fn.setenv("EXTENSION_WIKI_LINK", "1")
      local p = require("nvim-treesitter.parsers")
      p.markdown_inline.install_info.generate = true
      p.markdown_inline.install_info.generate_from_json = false
   end,
})
