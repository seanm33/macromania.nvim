local picker = require("macromania.picker")

vim.api.nvim_create_user_command("MacroAdd", function()
	picker.add_macro()
end, {})

vim.api.nvim_create_user_command("MacroList", function()
	picker.show_picker()
end, {})

vim.api.nvim_create_user_command("MacroHistory", function()
	local catalog = require("macromania")
	picker.show_list(catalog.history(), "History")
end, {})

vim.api.nvim_create_user_command("MacroTag", function(opts)
	local catalog = require("macromania")
	picker.show_list(catalog.filter_by_tag(opts.args), "Tag: " .. opts.args)
end, { nargs = 1 })
