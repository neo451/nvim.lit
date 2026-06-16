local root_markers1 = {
   ".emmyrc.json",
   ".emmyrc.lua",
   ".luarc.json",
   ".luarc.jsonc",
}
local root_markers2 = {
   ".luacheckrc",
   ".stylua.toml",
   "stylua.toml",
   "selene.toml",
   "selene.yml",
}

local library = {
   vim.env.VIMRUNTIME,
   -- For LSP Settings Type Annotations: https://github.com/neovim/nvim-lspconfig#lsp-settings-type-annotations
   vim.api.nvim_get_runtime_file("lua/lspconfig", false)[1],
}
local PLUGIN_DIR = vim.fs.normalize("~/Plugins/")

if vim.uv.fs_stat(PLUGIN_DIR) ~= nil then
   for name in vim.fs.dir(PLUGIN_DIR) do
      table.insert(library, vim.fs.joinpath(PLUGIN_DIR, name))
   end
end

---@type vim.lsp.Config
return {
   cmd = { "emmylua_ls" },
   filetypes = { "lua" },
   root_markers = vim.fn.has("nvim-0.11.3") == 1 and { root_markers1, root_markers2, { ".git" } }
      or vim.list_extend(vim.list_extend(root_markers1, root_markers2), { ".git" }),
   workspace_required = false,

   on_init = function(client)
      -- If the workspace has its own emmylua_ls/lua_ls config file, defer to it.
      if client.workspace_folders then
         local path = client.workspace_folders[1].name
         if
            path ~= vim.fn.stdpath("config")
            and (vim.uv.fs_stat(path .. "/.emmyrc.json") or vim.uv.fs_stat(path .. "/.luarc.json"))
         then
            client.config.settings = {}
         end
      end
   end,
   settings = {
      emmylua = {
         codeLens = { enable = true },
         hint = { enable = true },
         -- Tell the server which Lua you're using (usually LuaJIT, for Neovim).
         runtime = { version = "LuaJIT" },
         diagnostics = { globals = { "vim" } },
         -- Make the server aware of Neovim runtime files.
         workspace = {
            library = library,
         },
      },
   },
}
