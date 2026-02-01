return {
   cmd = { "lua-language-server" },
   root_markers = {
      ".luarc.json",
      ".luarc.jsonc",
      ".luacheckrc",
      ".stylua.toml",
      "stylua.toml",
      "selene.toml",
      "selene.yml",
      ".git",
   },
   filetypes = { "lua" },
   on_attach = function(client, buf_id)
      -- Reduce very long list of triggers for better 'mini.completion' experience
      client.server_capabilities.completionProvider.triggerCharacters = { ".", ":", "#", "(" }

      -- Use this function to define buffer-local mappings and behavior that depend
      -- on attached client or only makes sense if there is language server attached.
   end,
   -- LuaLS Structure of these settings comes from LuaLS, not Neovim
   settings = {
      Lua = {
         -- Define runtime properties. Use 'LuaJIT', as it is built into Neovim.
         runtime = {
            version = "LuaJIT",
            -- path = vim.split(package.path, ";"),
         },
         hint = { enable = true },
         workspace = {
            -- Don't analyze code from submodules
            -- ignoreSubmodules = true,
            -- Add Neovim's methods for easier code writing
            library = {
               vim.env.VIMRUNTIME,
               vim.fs.joinpath(vim.fn.stdpath("data"), "/site/pack/core/opt", "mini.nvim"),
               vim.fs.joinpath(vim.fn.stdpath("data"), "/site/pack/core/opt", "snacks.nvim"),
               "~/Plugins/obsidian.nvim/",
            },
            -- library = vim.api.nvim_get_runtime_file("", true)
         },
      },
   },
}
