return function(data)
   require("obsidian._base").view({ view = data.args ~= "" and data.args or nil })
end
