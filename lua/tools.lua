local tools

local remote_cache, branch_cache = {}, {}

local function git_cmd(root, ...)
   local job = vim.system({ "git", "-C", root, ... }, { text = true }):wait()

   if job.code ~= 0 then
      return nil, job.stderr
   end
   return vim.trim(job.stdout)
end

tools = {
   ui = {
      icons = {
         branch = "",
         bullet = "•",
         open_bullet = "○",
         ok = "✔",
         d_chev = "∨",
         ellipses = "…",
         node = "╼",
         document = "≡",
         lock = "",
         r_chev = ">",
         warning = " ",
         error = " ",
         info = "󰌶 ",
      },
      kind_icons = {
         Array = " 󰅪 ",
         BlockMappingPair = " 󰅩 ",
         Boolean = "  ",
         BreakStatement = " 󰙧 ",
         Call = " 󰃷 ",
         CaseStatement = " 󰨚 ",
         Class = "  ",
         Color = "  ",
         Constant = "  ",
         Constructor = " 󰆧 ",
         ContinueStatement = "  ",
         Copilot = "  ",
         Declaration = " 󰙠 ",
         Delete = " 󰩺 ",
         DoStatement = " 󰑖 ",
         Element = " 󰅩 ",
         Enum = "  ",
         EnumMember = "  ",
         Event = "  ",
         Field = "  ",
         File = "  ",
         Folder = "  ",
         ForStatement = "󰑖 ",
         Function = " 󰆧 ",
         GotoStatement = " 󰁔 ",
         Identifier = " 󰀫 ",
         IfStatement = " 󰇉 ",
         Interface = "  ",
         Keyword = "  ",
         List = " 󰅪 ",
         Log = " 󰦪 ",
         Lsp = "  ",
         Macro = " 󰁌 ",
         MarkdownH1 = " 󰉫 ",
         MarkdownH2 = " 󰉬 ",
         MarkdownH3 = " 󰉭 ",
         MarkdownH4 = " 󰉮 ",
         MarkdownH5 = " 󰉯 ",
         MarkdownH6 = " 󰉰 ",
         Method = " 󰆧 ",
         Module = " 󰅩 ",
         Namespace = " 󰅩 ",
         Null = " 󰢤 ",
         Number = " 󰎠 ",
         Object = " 󰅩 ",
         Operator = "  ",
         Package = " 󰆧 ",
         Pair = " 󰅪 ",
         Property = "  ",
         Reference = "  ",
         Regex = "  ",
         Repeat = " 󰑖 ",
         Return = " 󰌑 ",
         RuleSet = " 󰅩 ",
         Scope = " 󰅩 ",
         Section = " 󰅩 ",
         Snippet = "  ",
         Specifier = " 󰦪 ",
         Statement = " 󰅩 ",
         String = "  ",
         Struct = "  ",
         SwitchStatement = " 󰨙 ",
         Table = " 󰅩 ",
         Terminal = "  ",
         Text = " 󰀬 ",
         Type = "  ",
         TypeParameter = "  ",
         Unit = "  ",
         Value = "  ",
         Variable = "  ",
         WhileStatement = " 󰑖 ",
      },
   },
   nonprog_modes = {
      ["markdown"] = true,
      ["org"] = true,
      ["orgagenda"] = true,
      ["text"] = true,
   },
   -- highlighting -----------------------------
   hl_str = function(hl, str)
      return "%#" .. hl .. "#" .. str .. "%*"
   end,
   get_path_root = function(path)
      if path == "" then
         return
      end

      local root = vim.b.path_root
      if root then
         return root
      end

      local root_items = {
         ".git",
      }

      root = vim.fs.root(path, root_items)
      if root == nil then
         return nil
      end
      if root then
         vim.b.path_root = root
      end
      return root
   end,
   get_git_remote_name = function(root)
      if not root then
         return nil
      end
      if remote_cache[root] then
         return remote_cache[root]
      end

      local out = git_cmd(root, "config", "--get", "remote.origin.url")
      if not out then
         return nil
      end

      -- normalise to short repo name
      out = out:gsub(":", "/"):gsub("%.git$", ""):match("([^/]+/[^/]+)$")

      remote_cache[root] = out
      return out
   end,

   get_git_branch = function(root)
      if not root then
         return nil
      end
      if branch_cache[root] then
         return branch_cache[root]
      end

      local out = git_cmd(root, "rev-parse", "--abbrev-ref", "HEAD")
      if out == "HEAD" then
         local commit = git_cmd(root, "rev-parse", "--short", "HEAD")
         commit = tools.hl_str("Comment", "(" .. commit .. ")")
         out = string.format("%s %s", out, commit)
      end

      branch_cache[root] = out

      return out
   end,
   diagnostics_available = function()
      local clients = vim.lsp.get_clients({ bufnr = 0 })
      local diagnostics = vim.lsp.protocol.Methods.textDocument_publishDiagnostics

      for _, cfg in pairs(clients) do
         if cfg:supports_method(diagnostics) then
            return true
         end
      end

      return false
   end,
   group_number = function(num, sep)
      if num < 999 then
         return tostring(num)
      end

      num = tostring(num)
      return num:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse():gsub("^,", "")
   end,
}

return tools
