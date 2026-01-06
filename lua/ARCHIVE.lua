-- [[Arglist]]
set("n", "[A", "<cmd>first<bar>args<cr><esc>")
set("n", "]A", "<cmd>last<bar>args<cr><esc>")

set("n", "ga", function()
   return ":<C-U>" .. (vim.v.count > 0 and vim.v.count or "") .. "argu|args<cr><esc>"
end, { expr = true })

set("n", "<leader>aa", "<cmd>$arge %<bar>argded<bar>args<cr>")

set("n", "<leader>ad", "<cmd>argd %<bar>args<cr>")
set("n", "<leader>ac", "<cmd>%argd<cr><C-L>")
set("n", "<leader>ap", "<C-L><cmd>args<cr>")

vim.cmd([[
function! NavArglist(count)
    let arglen = argc()
    if arglen == 0
        return
    endif
    let next = fmod(argidx() + a:count, arglen)
    if next < 0
        let next += arglen
    endif
    exe float2nr(next + 1) .. 'argu'
endfunction

"autocmd TabNewEntered * argl|%argd -- TODO:
]])

vim.api.nvim_create_autocmd("TabNewEntered", { command = "argl|%argd" })

-- Move Lines
-- map("n", "<A-j>", "<cmd>execute 'move .+' . v:count1<cr>==", { desc = "Move Down" })
-- map("n", "<A-k>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Move Up" })
-- map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move Down" })
-- map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move Up" })
-- map("v", "<A-j>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move Down" })
-- map("v", "<A-k>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Move Up" })
