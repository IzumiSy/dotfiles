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
Plug 'bronson/vim-trailing-whitespace', { 'on': ['FixWhitespace'] }
Plug 'easymotion/vim-easymotion', { 'on': ['<Plug>(easymotion-s2)'] }
Plug 'deris/vim-gothrough-jk'
Plug 'terryma/vim-multiple-cursors'
Plug 'vim-scripts/surround.vim'
Plug 'scrooloose/nerdcommenter'
Plug 'https://github.com/itchyny/lightline.vim'
Plug 'https://github.com/Shougo/unite.vim'
Plug 'https://github.com/Shougo/vimproc'
Plug 'https://github.com/Shougo/neomru.vim'
Plug 'vim-scripts/The-NERD-tree', { 'on': ['NERDTreeToggle', 'NERDTreeFind'] }
Plug 'vim-scripts/desert256.vim'
Plug 'https://github.com/cocopon/vaffle.vim'

" Git
Plug 'https://github.com/airblade/vim-gitgutter'
Plug 'TamaMcGlinn/vim-flog', { 'on': ['Flogsplit'] } " A temp bugfix repo of rbong/vim-flog
Plug 'tpope/vim-fugitive'

" LSP
Plug 'prabirshrestha/async.vim'
Plug 'prabirshrestha/asyncomplete.vim'
Plug 'prabirshrestha/asyncomplete-lsp.vim'
Plug 'prabirshrestha/vim-lsp'
Plug 'https://github.com/mattn/vim-lsp-settings'

" Syntaxes
Plug 'leshill/vim-json', { 'for': 'json' }
Plug 'tpope/vim-haml', { 'for': 'haml' }
Plug 'https://github.com/pangloss/vim-javascript', { 'for': 'javascript' }
Plug 'maxmellon/vim-jsx-pretty', { 'for': 'javascript' }
Plug 'joukevandermaas/vim-ember-hbs', { 'for': 'handlebars' }
Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }
Plug 'cespare/vim-toml', { 'for': 'toml' }
Plug 'ap/vim-css-color', { 'for': 'css' }
Plug 'hail2u/vim-css3-syntax', { 'for': 'css' }
Plug 'itchyny/vim-haskell-indent', { 'for': 'haskell' }
Plug 'digitaltoad/vim-pug', { 'for': 'pug' }
Plug 'earthly/earthly.vim', { 'branch': 'main' }

call plug#end()

" ========================= "
"      General settings     "
" ========================= "
scriptencoding utf-8
set tabstop=2 shiftwidth=2 softtabstop=2
set fencs=utf-8,euc-jp,iso-2022-jp,cp932
set matchpairs+=<:>
set whichwrap+=h,l,<,>,[,],b,s,~
set autoindent
set autoread
set ambiwidth=double
set expandtab
set notitle
set number
set incsearch
set hlsearch
set ignorecase
set smartcase
set clipboard=unnamed
set ruler
set noswapfile
set nowrap
set confirm
set title
set ttyfast
set cursorline
set showmatch
set showcmd
set splitright
set switchbuf+=vsplit
set laststatus=2
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8,iso-2022-jp,euc-jp,sjis
set fileformats=unix,dos,mac
set backspace=indent,eol,start
set completeopt=menu,preview
set updatetime=10000
set relativenumber
syntax on
silent! colorscheme desert256
filetype on

" Maps leader key
let mapleader=","

" Prevent performance slow-down with long line
set synmaxcol=200

" Remove 'thank you for flying vim'
let &titleold=getcwd()

" ========================== "
"     Filetype detection     "
" ========================== "
au BufRead,BufNewFile,BufReadPost *.erb set filetype=eruby.html
au BufRead,BufNewFile,BufReadPost {*.ts,*.tsx} set filetype=typescript
au BufRead,BufNewFile,BufReadPost *.elm set filetype=elm
au BufRead,BufNewFile,BufReadPost *.toml set filetype=toml
au BufRead,BufNewFile,BufReadPost *.pug set filetype=pug
au BufRead,BufNewFile {COMMIT_EDITMSG} set filetype=gitcommit
au BufRead,BufNewFile {.envrc,_bash*} set filetype=sh

" Special tab/indent width
au FileType html,javascript,typescript set tabstop=2 shiftwidth=2 softtabstop=2
au FileType c,cpp,go,python,elm set tabstop=4 shiftwidth=4 softtabstop=4
au FileType c,cpp set cindent

" Check files' modifiction more frequently
augroup checktime
  autocmd!
  autocmd WinEnter * checktime
augroup END

" Trim whitespace before saving a file except markdown
au BufWritePre *\({*.md}\)\@<! :FixWhitespace

" SmartNERDTree function opens NERDTree in smarter way.
" If the current buffer is empty, it executes NERDTree on the current diretory.
" But, if the file is opened in calling this function, it unfolds the directory which
" contains the file currently opened in NERDTree.
nnoremap <silent><leader>tr :call SmartNERDTree()<CR>
function! SmartNERDTree()
    if @% == ""
        NERDTreeToggle
    else
        NERDTreeFind
    endif
endfunction

command VIMRC edit $MYVIMRC
command Encutf8 :e ++enc=utf8
command Sudow :w sudo:%
command Sudoe :e sudo:%
command Uuid :r !uuidgen|tr "[A-Z]" "[a-z]"

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
nnoremap K <Nop>
nnoremap L w
vnoremap L w
nnoremap <C-d> <Nop>

" Quit
nnoremap X :q<CR>
nnoremap <C-x> :q<CR>

" Pagination
nnoremap U <C-u>
nnoremap D <C-d>

" Split windows
nnoremap S :vsplit<CR>
nmap fl <C-w>l
nmap fk <C-w>k
nmap fj <C-w>j
nmap fh <C-w>h

" Tab shortcuts
nnoremap T :tabnew<CR>
nnoremap FL :tabn<CR>
nnoremap FH :tabp<CR>

" Reload the file opened in the current buffer from disk
nnoremap <C-r> :e!<CR>

" Fix strange behavior of Backspace
inoremap <expr><BS> "\<C-h>"

" Visual mode key-mappings for multiple indents
vnoremap > >gv
vnoremap < <gv

" Buffer manipulation
nnoremap <leader>zz :bprev<CR>

" Errors
nnoremap <leader>ne :cn<CR>
nnoremap <leader>pe :cp<CR>

" Terminals
nnoremap <leader>ot :vert term<CR>

" Resets highlighting
nnoremap <silent> <Esc><Esc> :noh<CR> :call clearmatches()<CR>

" Block opening command history.
" It is triggered off mistakenly when using :q
nnoremap q: <NOP>

" It applies ordinary Windows key binding for undo
" Vim has Ctrl-Z for temporary quitting by default but that is not actually useful.
nnoremap <silent><C-z> <NOP>
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
    :execute "tabnew|Vaffle %:h" . currentFilePath
  endif
endfunction

" ================= "
"      vim-lsp      "
" ================= "
let g:lsp_diagnostics_float_delay = 1000
let g:lsp_diagnostics_echo_delay = 1000
let g:lsp_documentation_float = 0
let g:lsp_format_sync_timeout = 1000
let g:lsp_settings = {
\   'elm-language-server': {
\     'initialization_options': {
\       'elmPath': './node_modules/.bin/elm',
\       'elmFormatPath': './node_modules/.bin/elm-format',
\       'elmTestPath': './node_modules/.bin/elm-test'
\     }
\   }
\ }

au BufWritePre {*.go,*.elm,*.ts,*.js,*.rs} :LspDocumentFormatSync
nnoremap <leader>df :vert LspDefinition<CR>
nnoremap <leader>ip :vert LspImplementation<CR>
nnoremap <leader>tt :tab LspDefinition<CR>
nnoremap <leader>hp :LspHover<CR>
nnoremap <leader>rr :LspReferences<CR>
nnoremap <leader>ee :LspDocumentDiagnostics<CR>
nnoremap <leader>rn :LspRename<CR>
nnoremap <leader>ca :LspCodeAction<CR>
nnoremap E :LspNextError<CR>

" Debugging
if !empty($VIM_DEBUG)
  let g:lsp_log_verbose = 1
  let g:lsp_log_file = expand('~/vim-lsp.log')
endif

" ====================== "
"      asyncomplete      "
" ====================== "
let g:asyncomplete_popup_delay = 150
let g:asyncomplete_auto_popup = 0
set pumheight=30
inoremap <expr><CR>  pumvisible() ? "<C-y>" : "<CR>"
inoremap <expr><C-j> pumvisible() ? "<Down>" : "<C-j>"
inoremap <expr><C-k> pumvisible() ? "<Up>" : "<C-k>"
inoremap <expr><C-u> pumvisible() ? "<Up><Up><Up><Up><Up>" : "<C-u>"
inoremap <expr><C-d> pumvisible() ? "<Down><Down><Down><Down><Down>" : "<C-d>"
inoremap <expr><C-h> pumvisible() ? asyncomplete#cancel_popup() : "<C-h>"
inoremap <expr><C-c> pumvisible() ? asyncomplete#cancel_popup() : "<C-c>"
" Completion triggers (when CTRL-L or a period typed)
inoremap <expr><C-l> pumvisible() ? asyncomplete#close_popup() : asyncomplete#force_refresh()
imap . .<Plug>(asyncomplete_force_refresh)

" ======================== "
"      Unite settings      "
" ======================== "
let g:unite_source_history_yank_enable=1
let g:unite_source_file_mru_limit=200
let g:unite_source_rec_min_cache_files=500
let g:unite_source_rec_max_cache_files=50000
let g:unite_redraw_hold_candidates = 100000
let g:unite_source_grep_recursive_opt=''
let g:unite_prompt=">> "
if executable('hw')
  let g:unite_source_rec_async_command=['hw', '--follow-link', '--line-number', '--no-group', '--no-color']
  let g:unite_source_grep_command='hw'
  let g:unite_source_grep_default_opts='--follow-link --line-number --no-group --no-color'
elseif executable('ag')
  let g:unite_source_rec_async_command=['ag', '--follow', '--nogroup', '--nocolor']
  let g:unite_source_grep_command='ag'
  let g:unite_source_grep_default_opts='--follow --nogroup --nocolor'
endif

" nnoremap <silent><leader>fo :Unite -start-insert file<CR>
" nnoremap <silent><leader>ro :Unite -start-insert file_rec/async:.<CR>
" nnoremap <silent><leader>fh :Unite -start-insert history/yank<CR>
" nnoremap <silent><leader>fb :Unite -start-insert buffer<CR>
nnoremap <silent><leader>hh :Unite -start-insert file_mru<CR>
nnoremap <silent><leader>fg :Unite -start-insert file_rec/git<CR>
nnoremap <silent><leader>ff :Unite grep:. -buffer-name=search-buffer -no-quit<CR>
nnoremap <silent><leader>fl :UniteWithCursorWord grep:. -buffer-name=search-buffer -no-quit<CR>
let ignores = join([
\    '\.png$', '\.ico$', '\.svg$', '\.gif$', '\.keep$',
\    '\.eot$', '\.ttf$', '\.woff$', '\.woff2$',
\    'tmp/', 'node_modules/', 'bower_components/',
\    'elm-stuff/', '.cache', 'vendor/',
\  ], '\|')
call unite#sources#rec#define()
call unite#custom#source('file,file_rec,file_rec/git,file_rec/async,grep', 'ignore_pattern', ignores)
call unite#custom#source('file,file_rec,file_rec/git,file_rec/async,grep', 'sorters', 'sorter_length')
call unite#filters#matcher_default#use(['matcher_glob'])
call unite#filters#sorter_default#use(['sorter_rank'])
call unite#custom#profile('default', 'context', {
\   'no_quit': 1,
\   'start_insert': 1,
\   'vertical_preview': 1,
\ })
autocmd VimEnter * :execute "normal \<Plug>(unite_redraw)"
autocmd FileType unite call s:unite_settings()
function! s:unite_settings()
  imap <buffer> <C-j> <Plug>(unite_select_next_line)
  imap <buffer> <C-k> <Plug>(unite_select_previous_line)
  imap <buffer> <C-d> <Plug>(unite_select_next_page)
  imap <buffer> <C-u> <Plug>(unite_select_previous_page)

  nmap <silent><buffer><expr> Enter unite#do_action('switch')
  imap <silent><buffer><expr> Enter unite#do_action('switch')
  nmap <silent><buffer><expr> <C-t> unite#do_action('tabswitch')
  imap <silent><buffer><expr> <C-t> unite#do_action('tabswitch')
  nmap <silent><buffer><expr> <C-s> unite#do_action('vsplitswitch')
  imap <silent><buffer><expr> <C-s> unite#do_action('vsplitswitch')
endfunction

" ========================== "
"     Lightline settings     "
" ========================== "
if !has('gui_running')
  set t_Co=256
endif
let g:lightline = {
\   'colorscheme': 'one',
\   'active': {
\     'left': [
\       ['mode', 'paste', ],
\       ['git', 'readonly', 'relativepath', 'modified']
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
nnoremap <silent><leader>gl :vert Flogsplit<CR>
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

" ======================= "
"  Settings for Markdown  "
" ======================= "
let g:vim_markdown_folding_disabled = 1

" =========================== "
"   Settings for easymotion   "
" =========================== "
let g:EasyMotion_keys = 'hjklasdfgyuiopqwertnmzxcvbHJKLASDFGYUIOPQWERTNMZXCVB'
let g:EasyMotion_do_mapping = 0
let g:EasyMotion_smartcase = 1
nmap <C-j> <Plug>(easymotion-s2)
nmap <C-k> <Plug>(easymotion-s2)
hi EasyMotionShade ctermbg=none ctermfg=blue

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

" ==================== "
"   vim-gothrough-jk   "
" ==================== "
let g:go_through_jk_reset_interval = 2000
let g:go_through_jk_move_count = 5

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
