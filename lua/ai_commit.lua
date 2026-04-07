local M = {}

local prompts = {
  commit = [[Based on this git diff, generate a single conventional commit message.
Format: type(scope): description
Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- Scope is optional, use only when changes are clearly focused on one area
- Keep the subject line under 72 characters
- Be specific and concise
- Output ONLY the raw commit message, no markdown fences, no explanation, no extra text]],

  pr = [[Based on this git diff, generate a detailed conventional commit message suitable for a PR merge commit.
Format:
type(scope): short description

- bullet point explaining a change
- another bullet point
- ...

BREAKING CHANGE: description (only if applicable)

Rules:
- Use conventional commit types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- Scope is optional
- Keep subject line under 72 characters
- Wrap body lines at 72 characters
- Use bullet points (- ) for each logical change
- Include BREAKING CHANGE footer only if there are breaking changes
- Output ONLY the raw commit message, no markdown fences, no explanation, no extra text]],
}

--- Strip markdown code fences that models tend to wrap around output.
---@param text string
---@return string
local function strip_fences(text)
  -- remove leading ```<lang>\n and trailing \n```
  text = text:gsub("^%s*```[^\n]*\n", "")
  text = text:gsub("\n```%s*$", "")
  -- also handle the case where the whole thing is fenced on one line
  text = text:gsub("^%s*```(.-)```%s*$", "%1")
  return vim.trim(text)
end

--- Get the staged diff, falling back to diff against HEAD.
---@return string? diff
---@return string? error
local function get_diff()
  local result = vim.system({ "git", "diff", "--cached" }):wait()
  if result.code ~= 0 then
    return nil, "git diff --cached failed: " .. (result.stderr or "unknown error")
  end
  if result.stdout and result.stdout ~= "" then
    return result.stdout, nil
  end
  -- fallback for amend workflows where nothing is staged
  result = vim.system({ "git", "diff", "HEAD" }):wait()
  if result.code ~= 0 then
    return nil, "git diff HEAD failed: " .. (result.stderr or "unknown error")
  end
  if result.stdout and result.stdout ~= "" then
    return result.stdout, nil
  end
  return nil, "No staged or unstaged changes found"
end

--- Build the full prompt string.
---@param style "commit"|"pr"
---@param hint? string
---@return string
local function build_prompt(style, hint)
  local base = prompts[style] or prompts.commit
  if hint and hint ~= "" then
    return base .. "\n\nAdditional context: " .. hint
  end
  return base
end

--- Present the generated message and let the user choose an action.
---@param message string
---@param bufnr number
local function preview_and_act(message, bufnr)
  vim.notify(message, vim.log.levels.INFO, { title = "AI Commit" })
  vim.ui.select({ "Insert", "Clipboard", "Discard" }, {
    prompt = "Commit message action:",
  }, function(choice)
    if not choice or choice == "Discard" then
      return
    end
    if choice == "Clipboard" then
      vim.fn.setreg("+", message)
      vim.notify("Copied to clipboard", vim.log.levels.INFO, { title = "AI Commit" })
      return
    end
    if choice == "Insert" then
      if not vim.api.nvim_buf_is_valid(bufnr) then
        vim.notify("Buffer no longer valid", vim.log.levels.ERROR, { title = "AI Commit" })
        return
      end
      local lines = vim.split(message, "\n", { plain = true })
      -- find the first comment line (starts with #) to know where to insert
      local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local insert_end = 0
      for i, line in ipairs(buf_lines) do
        if line:match("^#") then
          insert_end = i - 1
          break
        end
        insert_end = i
      end
      -- replace everything before the first comment line
      vim.api.nvim_buf_set_lines(bufnr, 0, insert_end, false, lines)
      vim.notify("Inserted", vim.log.levels.INFO, { title = "AI Commit" })
    end
  end)
end

--- Core generation function.
---@param style "commit"|"pr"
---@param hint? string
local function generate(style, hint)
  if vim.fn.executable("opencode") ~= 1 then
    vim.notify("opencode not found in PATH", vim.log.levels.ERROR, { title = "AI Commit" })
    return
  end

  local diff, err = get_diff()
  if not diff then
    vim.notify(err or "Failed to get diff", vim.log.levels.WARN, { title = "AI Commit" })
    return
  end

  local tmpfile = vim.fn.tempname() .. ".diff"
  vim.fn.writefile(vim.split(diff, "\n", { plain = true }), tmpfile)

  local prompt = build_prompt(style, hint)
  local bufnr = vim.api.nvim_get_current_buf()

  vim.notify("Generating commit message...", vim.log.levels.INFO, { title = "AI Commit" })

  vim.system(
    { "opencode", "run", "--file", tmpfile, prompt },
    {},
    vim.schedule_wrap(function(result)
      vim.fn.delete(tmpfile)

      if result.code ~= 0 then
        vim.notify(
          "opencode failed (exit " .. result.code .. "): " .. (result.stderr or ""),
          vim.log.levels.ERROR,
          { title = "AI Commit" }
        )
        return
      end

      local output = result.stdout or ""
      output = strip_fences(output)

      if output == "" then
        vim.notify("AI returned an empty response", vim.log.levels.WARN, { title = "AI Commit" })
        return
      end

      preview_and_act(output, bufnr)
    end)
  )
end

--- Setup the buffer-local :AICommit command.
function M.setup()
  vim.api.nvim_buf_create_user_command(0, "AICommit", function(opts)
    local arg = vim.trim(opts.args or "")

    if arg == "commit" then
      generate("commit")
    elseif arg == "pr" then
      generate("pr")
    elseif arg ~= "" then
      -- anything else is treated as a custom hint
      generate("commit", arg)
    else
      -- no argument: interactive select
      vim.ui.select({ "commit", "pr", "custom..." }, {
        prompt = "Commit message style:",
      }, function(choice)
        if not choice then
          return
        end
        if choice == "custom..." then
          vim.ui.input({ prompt = "Hint: " }, function(input)
            if input and input ~= "" then
              generate("commit", input)
            end
          end)
        else
          generate(choice)
        end
      end)
    end
  end, {
    nargs = "?",
    desc = "Generate a conventional commit message with AI (opencode)",
    complete = function()
      return { "commit", "pr" }
    end,
  })
end

return M
