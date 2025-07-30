require("obsidian").setup({
	-- Optional, customize how note IDs are generated given an optional title.
	-- @param title string|?
	-- @return string
	note_id_func = function(title)
		local name = ""
		if title ~= nil then
			-- If title is given, transform it into valid file name.
			name = title:gsub(" ", "-"):gsub("[^A-Za-z0-9_-]", ""):lower()
		else
			-- If title is nil, just add 4 random uppercase letters to the suffix.
			for _ = 1, 4 do
				name = name .. string.char(math.random(65, 90))
			end
		end
		return name
		-- return os.date("%Y%m%d%H%M%S")
	end,
	-- Optional, customize how note file names are generated given the ID, target directory, and title.
	-- @param spec { id: string, dir: obsidian.Path, title: string|? }
	-- @return string|obsidian.Path The full path to the new note.
	note_path_func = function(spec)
		local path
		if spec.title ~= nil then
			local title = tostring(spec.title:gsub(" ", "-"):gsub("[^A-Za-z0-9_-]", ""):lower())
			path = spec.dir / title
		else
			-- This is equivalent to the default behaviour.
			path = spec.dir / tostring(spec.id)
		end
		return path:with_suffix(".md")
	end,
	legacy_commands = false,
	-- prefer_config_from_obsidian_app = true,

	comment = {
		enabled = true,
	},

	checkbox = {
		order = { "x", " " },
		create_new = false,
	},

	open = {
		use_advanced_uri = true,
		func = function(uri)
			vim.ui.open(uri, { cmd = { "wsl-open" } })
		end,
	},
	--
	-- daily_notes = {
	-- 	folder = "daily_notes",
	-- 	date_format = "%Y/%m/%Y-%m-%d-%A",
	-- 	-- func = function(datetime)
	-- 	--   local note = os.date("%Y/%m-%B/%Y-%m-%d", datetime)
	-- 	--   return "daily_notes/" .. note .. "!.md"
	-- 	-- end,
	-- },
	daily_notes = {
		date_format = "%Y-%m-%d",
		-- template = "journaling-daily-note.md",
		folder = "10-areas/journaling/daily",
		workdays_only = true,
	},

	calendar = {
		cmd = "CalendarT",
		close_after = true,
	},

	picker = {
		name = "telescope.nvim",
	},

	attachments = {
		confirm_img_paste = false,
		img_folder = "./imgs",
	},

	-- note_id_func = function(title)
	-- 	return title
	-- end,

	templates = {
		folder = "templates",
		date_format = "%Y-%m-%d",
		time_format = "%H:%M",
		customizations = {
			zettel = {
				dir = "zettel",
				note_id_func = function(title)
					return "my-cool-id+" .. title
				end,
			},
		},
	},

	completion = {
		blink = true,
		nvim_cmp = false,
		-- blink = vim.g.my_cmp == "blink",
		-- nvim_cmp = vim.g.my_cmp == "cmp",
	},

	workspaces = {
		{
			name = "notes",
			path = "~/Vaults/Notes",
		},
		{
			name = "cosma-test",
			path = "~/Vaults/cosma-test/",
		},
		{
			name = "work",
			path = "~/Vaults/Work",
		},
		{
			name = "hub",
			path = "~/Vaults/obsidian-hub/",
		},
		-- {
		--   name = "stress test",
		--   path = "~/.local/share/nvim/nightmare_vault/",
		-- },
	},
})
