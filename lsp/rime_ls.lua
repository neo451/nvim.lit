vim.g.rime_enabled = true

local prose_filetypes = {
   gitcommit = true,
   markdown = true,
   plaintex = true,
   quarto = true,
   text = true,
   tex = true,
   typst = true,
}

local trigger_group = vim.api.nvim_create_augroup("RimeLsTriggers", { clear = false })

local rime_on_attach = function(client, bufnr)
   local toggle_rime = function()
      client.request("workspace/executeCommand", { command = "rime-ls.toggle-rime" }, function(_, result, ctx, _)
         if ctx.client_id == client.id then
            vim.g.rime_enabled = result
         end
      end)
   end

   local sync_rime = function()
      client.request("workspace/executeCommand", { command = "rime-ls.sync-user-data" })
   end

   -- Rime is unprefixed in prose. In source files, prefix a reading with `>`
   -- (for example `>nihc`) so normal language-server completion stays useful.
   local update_trigger = function()
      if client:is_stopped() then
         return
      end
      local trigger = prose_filetypes[vim.bo[bufnr].filetype] and {} or { ">" }
      local settings = { trigger_characters = trigger }
      client.config.settings = settings
      client:notify("workspace/didChangeConfiguration", { settings = settings })
   end

   vim.keymap.set("n", "<leader>rr", toggle_rime, { buffer = bufnr, desc = "Toggle [R]ime" })
   vim.keymap.set("i", "<C-x>", toggle_rime, { buffer = bufnr, desc = "Toggle Rime" })
   vim.keymap.set("n", "<leader>rs", sync_rime, { buffer = bufnr, desc = "[R]ime [S]ync" })
   vim.api.nvim_clear_autocmds({ group = trigger_group, buffer = bufnr })
   vim.api.nvim_create_autocmd("BufEnter", {
      group = trigger_group,
      buffer = bufnr,
      callback = update_trigger,
   })
   update_trigger()
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("blink.cmp").get_lsp_capabilities(capabilities)

local rime_shared_data_dir = vim.env.RIME_DATA_DIR or "/usr/share/rime-data"
local rime_user_data_dir = vim.env.RIME_LS_USER_DATA_DIR or vim.fn.expand("~/.local/share/rime-ls")

---@type vim.lsp.Config
return {
   name = "rime_ls",
   cmd = { "rime_ls" },
   init_options = {
      enabled = vim.g.rime_enabled,
      shared_data_dir = rime_shared_data_dir,
      user_data_dir = rime_user_data_dir,
      log_dir = "/tmp",
      max_candidates = 9,
      paging_characters = { "-", "=", ",", "." },
      trigger_characters = {},
      schema_trigger_character = "&",
      max_tokens = 0,
      always_incomplete = false,
      preselect_first = false,
      show_filter_text_in_label = false,
      long_filter_text = true,
      show_order_in_label = true,
   },
   on_attach = rime_on_attach,
   capabilities = capabilities,
}
