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

-- Avoid a stale local build earlier in $PATH. On this Nix machine it points at
-- an old glibc store path and fails direct execution.
local emmylua_cmd = vim.fs.joinpath("/etc/profiles/per-user", vim.env.USER, "bin", "emmylua_ls")
if vim.fn.executable(emmylua_cmd) ~= 1 then
   emmylua_cmd = "emmylua_ls"
end

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

---@type vim.lsp.Config
return {
   cmd = { emmylua_cmd, "--communication", "stdio", "--editor", "neovim" },
   cmd_env = vim.uv.fs_stat(obsidian_nvim_path) and { OBSIDIAN_NVIM_PATH = obsidian_nvim_path } or nil,
   filetypes = { "lua" },
   root_markers = { root_markers1, root_markers2, { ".git" } },
   workspace_required = false,

   before_init = function(params, config)
      -- If the workspace has its own emmylua_ls/lua_ls config file, defer to it.
      local path = params.rootPath
      if
         type(path) == "string"
         and path ~= vim.fn.stdpath("config")
         and (vim.uv.fs_stat(path .. "/.emmyrc.json") or vim.uv.fs_stat(path .. "/.luarc.json"))
      then
         -- Neovim copies this table onto the client before before_init runs, so
         -- clear it in place instead of replacing config.settings.
         for key in pairs(config.settings) do
            config.settings[key] = nil
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
