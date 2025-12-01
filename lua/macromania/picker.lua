local catalog = require("macromania")
local fzf = require("fzf-lua")

local M = {}

-------------------------------------------------------
-- Register helpers
-------------------------------------------------------

local function detect_macro_register()
	local rec = vim.fn.reg_recording()
	if rec ~= "" then
		return rec
	end
	local exec = vim.fn.reg_executing()
	if exec ~= "" then
		return exec
	end
	return "q"
end

local function validate_register(input, default)
	if not input or input == "" then
		return default
	end
	input = input:match("^%s*(.-)%s*$")
	return (#input == 1) and input or nil
end

-------------------------------------------------------
-- Picker utilities
-------------------------------------------------------

local function extract_name(item)
	if type(item) ~= "string" then
		return nil
	end
	local name = item:match("^(.-)│")
	return name and vim.trim(name) or nil
end

local function find_macro(name, list)
	for _, m in ipairs(list) do
		if m.name == name then
			return m
		end
	end
end

local function build_entries(macros)
	local entries = {}
	for _, m in ipairs(macros) do
		local tags = m.tags and table.concat(m.tags, ",") or ""
		local fts = (type(m.ft) == "string" and m.ft) or (type(m.ft) == "table" and table.concat(m.ft, ",")) or "*"
		table.insert(entries, string.format("%-20s │ %-15s │ %-10s │ %s", m.name, tags, fts, m.keys or ""))
	end
	return entries
end

-------------------------------------------------------
-- Base picker UI
-------------------------------------------------------

function M.show_list(list, title)
	if #list == 0 then
		vim.notify("[macromania] No macros found (" .. title .. ")", vim.log.levels.WARN)
		return
	end

	local entries = build_entries(list)

	fzf.fzf_exec(entries, {
		prompt = "Macros(" .. title .. ")> ",

		previewer = function(item)
			local name = extract_name(item)
			if not name then
				return "No macro selected"
			end

			local macro = find_macro(name, list)
			if not macro then
				return "Macro not found"
			end

			local readable = macro.keys and vim.fn.keytrans(macro.keys) or ""

			return table.concat({
				"Name:        " .. macro.name,
				"Tags:        " .. (macro.tags and table.concat(macro.tags, ", ") or ""),
				"Filetypes:   "
					.. (macro.ft and (type(macro.ft) == "string" and macro.ft or table.concat(macro.ft, ", ")) or "*"),
				"",
				"Raw:",
				macro.keys or "",
				"",
				"Keytrans:",
				readable,
			}, "\n")
		end,

		actions = {
			---------------------------------------------------
			-- Load macro into a register
			---------------------------------------------------
			["default"] = function(selected)
				local name = extract_name(selected[1])
				local macro = find_macro(name, list)
				if not macro then
					return
				end

				vim.schedule(function()
					vim.ui.input({ prompt = "Load into register (default q): " }, function(input)
						local reg = validate_register(input, "q")
						if not reg then
							return
						end
						catalog.perform_macro(macro, reg)
					end)

					vim.schedule(function()
						local keys = vim.api.nvim_replace_termcodes("i", true, false, true)
						vim.api.nvim_feedkeys(keys, "n", true)
					end)
				end)
			end,

			---------------------------------------------------
			-- Delete
			---------------------------------------------------
			["ctrl-d"] = function(selected)
				local name = extract_name(selected[1])
				vim.ui.select({ "No", "Yes" }, { prompt = "Delete '" .. name .. "'?" }, function(choice)
					if choice == "Yes" then
						catalog.delete_macro(name)
					end
				end)
			end,

			---------------------------------------------------
			-- Edit
			---------------------------------------------------
			["ctrl-e"] = function(selected)
				catalog.edit_macro(extract_name(selected[1]))
			end,

			---------------------------------------------------
			-- Rename
			---------------------------------------------------
			["ctrl-r"] = function(selected)
				local old = extract_name(selected[1])
				vim.ui.input({ prompt = "New name: " }, function(new)
					if new and new ~= "" then
						catalog.rename_macro(old, new)
					end
				end)
			end,

			---------------------------------------------------
			-- Clone
			---------------------------------------------------
			["ctrl-y"] = function(selected)
				local old = extract_name(selected[1])
				vim.ui.input({ prompt = "Clone as: " }, function(new)
					if new and new ~= "" then
						catalog.clone_macro(old, new)
					end
				end)
			end,

			---------------------------------------------------
			-- History
			---------------------------------------------------
			["ctrl-h"] = function()
				M.show_list(catalog.history(), "History")
			end,

			---------------------------------------------------
			-- Tag filter
			---------------------------------------------------
			["ctrl-t"] = function(selected)
				local macro = find_macro(extract_name(selected[1]), list)
				if not macro or not macro.tags then
					return
				end
				vim.ui.select(macro.tags, { prompt = "Filter by tag:" }, function(tag)
					if tag then
						M.show_list(catalog.filter_by_tag(tag), "Tag: " .. tag)
					end
				end)
			end,
		},
	})
end

-------------------------------------------------------
-- Main picker
-------------------------------------------------------

function M.show_picker()
	local ft = vim.bo.filetype
	M.show_list(catalog.filtered(ft), ft)
end

-------------------------------------------------------
-- Adding macros
-------------------------------------------------------

function M.add_macro()
	local ft = vim.bo.filetype
	local suggested = detect_macro_register()

	vim.ui.input({ prompt = "Macro name:" }, function(name)
		if not name or name == "" then
			return
		end

		vim.ui.input({ prompt = "Description:" }, function(desc)
			vim.ui.input({ prompt = "Tags (comma-separated):" }, function(tag_input)
				local tags
				if tag_input and tag_input ~= "" then
					tags = {}
					for t in tag_input:gmatch("[^,]+") do
						table.insert(tags, vim.trim(t))
					end
				end

				vim.ui.input({ prompt = "Register containing macro (" .. suggested .. "):" }, function(reg)
					local valid = validate_register(reg, suggested)
					if not valid then
						return
					end

					local keys = vim.fn.getreg(valid)
					if not keys or keys == "" then
						vim.notify("[macromania] Register @" .. valid .. " is empty", vim.log.levels.ERROR)
						return
					end

					catalog.save_macro({
						name = name,
						description = desc or "",
						keys = keys,
						ft = ft,
						tags = tags,
					})
				end)
			end)
		end)
	end)
end

return M
