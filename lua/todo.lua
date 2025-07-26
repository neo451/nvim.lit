local api = vim.api

local expanded = true

local state = {
  win = nil,
  buf = nil,
}

---@param config vim.api.keyset.win_config
local function update(config)
  api.nvim_win_set_config(state.win, config)
end

local function open()
  local buf = api.nvim_create_buf(false, true)
  local win = api.nvim_open_win(buf, false, {
    anchor = "SE",
    relative = "editor",
    row = 0,
    col = vim.o.columns,
    width = math.floor(vim.o.columns / 4),
    height = math.floor(vim.o.lines / 4),
    style = "minimal",
  })
  state.win = win
  state.buf = buf

  vim.wo[win].statuscolumn = ""
  vim.wo[win].signcolumn = "no"
  vim.api.nvim_win_call(win, function()
    vim.cmd.edit("/home/n451/Notes/TODO.md")
    vim.api.nvim_win_set_cursor(state.win, { 7, 0 })
    vim.cmd("norm zt")
    update({ height = api.nvim_buf_line_count(state.buf) - 6 })
  end)
end

vim.keymap.set("n", "<leader>D", function()
  if expanded then
    update({ height = 1 })
    expanded = false
  else
    vim.api.nvim_win_call(state.win, function()
      vim.cmd("norm zt")
      update({ height = api.nvim_buf_line_count(state.buf) - 6 })
    end)
    expanded = true
  end
end)

return open
