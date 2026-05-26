local function open_yt()
   local cword = vim.fn.expand("<cword>")
   local url = "https://www.youtube.com/watch?v=" .. cword
   vim.ui.open(url)
end

vim.keymap.set("n", "<cr>", open_yt)
