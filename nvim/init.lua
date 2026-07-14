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
  { "williamboman/mason.nvim", opts = {} },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      -- Servers: { lspconfig name, mason package name }
      local servers = {
        { "ts_ls", "typescript-language-server" },
      }

      -- ts_ls: monorepo対応 - 最寄りの tsconfig.json をrootにする
      vim.lsp.config('ts_ls', {
        root_dir = function(bufnr, on_dir)
          local fname = vim.api.nvim_buf_get_name(bufnr)
          local found = vim.fs.find('tsconfig.json', { path = vim.fs.dirname(fname), upward = true })[1]
          if found then on_dir(vim.fs.dirname(found)) end
        end,
      })

      local registry = require("mason-registry")
      for _, s in ipairs(servers) do
        local ok, pkg = pcall(registry.get_package, s[2])
        if ok and pkg:is_installed() then
          vim.lsp.enable(s[1])
        else
          vim.defer_fn(function()
            if vim.fn.confirm(s[2] .. " is not installed. Install via Mason?", "&Yes\n&No", 2) == 1 then
              vim.cmd("MasonInstall " .. s[2])
            end
          end, 100)
        end
      end

      -- Keymaps (on LSP attach)
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local buf = args.buf
          local map = function(mode, lhs, rhs)
            vim.keymap.set(mode, lhs, rhs, { buffer = buf })
          end

          map("n", "<leader>df", function() vim.cmd("vsplit") vim.lsp.buf.definition() end)
          map("n", "<leader>ip", function() vim.cmd("vsplit") vim.lsp.buf.implementation() end)
          map("n", "<leader>rr", vim.lsp.buf.references)
          map("n", "<leader>ee", vim.diagnostic.setloclist)
          map("n", "<leader>rn", vim.lsp.buf.rename)
          map("n", "<leader>ca", vim.lsp.buf.code_action)
          map("n", "E", vim.diagnostic.goto_next)
          map("n", "K", vim.lsp.buf.hover)

          -- Manual completion trigger (like your vimrc <C-l>)
          map("i", "<C-l>", "<C-x><C-o>")
        end,
      })
    end,
  },
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

-- Format on save via LSP (like vim-lsp format_sync)
au("BufWritePre", {
  pattern = { "*.ts", "*.tsx" },
  callback = function()
    vim.lsp.buf.format({ timeout_ms = 1000 })
  end,
})

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
