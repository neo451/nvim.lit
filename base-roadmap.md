# Obsidian Bases mode roadmap

This is a roadmap for turning the Neovim `.base` support into a more usable, Obsidian-app-like Bases mode.

## Near-term improvements

### 1. Real table selection model ✅

Track `row_index` and `column_index` in buffer-local state instead of relying only on Morph cell mappings.

Desired behavior:

- `j` / `k`: move rows
- `h` / `l`: move columns
- `gg` / `G`: first/last row
- current row/cell highlight
- row actions work from anywhere on the line

Suggested state:

```lua
vim.b.obsidian_base_model
vim.b.obsidian_base_selected_row
vim.b.obsidian_base_selected_col
vim.b.obsidian_base_runtime_filter
vim.b.obsidian_base_runtime_sort
```

### 2. Inline property editing ✅

Press `e` or `i` on a cell to edit that frontmatter/property value and write it back to the note.

Supported first:

- strings
- numbers
- booleans
- dates
- tags/list values

Important details:

- preserve existing YAML formatting when possible
- validate type before write
- refresh the table after saving
- mark unsupported/computed columns read-only

### 3. Stronger filter evaluation

Current query extraction is intentionally small. Add real evaluation for more Bases expressions.

Useful filters:

```text
file.inFolder("Projects")
file.hasTag("project")
file.name.contains("plan")
note.status == "active"
note.priority != "low"
note.rating >= 4
note.done == false
note.due <= today()
```

Implementation idea:

- parse expressions into AST
- evaluate AST against each loaded note
- keep folder/tag extraction as an optimization for scanning fewer files

### 4. Better sorting

Expand sorting support to include:

- runtime sort by current column
- reverse sort
- stable multi-column sort
- natural string sort
- date-aware sort
- nil/empty placement options

Keys:

```text
S: sort current column
R: reverse current sort
```

### 5. Column management

Add a column picker:

```vim
:Obsidian base columns
```

Features:

- discover metadata keys from visible notes
- toggle columns
- reorder columns
- resize columns
- optionally persist changes back to `.base`

### 6. Persist runtime edits back to `.base`

Eventually support:

```vim
:Obsidian base save
```

Persist:

- selected columns/order
- column widths
- sort order
- filters
- view rename

This needs a YAML update layer that preserves comments and formatting if possible.

### 7. Preview pane

Add a preview mode similar to picker/list-detail UIs:

```text
p: floating preview
P: persistent side preview
```

Nice layout:

```text
base table | note preview
```

### 8. Fuzzy row search

Add:

```vim
:Obsidian base find
```

Search across visible row values and open the selected note.

### 9. Smarter note creation

Improve `base create` / `a`:

- infer default field values from filters, not only tags/folder
- prompt for required fields
- support templates
- allow create-without-leaving-table
- refresh table after note creation

### 10. More Obsidian-compatible fields

Add special columns:

```text
file.basename
file.ext
file.ctime
file.mtime
file.size
file.link
file.outlinks
file.inlinks
```

### 11. Rich renderers

Render values in a more Obsidian-like way:

- tags as highlighted `#tag`
- booleans as checkmarks
- dates with overdue/today/future highlights
- links as navigable cells
- missing values dimmed

## Long-term goal

A usable Bases mode should feel like a lightweight database view over the vault:

- fast to open
- keyboard-first
- editable where safe
- close to Obsidian's Bases semantics
- resilient to partial/unsupported `.base` syntax
- useful even before full feature parity
