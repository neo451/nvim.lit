### 1. Typing lag is primarily Obsidian inlay hints—not Rime

In lua/autocmds.lua, every obsidian-ls attachment enables inlay
hints:

```lua
  vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
```

Each keystroke then requests inlay hints. The handler reconstructs
the entire note even though no hint resolver is currently configured.

On 451notes.md:

- Current median keystroke: ~627 ms
- obsidian-ls inlay-hint work: ~575 ms per keystroke
- With inlay hints disabled: ~51 ms
- With inlay hints and Markdown Plus renumbering disabled: ~17 ms

Rime itself made no meaningful difference in this benchmark.

A secondary slowdown comes from Markdown Plus scanning ±20 lines for
ordered lists on every TextChangedI. This is unusually expensive
because the note contains inline base64 image lines of approximately
41 KB, 145 KB, and 459 KB.

There is also a one-time delay when Blink first loads on the first
insert session, but it is not the recurring lag.

### 2. Full-width punctuation cause confirmed

paging_characters currently advertises:

```lua
  { "-", "=", ",", "." }
```

This makes comma and period trigger Rime completion. Reproduction:

```text
  nihc<Space>  → 你好
  ,            → Rime offers ，
  ni           → no useful Rime candidates
```

With comma/period removed from Rime’s trigger characters:

```text
  nihc<Space>  → 你好
  ,            → literal comma, no completion
  ni           → Rime candidates appear normally
```

For complete punctuation suppression, I recommend paging_characters =
{}. The tradeoff is losing Rime’s punctuation-based candidate paging;
Blink’s normal candidate navigation remains available.

### 3. Current toggle mapping is not Vim-native

<C-x> is Vim’s built-in insert-completion prefix and is also
registered with mini.clue. It should not be used to toggle Rime.

I do not recommend <C-S-r>:

- Many terminals cannot distinguish it from <C-r>.
- Normal <C-r> is redo.
- Insert <C-r> inserts a register.

Proposed plan

1. Remove automatic Obsidian inlay hints
   - Remove the obsidian-ls automatic enable in lua/autocmds.lua.
   - Keep the existing manual <leader>H toggle.
   - No functionality is currently lost because the hint resolver in
     _obsidian.lua is commented out.

2. Mitigate Markdown Plus scanning
   - Recommended immediate workaround: disable its automatic
     list-renumber autocmd in Markdown buffers containing inline
     base64 images.
   - Keep its list mappings and manual operations.
   - Longer-term: move embedded base64 images to attachment files or
     patch Markdown Plus to skip enormous lines.

3. Suppress Rime punctuation completions
   - Set paging_characters = {} in lsp/rime_ls.lua.
   - Add a regression check for:
     nihc → accept → comma → ni, ensuring comma stays ASCII and Rime
     resumes afterward.

4. Make Rime default off
   - Set vim.g.rime_enabled = false.
   - Keep the server attached so toggling remains immediate.
   - Redraw the statusline and optionally notify after toggle
     completion.

5. Replace the toggle mappings
   - Remove insert <C-x>.
   - My recommendation:
     - Normal: <leader>rr
     - Insert: <C-g>r
   - This preserves Vim’s native completion, register, and redo
     keys.

   Other reasonable options:

   ┌─────────────────┬─────────────────────┬────────────────────────┐
   │ Mapping │ Advantages │ Drawbacks │
   ├─────────────────┼─────────────────────┼────────────────────────┤
   │ <M-r> in normal │ Same mnemonic │ Meta handling varies │
   │ + insert │ chord, usually │ by terminal │
   │ │ unbound │ │
   ├─────────────────┼─────────────────────┼────────────────────────┤
   │ <C-Space> in │ Familiar IME toggle │ May be intercepted; │
   │ normal + insert │ │ aliases <C-@> in some │
   │ │ │ terminals │
   ├─────────────────┼─────────────────────┼────────────────────────┤
   │ <F8> in normal │ Highly reliable │ Less mnemonic │
   │ + insert │ │ │
   ├─────────────────┼─────────────────────┼────────────────────────┤
   │ <leader>rr + │ Most Vim-native and │ Different mappings by │
   │ <C-g>r │ terminal-safe │ mode │
   └─────────────────┴─────────────────────┴────────────────────────┘

6. Small cleanup
   - Consider hiding numeric prefixes with show_order_in_label =
     false if normal Blink navigation is preferred.
   - Ensure the ; Rime candidate mapping and the global ;<C-g>u
     mapping do not conflict.
   - Add :RimeToggle / :RimeSync commands so mappings are optional
     and discoverable.

7. Verify
   - Repeat the per-keystroke benchmark on both the large note and a
     regular Markdown note.
   - Confirm Rime starts disabled.
   - Confirm punctuation remains literal.
   - Confirm <C-x>, <C-r>, and redo retain native behavior.
   - Run a headless config startup check.

No tracked files have been changed yet. My recommended mapping choice
is <leader>rr in normal mode and <C-g>r in insert mode.
