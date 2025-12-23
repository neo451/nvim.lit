return {
   cmd = { "emmylua_ls" },
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

   settings = {
      Lua = {
         runtime = {
            version = "LuaJIT",
         },
         workspace = {
            library = {
               vim.env.VIMRUNTIME,
               -- vim.fs.joinpath(vim.fn.stdpath("data"), "/site/pack/core/opt", "mini.nvim"),
               -- vim.fs.joinpath(vim.fn.stdpath("data"), "/site/pack/core/opt", "snacks.nvim"),
               -- "~/Plugins/obsidian.nvim/",
            },
            -- library = vim.api.nvim_get_runtime_file("", true)
         },
      },
   },
}
