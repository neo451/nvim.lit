require("blink.cmp").setup({
   completion = {
      menu = {
         draw = {
            columns = {
               { "label", "label_description", gap = 3 },
               { "kind" },
            },
         },
      },
      documentation = { auto_show = true },
   },

   cmdline = {
      enabled = false,
   },

   sources = {
      default = {
         "lsp",
         "path",
         "snippets",
         "buffer",
      },
      per_filetype = {
         markdown = {
            "lsp",
            "dictionary",
         },
         sql = { "snippets", "dadbod", "buffer" },
      },
      providers = {
         lsp = {
            transform_items = function(_, items)
               -- the default transformer will do this
               for _, item in ipairs(items) do
                  if item.kind == require("blink.cmp.types").CompletionItemKind.Snippet then
                     item.score_offset = item.score_offset - 3
                  end
               end
               -- you can define your own filter for rime item
               return items
            end,
         },
         dadbod = {
            name = "Dadbod",
            module = "vim_dadbod_completion.blink",
         },
         -- Use the dictionary source
         dictionary = {
            name = "blink-cmp-words",
            module = "blink-cmp-words.dictionary",
            -- All available options
            opts = {
               -- The number of characters required to trigger completion.
               -- Set this higher if completion is slow, 3 is default.
               dictionary_search_threshold = 3,
               -- See above
               score_offset = 0,
               -- See above
               definition_pointers = { "!", "&", "^" },
            },
         },
      },
   },
})
