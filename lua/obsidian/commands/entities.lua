local api = require("obsidian.api")
local entities = require("obsidian.entities")
local log = require("obsidian.log")

local M = {}

local categories = {
   { id = "place", label = "Place" },
   { id = "person", label = "Person" },
   { id = "thing", label = "Thing" },
}

local aliases = {
   places = "place",
   people = "person",
   other = "thing",
}

local function trim(value)
   return vim.trim(value or "")
end

local function prompt_query(kind, supplied)
   local query = trim(supplied)
   if query == "" then
      query = trim(api.input(kind:gsub("^%l", string.upper) .. " name", {}))
   end
   if query == "" then
      log.info("Aborted")
      return nil
   end
   return query
end

local function run(kind, supplied)
   local query = prompt_query(kind, supplied)
   if not query then
      return
   end

   if kind == "place" then
      entities.create_place(query, function() end)
   elseif kind == "person" then
      entities.create_person(kind, query)
   else
      entities.create_thing(query)
   end
end

local function choose_category(supplied)
   vim.ui.select(categories, {
      prompt = "Entity type",
      format_item = function(item)
         return item.label
      end,
   }, function(item)
      if not item then
         log.info("Aborted")
         return
      end
      run(item.id, supplied)
   end)
end

---@param data obsidian.CommandArgs
function M.command(data)
   local args = trim(data.args)
   if args == "" then
      choose_category("")
      return
   end

   local parts = vim.split(args, "%s+", { trimempty = true })
   local requested = parts[1]:lower()
   local kind = aliases[requested] or requested
   local supplied

   if kind == "place" or kind == "person" or kind == "thing" then
      supplied = table.concat(parts, " ", 2)
      run(kind, supplied)
   else
      choose_category(args)
   end
end

function M.complete(arg_lead)
   local completions = { "place", "person", "thing", "places", "people", "other" }
   return vim.tbl_filter(function(value)
      return vim.startswith(value, arg_lead)
   end, completions)
end

return setmetatable(M, {
   __call = function(_, data)
      return M.command(data)
   end,
})
