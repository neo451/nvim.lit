local h = dofile "tests/helpers.lua"
local T, child = h.child_vault()
local eq = MiniTest.expect.equality

local function open_note()
  local files = h.mock_vault_contents(child.Obsidian.dir, { ["paste.md"] = "hello" })
  child.cmd("edit! " .. vim.fn.fnameescape(files["paste.md"]))
  h.child_wait(child, [[return vim.fn.maparg("p", "x", false, true).buffer == 1]], { desc = "visual paste mapping" })
end

local function paste(keys)
  child.lua(([[
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(%q, true, false, true), "xt", false)
  ]]):format(keys))
end

T["pastes a URI as a Markdown link over the visual selection"] = function()
  open_note()
  child.lua [[vim.fn.setreg('"', "https://example.com/docs")]]
  paste "0vllp"
  eq("[hel](<https://example.com/docs>)lo", child.lua_get [[vim.api.nvim_get_current_line()]])
end

T["delegates non-URI visual paste to the selected native register"] = function()
  open_note()
  child.lua [[vim.fn.setreg('a', "replacement")]]
  paste '0vll"ap'
  eq("replacementlo", child.lua_get [[vim.api.nvim_get_current_line()]])
end

return T
