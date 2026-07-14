-- ================================================
-- Neovim minimal config
-- Test: nvim -u ./nvim/init.lua
-- ================================================

-- Leader key (before any mappings)
vim.g.mapleader = ","

-- ========================
--     Plugin (lazy.nvim)
-- ========================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    config = function()
      local mc = require("multicursor-nvim")
      mc.setup()

      local set = vim.keymap.set

      -- Visual select → I to add cursor on each selected line
      -- then press i/a to insert on all cursors
      set("x", "I", mc.addCursorOperator)

      -- Quit / clear cursors (like old <C-c>)
      set("n", "<C-c>", function()
        if mc.hasCursors() then
          mc.clearCursors()
        end
      end)

      -- Escape to enable/clear when multi-cursor active
      mc.addKeymapLayer(function(layerSet)
        layerSet("n", "<Esc>", function()
          if not mc.cursorsEnabled() then
            mc.enableCursors()
          else
            mc.clearCursors()
          end
        end)
      end)

      -- Cursor highlight
      vim.api.nvim_set_hl(0, "MultiCursorCursor", { reverse = true })
      vim.api.nvim_set_hl(0, "MultiCursorVisual", { link = "Visual" })
    end,
  },
})

-- ========================
--        Options
-- ========================
local opt = vim.opt

opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true
opt.autoindent = true
opt.smartindent = true

opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.showmatch = true
opt.wrap = false
opt.scrolloff = 4

opt.incsearch = true
opt.hlsearch = true
opt.ignorecase = true
opt.smartcase = true

opt.clipboard = "unnamed"
opt.swapfile = false
opt.confirm = true
opt.title = true
opt.splitright = true
opt.updatetime = 1000
opt.synmaxcol = 200
opt.pumheight = 30

opt.fileencoding = "utf-8"
opt.fileencodings = { "utf-8", "iso-2022-jp", "euc-jp", "sjis" }
opt.fileformats = { "unix", "dos" }

opt.laststatus = 2
opt.whichwrap:append("h,l,<,>,[,],b,s,~")

-- ========================
--        Keymaps
-- ========================
local map = vim.keymap.set

-- Escape
map("i", "jj", "<Esc>")

-- Navigation
map({ "n", "v" }, "H", "b")
map({ "n", "v" }, "L", "w")
map({ "n", "v" }, "U", "<C-u>")
map({ "n", "v" }, "D", "<C-d>")

-- Disable
map("n", "J", "<Nop>")
map("n", "<C-j>", "<Nop>")
map("n", "<C-d>", "<Nop>")
map("n", ".", "<Nop>")
map("n", "q:", "<Nop>")
map("n", "<C-w><C-n>", "<Nop>")

-- Quit
map("n", "X", ":q<CR>")
map("n", "<C-x>", ":q<CR>")

-- Splits
map("n", "S", "<Nop>")
map("n", "<leader>sp", ":vsplit<CR>")
map("n", "<leader>vs", ":split<CR>")
map("n", "fl", "<C-w>l")
map("n", "fk", "<C-w>k")
map("n", "fj", "<C-w>j")
map("n", "fh", "<C-w>h")

-- Reload buffer from disk
map("n", "<C-r>", ":e!<CR>")

-- Undo
map("n", "<C-z>", ":undo<CR>", { silent = true })

-- Indent in visual mode (keep selection)
map("v", ">", ">gv")
map("v", "<", "<gv")

-- Clear search highlight
map("n", "<Esc><Esc>", ":noh<CR>:call clearmatches()<CR>", { silent = true })

-- Shift-free command mode
map("n", ";", ":")

-- Copy to pbcopy
map({ "n", "v" }, "<leader>cp", ":w !pbcopy<CR>")

-- Tabs
map("n", "tn", ":tabnew<CR>")
map("n", "tl", ":tabnext<CR>")
map("n", "th", ":tabprev<CR>")
map("n", "tx", ":tabclose<CR>")

-- File explorer (netrw)
vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 0
vim.g.netrw_hide = 0  -- show hidden files

map("n", "<leader>pp", function()
  local dir = vim.fn.expand("%:h")
  if dir == "" then dir = "." end
  vim.cmd("Explore " .. dir)
end)

vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    local bopts = { buffer = true, remap = true }
    vim.keymap.set("n", "l", "<CR>", bopts)   -- enter/open
    vim.keymap.set("n", "h", "-", bopts)      -- go up
    vim.keymap.set("n", ".", "gh", bopts)     -- toggle hidden files
    vim.keymap.set("n", "q", ":bd<CR>", bopts) -- close
  end,
})

-- ========================
--       Autocmds
-- ========================
local au = vim.api.nvim_create_autocmd

-- Trim trailing whitespace on save (except markdown)
au("BufWritePre", {
  pattern = "*",
  callback = function()
    if vim.bo.filetype ~= "markdown" then
      local pos = vim.api.nvim_win_get_cursor(0)
      vim.cmd([[%s/\s\+$//e]])
      vim.api.nvim_win_get_cursor(0)
      pcall(vim.api.nvim_win_set_cursor, 0, pos)
    end
  end,
})

-- Filetype detection
au({ "BufRead", "BufNewFile" }, {
  pattern = { "COMMIT_EDITMSG" },
  callback = function() vim.bo.filetype = "gitcommit" end,
})
au({ "BufRead", "BufNewFile" }, {
  pattern = { ".envrc", "_bash*" },
  callback = function() vim.bo.filetype = "sh" end,
})

-- Filetype-specific indent
au("FileType", {
  pattern = { "c", "cpp", "go", "python", "elm" },
  callback = function()
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    vim.bo.softtabstop = 4
  end,
})
au("FileType", {
  pattern = { "tsv", "cue" },
  callback = function() vim.bo.expandtab = false end,
})

-- Check file changes on focus
au({ "FocusGained", "WinEnter" }, {
  pattern = "*",
  command = "checktime",
})

-- ========================
--      Colorscheme
-- ========================
vim.cmd("colorscheme habamax")

-- Transparent background
vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
vim.api.nvim_set_hl(0, "NonText", { bg = "NONE" })

-- ========================
--      Abbreviations
-- ========================
local abbrevs = { "W!", "Q!", "Qall!", "Wq", "Wa", "wQ", "WQ", "W", "Q", "Qall" }
local targets = { "w!", "q!", "qall!", "wq", "wa", "wq", "wq", "w", "q", "qall" }
for i, ab in ipairs(abbrevs) do
  vim.cmd("cnoreabbrev " .. ab .. " " .. targets[i])
end

-- vim: set ts=2 sw=2 et:
