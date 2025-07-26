require("obsidian").setup({
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

	daily_notes = {
		folder = "daily_notes",
		date_format = "%Y/%m/%Y-%m-%d-%A",
		-- func = function(datetime)
		--   local note = os.date("%Y/%m-%B/%Y-%m-%d", datetime)
		--   return "daily_notes/" .. note .. "!.md"
		-- end,
	},

	calendar = {
		cmd = "CalendarT",
		close_after = true,
	},

	picker = {
		name = "snacks.pick",
	},

	attachments = {
		confirm_img_paste = false,
		img_folder = "./imgs",
	},

	note_id_func = function(title)
		return title
	end,

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
		blink = false,
		nvim_cmp = false,
		-- blink = vim.g.my_cmp == "blink",
		-- nvim_cmp = vim.g.my_cmp == "cmp",
	},

	workspaces = {
		{
			name = "notes",
			path = "~/Notes",
		},
		{
			name = "cosma-test",
			path = "~/cosma-test/",
		},
		-- {
		--   name = "work",
		--   path = "~/Work",
		-- },
		{
			-- name = "hub",
			path = "~/obsidian-hub/",
		},
		-- {
		--   name = "stress test",
		--   path = "~/.local/share/nvim/nightmare_vault/",
		-- },
	},
})
