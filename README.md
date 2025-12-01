# macromania.nvim

**macromania.nvim** is a persistent, fuzzy-searchable **macro management plugin** for
Neovim.

It lets you:

- Save named macros
- Edit them in a floating window
- Tag and categorize macros
- Filter by filetype
- Clone, rename, delete macros
- View usage history
- Load macros into registers without auto-executing them

Powered by **fzf-lua**.

---

## 📜 Acknowledgement

This plugin started as a tiny utility in my own Neovim setup to keep my macros synced between computers.  
I later rebuilt it as a proper plugin as a learning project and a way to clean up the original hacky version.

It’s built for my personal workflow and not meant to be the ultimate macro manager — but if it helps you too, that’s awesome.

## ✨ Features

- 📁 Persistent macro storage (`macromania.json` in nvim data directory)
- 🔍 FZF-based macro picker
- 🔎 Filetype-filtered macro lists
- 🏷 Tag filtering
- 📜 Macro history (last used / use count)
- ✏ Floating macro editor
- 🧬 Clone / rename / delete macros
- ⌨ Load macros into registers without running them automatically

---

## 🚀 Installation

### Lazy.nvim

```lua
return {
  "seanm33/macromania.nvim",
  dependencies = { "ibhagwan/fzf-lua" },
  config = function()
    -- optional keymaps
    vim.keymap.set("n", "<leader>ma", "<cmd>MacroAdd<cr>", {
      desc = "Add Macro"
    })
    vim.keymap.set("n", "<leader>mm", "<cmd>MacroList<cr>", {
      desc = "Macro Picker"
    })
    vim.keymap.set("n", "<leader>mh", "<cmd>MacroHistory<cr>", {
      desc = "Macro History"
    })
  end,
}
```
