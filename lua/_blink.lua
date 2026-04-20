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
         markdown = { "dictionary" },
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
         -- Use the thesaurus source
         thesaurus = {
            name = "blink-cmp-words",
            module = "blink-cmp-words.thesaurus",
            -- All available options
            opts = {
               -- A score offset applied to returned items.
               -- By default the highest score is 0 (item 1 has a score of -1, item 2 of -2 etc..).
               score_offset = 0,

               -- Default pointers define the lexical relations listed under each definition,
               -- see Pointer Symbols below.
               -- Default is as below ("antonyms", "similar to" and "also see").
               definition_pointers = { "!", "&", "^" },

               -- The pointers that are considered similar words when using the thesaurus,
               -- see Pointer Symbols below.
               -- Default is as below ("similar to", "also see" }
               similarity_pointers = { "&", "^" },

               -- The depth of similar words to recurse when collecting synonyms. 1 is similar words,
               -- 2 is similar words of similar words, etc. Increasing this may slow results.
               similarity_depth = 2,
            },
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
