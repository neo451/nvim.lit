## xieyonn/spinner.nvim

```lua
require("spinner").setup({})
```

## nvim-lua/plenary.nvim

## igorlfs/nvim-lsp-file-operations

```lua
require("lsp-file-operations").setup({})
```

## neovim/nvim-lspconfig

```lua
local lspconfig = require("lspconfig")

-- Set global defaults for all servers
lspconfig.util.default_config = vim.tbl_extend("force", lspconfig.util.default_config, {
   capabilities = vim.tbl_deep_extend(
      "force",
      vim.lsp.protocol.make_client_capabilities(),
      -- returns configured operations if setup() was already called
      -- or default operations if not
      require("lsp-file-operations").default_capabilities()
   ),
})
```

## gregorias/coop.nvim

- lazy: `true`

## nvim-telescope/telescope.nvim

- lazy: `true`

## ibhagwan/fzf-lua

- lazy: `true`

## nvim-treesitter/nvim-treesitter

- version: `main`
