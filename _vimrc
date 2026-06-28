" --------------------------------------------------
"
" _|      _|  _|_|_|  _|      _|  _|_|_|      _|_|_|
" _|      _|    _|    _|_|  _|_|  _|    _|  _|
" _|      _|    _|    _|  _|  _|  _|_|_|    _|
"   _|  _|      _|    _|      _|  _|    _|  _|
"     _|      _|_|_|  _|      _|  _|    _|    _|_|_|
"
"                                 Created by IzumiSy
" --------------------------------------------------

" Install vim-plug if not installed yet
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" ========================
"     Load VIM plugins
" ========================

call plug#begin('~/.vim/plugged')

Plug 'vim-scripts/sudo.vim'
Plug 'vim-scripts/surround.vim'
Plug 'vim-scripts/desert256.vim'
Plug 'bronson/vim-trailing-whitespace', { 'on': ['FixWhitespace'] }
Plug 'terryma/vim-multiple-cursors'
Plug 'scrooloose/nerdcommenter'
Plug 'https://github.com/itchyny/lightline.vim'
Plug 'https://github.com/cocopon/vaffle.vim'
Plug 'tpope/vim-fugitive'
Plug 'mechatroner/rainbow_csv', { 'for': ['csv', 'tsv'] }

" LSP
Plug 'prabirshrestha/async.vim'
Plug 'prabirshrestha/asyncomplete.vim'
Plug 'prabirshrestha/asyncomplete-lsp.vim'
Plug 'prabirshrestha/vim-lsp'
Plug 'https://github.com/mattn/vim-lsp-settings'
Plug 'micchy326/lightline-lsp-progress', { 'branch': 'main' }

call plug#end()

" ========================= "
"      General settings     "
" ========================= "
scriptencoding utf-8
set tabstop=2 shiftwidth=2 softtabstop=2
set whichwrap+=h,l,<,>,[,],b,s,~
set autoindent
set autoread
set ambiwidth=double
set expandtab
set number
set incsearch
set hlsearch
set ignorecase
set smartcase
set clipboard=unnamed
set noswapfile
set nowrap
set confirm
set title
set cursorline
set showmatch
set splitright
set signcolumn=yes
set switchbuf+=vsplit
set laststatus=2
set fileencoding=utf-8
set fileencodings=utf-8,iso-2022-jp,euc-jp,sjis
set fileformats=unix,dos
set updatetime=1000
set relativenumber

" Vim default is re=0, but something in the runtime/plugin stack likely overrides it
" after startup; without this explicit reset, TS highlighting regresses here. Check with:
"   :verbose set re?
set re=0

syntax on
silent! colorscheme desert256
filetype plugin indent on

" Maps leader key
let mapleader=","

" Prevent performance slow-down with long line
set synmaxcol=200

" Remove 'thank you for flying vim'
let &titleold=getcwd()

" ========================== "
"     Filetype detection     "
" ========================== "
au BufRead,BufNewFile {COMMIT_EDITMSG} set filetype=gitcommit
au BufRead,BufNewFile {.envrc,_bash*} set filetype=sh

" Special tab/indent width
au FileType html,javascript,typescript,typescriptreact set tabstop=2 shiftwidth=2 softtabstop=2
au FileType c,cpp,go,python,elm set tabstop=4 shiftwidth=4 softtabstop=4
au FileType c,cpp set cindent
au FileType tsv,cue set noexpandtab

" Check files' modifiction more frequently
augroup checktime
  autocmd!
  autocmd WinEnter * checktime
augroup END

" Trim whitespace before saving a file except markdown
au BufWritePre *\({*.md}\)\@<! :FixWhitespace

command VIMRC edit $MYVIMRC
command Encutf8 :e ++enc=utf8
command Sudow :w sudo:%
command Sudoe :e sudo:%

" Insert UUID
function GenerateUuid() abort
  let l:uuid = system('uuidgen | tr "[A-Z]" "[a-z]" | tr -d "\n"')
  execute "normal! a".uuid."\<esc>"
endfunction
command Uuid :call GenerateUuid()

" Command to update tabs to spaces
command ChangeTab2Space :call s:change_tab_function()
function s:change_tab_function()
  set expandtab
  retab
endfunction

" =============================== "
"     Customized key mappings     "
" =============================== "
imap jj <Esc>
nnoremap J <Nop>
nnoremap H b
vnoremap H b
nnoremap <C-j> <Nop>
nnoremap L w
vnoremap L w
nnoremap <C-d> <Nop>

" Quit
nnoremap X :q<CR>
nnoremap <C-x> :q<CR>

" Pagination
nnoremap U <C-u>
vnoremap U <C-u>
nnoremap D <C-d>
vnoremap D <C-d>

" Split windows
nnoremap S <nop>
nnoremap <leader>sp :vsplit<CR>
nnoremap <leader>vs :split<CR>
nmap fl <C-w>l
nmap fk <C-w>k
nmap fj <C-w>j
nmap fh <C-w>h

" Reload the file opened in the current buffer from disk
nnoremap <C-r> :e!<CR>

" Fix strange behavior of Backspace
inoremap <expr><BS> "\<C-h>"

" Visual mode key-mappings for multiple indents
vnoremap > >gv
vnoremap < <gv

" Terminals
nnoremap <leader>ot :vert term<CR>

" Copy
nnoremap <leader>cp :w !pbcopy<CR>
vnoremap <leader>cp :w !pbcopy<CR>

" Enabling paste mode only in Normal mode (pastetoggle cannot achieve this)
" In addition, it maps `p` with pasting contents from clipboard and switching into nopaste mode
nnoremap @ :call TogglePasteMode()<CR>
function! TogglePasteMode()
  if &paste
    set nopaste
  else
    set paste
  endif
endfunction
nnoremap p :call PasteSwitchingIntoNoPaste()<CR>
function! PasteSwitchingIntoNoPaste()
  normal! p
  if &paste
    set nopaste
  endif
endfunction

" Resets highlighting
nnoremap <silent> <Esc><Esc> :noh<CR> :call clearmatches()<CR>

" Block opening command history.
" It is triggered off mistakenly when using :q
nnoremap q: <NOP>

" It applies ordinary Windows key binding for undo
" Vim has Ctrl-Z for temporary quitting by default but that is not actually useful.
nnoremap <silent><C-z> :undo<CR>

" Stop opening split windows with Ctrl+w+n
" to block bumping with GNU screen keybinding to change windows
nnoremap <C-w><C-n> <NOP>

" Disable dot action
nnoremap . <NOP>

" Shift-free command mode in US layout
nmap ; :

" Disabled built-in SQL completion in Vim
let g:omni_sql_no_default_maps = 1

" redraw on focus return and actual split creation; avoid every WinEnter on TS
au FocusGained,WinNew * redraw!

" ============= "
"    Vaffle     "
" ============= "
let g:vaffle_show_hidden_files = 1
nnoremap <silent><leader>pp :call SmartVaffle()<CR>
function! SmartVaffle()
  if @% == ""
    Vaffle
  else
    let currentFilePath = expand("%:h")
    :execute "Vaffle " . currentFilePath
  endif
endfunction

" ================= "
"      vim-lsp      "
" ================= "
let g:lsp_documentation_float = 0
let g:lsp_format_sync_timeout = 1000
let g:lsp_work_done_progress_enabled = 1
let g:lsp_inlay_hints_enabled = 0
let g:lsp_diagnostics_virtual_text_enabled = 0
let g:lsp_settings = {
\   'elm-language-server': {
\     'initialization_options': {
\       'elmPath': './node_modules/.bin/elm',
\       'elmFormatPath': './node_modules/.bin/elm-format',
\       'elmTestPath': './node_modules/.bin/elm-test'
\     }
\   }
\ }

nnoremap <leader>df :vert LspDefinition<CR>
nnoremap <leader>ip :vert LspImplementation<CR>
nnoremap <leader>rr :LspReferences<CR>
nnoremap <leader>ee :LspDocumentDiagnostics<CR>
nnoremap <leader>rn :LspRename<CR>
nnoremap <leader>ca :LspCodeAction<CR>
nnoremap E :LspNextError<CR>
nnoremap K :LspHover<CR>

" Debugging
if !empty($VIM_DEBUG)
  let g:lsp_log_verbose = 1
  let g:lsp_log_file = expand('~/vim-lsp.log')
endif

" Inlay style
highlight lspInlayHintsType ctermfg=darkgray guifg=darkgray ctermbg=black guibg=black
highlight lspInlayHintsParameter ctermfg=darkgray guifg=darkgray ctermbg=black guibg=black

" ====================== "
"      asyncomplete      "
" ====================== "
let g:asyncomplete_popup_delay = 150
let g:asyncomplete_auto_popup = 0
set pumheight=30
inoremap <expr><CR>  pumvisible() ? "<C-y>" : "<CR>"
inoremap <expr><C-c> pumvisible() ? asyncomplete#cancel_popup() : "<C-c>"
inoremap <expr>J     pumvisible() ? "<Down>" : "J"
inoremap <expr>K     pumvisible() ? "<Up>" : "K"
inoremap <expr>U     pumvisible() ? "<Up><Up><Up><Up><Up>" : "U"
inoremap <expr>D     pumvisible() ? "<Down><Down><Down><Down><Down>" : "D"
inoremap <expr>H     pumvisible() ? asyncomplete#cancel_popup() : "H"
inoremap <expr><C-l> pumvisible() ? asyncomplete#close_popup() : asyncomplete#force_refresh()

" ========================== "
"     Lightline settings     "
" ========================== "
let g:lightline_lsp_progress_skip_time = 0.1
let g:lightline = {
\   'colorscheme': 'one',
\   'active': {
\     'left': [
\       ['mode', 'paste'],
\       ['git', 'readonly', 'relativepath', 'modified', 'lsp_status']
\     ],
\     'right': [
\       ['lineinfo'],
\       ['fileformat', 'fileencoding', 'filetype']
\     ]
\   },
\   'component': {
\     'git': '%{FugitiveStatusline()}',
\     'readonly': '%{&readonly ? "[LOCKED]" : ""}',
\   },
\   'component_function': {
\     'lsp_status': 'lightline_lsp_progress#progress',
\     'relativepath': 'RelativePath',
\   }
\ }

" Calculate relative path from current git project.
" This functins requires vim-fugitive plugins to work.
function! RelativePath()
  let root = fnamemodify(get(b:, 'git_dir'), ':h')
  let path = expand('%:p')
  if path[:len(root)-1] ==# root
    return path[len(root)+1:]
  endif
  return expand('%')
endfunction

" ======================= "
"      vim-fugitive       "
" ======================= "
nnoremap <silent><leader>gs :Git<CR>:20wincmd_<CR>
nnoremap <silent><leader>gd :vert Git diff --staged<CR>
nnoremap <silent><leader>gl :vert Git log --oneline --decorate<CR>
nnoremap <silent><leader>gg :Git commit<CR>
nnoremap <silent><leader>gw :Git commit -m "wip"<CR>
nnoremap <silent><leader>ga :Git add . --verbose<CR>
nnoremap <silent><leader>gb :Git blame<CR>
nnoremap <silent><leader>gp :call GitPushCurrentBranch()<CR>

" Pushes commits to the branch whose name is the same as we are currently checking out on
function! GitPushCurrentBranch()
  let branch = trim(system('git branch --show-current'))
  echo "Git pushing to the remote branch... (" . branch . ")"
  execute ":Git push -u origin " . branch
endfunction

" =========================== "
"   Settings for easymotion   "
" =========================== "
" let g:EasyMotion_keys = 'hjklasdfgyuiopqwertnmzxcvbHJKLASDFGYUIOPQWERTNMZXCVB'
" let g:EasyMotion_do_mapping = 0
" let g:EasyMotion_smartcase = 1
" nmap <C-j> <Plug>(easymotion-s2)
" nmap <C-k> <Plug>(easymotion-s2)
" hi EasyMotionShade ctermbg=none ctermfg=blue

" ================= "
"   Abbreviations   "
" ================= "
cnoreabbrev W! w!
cnoreabbrev Q! q!
cnoreabbrev Qall! qall!
cnoreabbrev Wq wq
cnoreabbrev Wa wa
cnoreabbrev wQ wq
cnoreabbrev WQ wq
cnoreabbrev W w
cnoreabbrev Q q
cnoreabbrev Qall qall

" ================= "
"   NeedCommenter   "
" ================= "
let g:NERDCreateDefaultMappings = 0
let g:NERDSpaceDelims = 1
let g:NERDCompactSexyComs = 1
let g:NERDDefaultAlign = 'left'
nnoremap <leader>cc <plug>NERDCommenterToggle
vnoremap <leader>cc <plug>NERDCommenterToggle

" ===================== "
"   vim-multi-cursors   "
" ===================== "
let g:multi_cursor_use_default_mapping = 0
let g:multi_cursor_start_word_key = "<S-i>"
let g:multi_cursor_quit_key = "<C-c>"

" ================= "
"     Highlight     "
" ================= "
" Enable background transparency. these highlight settings needs to be here.
highlight Normal ctermbg=none
highlight NonText ctermbg=none
