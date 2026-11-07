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

local library = { vim.env.VIMRUNTIME }

vim.api.nvim_create_autocmd("VimLeavePre", {
   group = vim.api.nvim_create_augroup("emmylua_force_stop", { clear = true }),
   callback = function()
      for _, client in ipairs(vim.lsp.get_clients({ name = "emmylua_ls" })) do
         client:stop(true)
      end
   end,
})

local PLUGIN_DIR = vim.fs.normalize("~/Plugins/")
local obsidian_nvim_path = vim.fs.joinpath(PLUGIN_DIR, "obsidian.nvim")

if vim.uv.fs_stat(PLUGIN_DIR) ~= nil then
   for name in vim.fs.dir(PLUGIN_DIR) do
      table.insert(library, vim.fs.joinpath(PLUGIN_DIR, name))
   end
end

for _, plugin in ipairs(vim.pack.get()) do
   table.insert(library, plugin.path)
end

---@type vim.lsp.Config
return {
   cmd = { "emmylua_ls", "--communication", "stdio", "--editor", "neovim" },
   cmd_env = vim.uv.fs_stat(obsidian_nvim_path) and { OBSIDIAN_NVIM_PATH = obsidian_nvim_path } or nil,
   filetypes = { "lua" },
   root_markers = { root_markers1, root_markers2, { ".git" } },
   workspace_required = false,
   -- before_init = function(params, config)
   --    -- If the workspace has its own emmylua_ls/lua_ls config file, defer to it.
   --    local path = params.rootPath
   --    if
   --       type(path) == "string"
   --       and path ~= vim.fn.stdpath("config")
   --       and (vim.uv.fs_stat(path .. "/.emmyrc.json") or vim.uv.fs_stat(path .. "/.luarc.json"))
   --    then
   --       -- Neovim copies this table onto the client before before_init runs, so
   --       -- clear it in place instead of replacing config.settings.
   --       for key in pairs(config.settings) do
   --          config.settings[key] = nil
   --       end
   --    end
   -- end,
   settings = {
      emmylua = {
         codeLens = { enable = true },
         hint = { enable = true },
         runtime = { version = "LuaJIT" },
         workspace = { library = library },
      },
   },
}
