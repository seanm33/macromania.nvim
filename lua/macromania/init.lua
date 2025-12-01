local M = {}

local json_path = vim.fn.stdpath("data") .. "/macromania.json"

-------------------------------------------------------
-- Catalog storage
-------------------------------------------------------

local function ensure_file()
	if vim.fn.filereadable(json_path) == 0 then
		vim.fn.writefile({ vim.json.encode({}) }, json_path)
	end
end

function M.load()
	ensure_file()
	local raw = table.concat(vim.fn.readfile(json_path), "\n")
	local ok, decoded = pcall(vim.json.decode, raw)
	return (ok and type(decoded) == "table") and decoded or {}
end

function M.save(catalog)
	ensure_file()
	vim.fn.writefile({ vim.json.encode(catalog) }, json_path)
end

-------------------------------------------------------
-- Filtering helpers
-------------------------------------------------------

local function ft_matches(macro_ft, current_ft)
	if not macro_ft then
		return true
	end
	if macro_ft == "*" then
		return true
	end
	if type(macro_ft) == "string" then
		return macro_ft == current_ft
	end
	if type(macro_ft) == "table" then
		for _, ft in ipairs(macro_ft) do
			if ft == current_ft then
				return true
			end
		end
	end
	return false
end

function M.filtered(ft)
	local out = {}
	for _, m in ipairs(M.load()) do
		if ft_matches(m.ft, ft) then
			table.insert(out, m)
		end
	end
	return out
end

function M.filter_by_tag(tag)
	local out = {}
	for _, m in ipairs(M.load()) do
		if m.tags then
			for _, t in ipairs(m.tags) do
				if t == tag then
					table.insert(out, m)
					break
				end
			end
		end
	end
	return out
end

-------------------------------------------------------
-- History tracking
-------------------------------------------------------

function M.use_macro(entry)
	local catalog = M.load()
	entry.last_used = vim.loop.now()
	entry.use_count = (entry.use_count or 0) + 1
	M.save(catalog)
end

function M.history(limit)
	local catalog = M.load()
	table.sort(catalog, function(a, b)
		return (a.last_used or 0) > (b.last_used or 0)
	end)
	if not limit then
		return catalog
	end
	local out = {}
	for i = 1, math.min(limit, #catalog) do
		out[i] = catalog[i]
	end
	return out
end

-------------------------------------------------------
-- Macro execution/loading
-------------------------------------------------------

function M.perform_macro(macro, register)
	if macro.keys and macro.keys ~= "" then
		vim.fn.setreg(register, macro.keys, "n")
		M.use_macro(macro)
	else
		vim.notify("[macromania] Macro has no keys", vim.log.levels.ERROR)
	end
end

-------------------------------------------------------
-- CRUD operations
-------------------------------------------------------

function M.save_macro(entry)
	local catalog = M.load()
	for i, m in ipairs(catalog) do
		if m.name == entry.name then
			catalog[i] = entry
			M.save(catalog)
			return
		end
	end
	table.insert(catalog, entry)
	M.save(catalog)
end

function M.delete_macro(name)
	local out = {}
	for _, m in ipairs(M.load()) do
		if m.name ~= name then
			table.insert(out, m)
		end
	end
	M.save(out)
end

function M.rename_macro(old_name, new_name)
	local catalog = M.load()
	for _, m in ipairs(catalog) do
		if m.name == old_name then
			m.name = new_name
			M.save(catalog)
			return
		end
	end
end

function M.clone_macro(old_name, new_name)
	local catalog = M.load()
	for _, m in ipairs(catalog) do
		if m.name == old_name then
			local clone = vim.deepcopy(m)
			clone.name = new_name
			clone.last_used = nil
			clone.use_count = nil
			table.insert(catalog, clone)
			M.save(catalog)
			return
		end
	end
end

-------------------------------------------------------
-- Floating editor
-------------------------------------------------------

function M.edit_macro(name)
	local catalog = M.load()
	local macro
	for _, m in ipairs(catalog) do
		if m.name == name then
			macro = m
			break
		end
	end
	if not macro then
		vim.notify("[macromania] Macro not found: " .. name, vim.log.levels.ERROR)
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "macro://" .. name)
	vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

	local float = {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		width = math.floor(vim.o.columns * 0.5),
		height = 10,
		row = math.floor(vim.o.lines / 2 - 5),
		col = math.floor(vim.o.columns / 2 - 30),
	}

	local win = vim.api.nvim_open_win(buf, true, float)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { macro.keys or "" })

	local function save()
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		macro.keys = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
		M.save(catalog)
		vim.api.nvim_set_option_value("modified", false, { buf = buf })
	end

	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf,
		callback = function()
			save()
			vim.notify("[macromania] Saved macro '" .. name .. "'")
		end,
	})

	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = buf,
		callback = save,
	})

	vim.keymap.set("n", "q", function()
		save()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf })

	vim.keymap.set("n", "<Esc>", function()
		save()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf })

	vim.api.nvim_set_option_value("modified", true, { buf = buf })
end

return M
