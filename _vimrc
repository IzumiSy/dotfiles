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

" ========================
"     Load VIM plugins
" ========================

call plug#begin('~/.vim/plugged')

" Sudo wrapper plugin
Plug 'vim-scripts/sudo.vim'

" Syntax checking plugin
" Plug 'dense-analysis/ale'
" Plug 'maximbaz/lightline-ale'

" Whitespace trailer
Plug 'bronson/vim-trailing-whitespace', { 'on': 'FixWhitespace' }

" Fulltext searching
Plug 'rking/ag.vim'

" Nice Vim manipulation
Plug 'easymotion/vim-easymotion'
Plug 'deris/vim-gothrough-jk'
Plug 'terryma/vim-multiple-cursors'

" Word bracket, commenting plugins
Plug 'vim-scripts/surround.vim'
Plug 'scrooloose/nerdcommenter'

" Autocomplete popup
Plug 'https://github.com/Shougo/neocomplete'

" Status line customizing plugin
Plug 'https://github.com/itchyny/lightline.vim'

" Interactive fuzzy-wording finder over multiple
" sources like files, buffers, and file histories.
Plug 'https://github.com/Shougo/unite.vim'
Plug 'https://github.com/Shougo/vimproc', { 'do': 'make' }
Plug 'https://github.com/Shougo/neomru.vim'

" File viewer plugins
Plug 'vim-scripts/The-NERD-tree', { 'on': 'NERDTree' }

" Theme
Plug 'vim-scripts/desert256.vim'

" Git
" @ vim-gitgutter is a plugin shows Git status on an each line
" @ vim-fugitive is required for lightline.vim
Plug 'https://github.com/airblade/vim-gitgutter'
Plug 'tpope/vim-fugitive'

" TypeScript
" @ typescript-vim is syntax highlight support
" @ tsuquyomi is a plugin to use TypeScript server
Plug 'leafgarland/typescript-vim', { 'for': 'typescript' }
Plug 'Quramy/tsuquyomi', { 'for': 'typescript', 'do': 'npm install -g typescript' }

" CSS
" @ css.vim is a plugin to add standard CSS syntax highlight
" @ vim-css3-syntax adds a syntax for CSS3 in addition to css.vim
Plug 'JulesWang/css.vim', { 'for': 'css' }
Plug 'hail2u/vim-css3-syntax', { 'for': 'css' }

" Golang
Plug 'fatih/vim-go', { 'for': 'go', 'do': ':GoInstallBinaries' }

" Elm
Plug 'elmcast/elm-vim', { 'for': 'elm' }

" Other syntaxes
Plug 'leshill/vim-json', { 'for': 'json' }
Plug 'tpope/vim-haml', { 'for': 'haml' }
Plug 'othree/html5.vim', { 'for': 'html' }
Plug 'cakebaker/scss-syntax.vim', { 'for': 'scss' }
Plug 'othree/yajs.vim', { 'for': 'javascript' }
Plug 'maxmellon/vim-jsx-pretty', { 'for': 'javascript' }
Plug 'joukevandermaas/vim-ember-hbs', { 'for': 'handlebars' }
Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }
Plug 'cespare/vim-toml', { 'for': 'toml' }

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
set laststatus=2
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8,iso-2022-jp,euc-jp,sjis
set fileformats=unix,dos,mac
set backspace=indent,eol,start
set completeopt=menu,preview
set updatetime=100
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
au BufRead,BufNewFile {COMMIT_EDITMSG} set filetype=gitcommit
au BufRead,BufNewFile {.envrc,_bash*} set filetype=sh

" Speciul tab/indent width
au FileType c,golang set tabstop=4 shiftwidth=4 softtabstop=4
au FileType c,cpp,python set cindent

" Check files' modifiction more frequently
augroup checktime
  autocmd!
  autocmd WinEnter * checktime
augroup END

" Trim whitespace before saving a file except markdown
au BufWritePre *\({*.md}\)\@<! :FixWhitespace

nnoremap <silent>,tr :NERDTree<CR>
nnoremap <F7> :Errors<CR>
nnoremap <F8> :make<CR>

command VIMRC edit $MYVIMRC
command Encutf8 :e ++enc=utf8
command Sudow :w sudo:%
command Sudoe :e sudo:%

" Command to update tabs to spaces
command ChangeTab2Space :call s:change_tab_function()
function s:change_tab_function()
  set expandtab
  retab
endfunction

" =============================== "
"     Customized key mappings     "
" =============================== "
nnoremap <C-t> :tabnew<CR>
nnoremap <C-m> :tabn<CR>
nnoremap <C-n> :tabp<CR>

nmap <silent><C-h> b
nmap <silent><C-l> w
vmap <silent><C-h> b
vmap <silent><C-l> w

" Fix strange behavior of Backspace
inoremap <expr><BS> "\<C-h>"

" Closes window
nnoremap <C-x> :q<CR>

" Disables arrow keys
noremap <Up> <Nop>
noremap <Down> <Nop>
noremap <Left> <Nop>
noremap <Right> <Nop>

" Visual mode key-mappings for multiple indents
vnoremap > >gv
vnoremap < <gv

" Resets highlighting
nnoremap <silent> <Esc><Esc> :noh<CR> :call clearmatches()<CR>

" Searching the selected text in visual mode
vmap <silent>,ff y/<C-R>"<CR>

" Block opening command history.
" It is triggered off mistakenly when using :q
nnoremap q: <NOP>

" It applies ordinary Windows key binding for undo
" On the default setting, Vim has Ctrl-Z for temporary quitting
" with shell control system, but it is not actually useful.
nnoremap <silent>u <NOP>
nnoremap <silent><C-z> <NOP>
nnoremap <silent><C-z> :undo<CR>

" Stop opening split windows with Ctrl+w+n
" to block bumping with GNU screen keybinding to change windows
nnoremap <C-w><C-n> <NOP>

" Disable dot action
nnoremap . <NOP>

" ======================== "
"      Unite settings      "
" ======================== "
function! SetupUniteOptions()
  if exists(':Unite')
    let ignores = join([
    \    '\.png$', '\.ico$', '\.svg$', '\.gif$', '\.keep$',
    \    '\.eot$', '\.ttf$', '\.woff$', '\.woff2$',
    \    'tmp/', 'node_modules/', 'bower_components/',
    \    'elm-stuff/', '.cache'
    \  ], '\|')
    call unite#sources#rec#define()
    call unite#custom#source('file,file_rec,file_rec/git,file_rec/async,grep', 'ignore_pattern', ignores)
    call unite#custom#source('file,file_rec,file_rec/git,file_rec/async,grep', 'sorters', 'sorter_length')
    call unite#filters#matcher_default#use(['matcher_glob'])
    call unite#filters#sorter_default#use(['sorter_rank'])

    if executable('ag')
      let g:unite_source_rec_async_command=['ag', '--follow', '--nogroup', '--nocolor']
      let g:unite_source_grep_command='ag'
      let g:unite_source_grep_default_opts='--follow --nogroup --nocolor'
    elseif executable('hw')
      let g:unite_source_rec_async_command=['hw', '--follow-link', '--line-number', '--no-group', '--no-color']
      let g:unite_source_grep_command='hw'
      let g:unite_source_grep_default_opts='--follow-link --line-number --no-group --no-color'
    endif

    let g:unite_source_history_yank_enable=1
    let g:unite_source_file_mru_limit=200
    let g:unite_source_rec_min_cache_files=500
    let g:unite_source_rec_max_cache_files=99999
    let g:unite_redraw_hold_candidates = 50000
    let g:unite_prompt=">> "

    nnoremap <silent>,fo :Unite -start-insert file<CR>
    nnoremap <silent>,ro :Unite -start-insert file_rec/async:.<CR>
    nnoremap <silent>,fg :Unite -start-insert file_rec/git<CR>
    nnoremap <silent>,fm :Unite -start-insert file_mru<CR>
    nnoremap <silent>,fh :Unite -start-insert history/yank<CR>
    nnoremap <silent>,fb :Unite -start-insert buffer<CR>
    nnoremap <silent>,ff :Unite grep:. -buffer-name=search-buffer -no-quit<CR>
    nnoremap <silent>,fl :UniteWithCursorWord grep:. -buffer-name=search-buffer -no-quit<CR>

    let g:unite_source_grep_recursive_opt=''
  endif
endfunction
autocmd VimEnter * call SetupUniteOptions()
autocmd VimEnter * :execute "normal \<Plug>(unite_redraw)"

" ========================== "
"     Lightline settings     "
" ========================== "
if !has('gui_running')
  set t_Co=256
endif
let g:lightline = {
\   'colorscheme': 'powerline',
\   'active': {
\     'left': [
\       ['mode', 'paste'],
\       ['fugitive', 'readonly', 'filename', 'modified'],
\       ['ctrlpmark']
\     ],
\     'right': [
\       ['lineinfo'],
\       ['fileformat', 'fileencoding', 'filetype'],
\       ['linter_checking', 'linter_errors', 'linter_warnings', 'linter_ok']
\     ]
\   },
\   'component': {
\     'fugitive': '%{exists("*fugitive#head") ? "<".fugitive#head().">" : ""}',
\     'readonly': '%{&readonly ? "[LOCKED]" : ""}'
\   },
\   'component_expand': {
\     'linter_checking': 'lightline#ale#checking',
\     'linter_warnings': 'lightline#ale#warnings',
\     'linter_errors': 'lightline#ale#errors',
\     'linter_ok': 'lightline#ale#ok'
\   },
\   'component_type': {
\     'linter_checking': 'left',
\     'linter_warnings': 'warning',
\     'linter_errors': 'error',
\     'linter_ok': 'left'
\   }
\ }

" ============================= "
"      Git plugin settings      "
" ============================= "
let g:git_command_edit = 'rightbelow vnew'
nnoremap <silent>,gg :GitGutterToggle<CR>
nnoremap <silent>,gh :GitGutterLineHighlightsToggle<CR>
nnoremap <silent>,gl :GV!<CR>

" ============ "
"     ale      "
" ============ "
" let g:ale_set_loclist=0
" let g:ale_set_quickfix=1
" let g:ale_linters={
" \   'go': ['gopls']
" \ }

" ===================== "
"  Settings for Golang  "
" ===================== "
let g:go_highlight_functions=1
let g:go_highlight_methods=1
let g:go_highlight_structs=1
let g:go_highlight_fields=1
let g:go_highlight_types=1
let g:go_highlight_operators=1
let g:go_def_mapping_enabled=0
let g:go_def_mode='gopls'
let g:go_info_mode='gopls'
au BufWritePost *.go :silent GoFmt
au FileType go :nnoremap <silent>,df :call go#def#Jump("split", 0)<CR>

" Fix for fuckin slow autocompletion
" [Ref] https://github.com/fatih/vim-go/issues/2049#issuecomment-437045293
let g:go_auto_type_info=0
let g:go_auto_sameids=0
let g:go_gocode_propose_source=0

" ====================== "
"    Settings for Elm    "
" ====================== "
let g:elm_setup_keybindings=0
let g:elm_format_autosave=1

" ======================= "
"  Settings for Markdown  "
" ======================= "
let g:vim_markdown_folding_disabled=1

" =========================== "
"   Settings for easymotion   "
" =========================== "
let g:EasyMotion_keys='hjklasdfgyuiopqwertnmzxcvbHJKLASDFGYUIOPQWERTNMZXCVB'
let g:EasyMotion_do_mapping=0
let g:EastMotion_grouping=1
nmap <C-j><C-j> <Plug>(easymotion-s2)
nmap <C-k><C-k> <Plug>(easymotion-s2)
hi EasyMotionShade ctermbg=none ctermfg=blue

" ============================ "
"   Settings for neocomplete   "
" ============================ "
let g:acp_enableAtStartup=0
let g:neocomplete#enable_at_startup=1
let g:neocomplete#enable_smart_case=1

if !exists('g:neocomplete#keyword_patterns')
  let g:neocomplete#keyword_patterns = {}
endif
if !exists('g:neocomplete#force_omni_input_patterns')
  let g:neocomplete#force_omni_input_patterns = {}
endif

let g:neocomplete#keyword_patterns['default'] = '\h\w*'
let g:neocomplete#force_omni_input_patterns['typescript'] = '[^. *\t]\.\w*\|\h\w*::'
let g:neocomplete#force_omni_input_patterns['go'] = '\h\w\.\w*'

inoremap <expr><TAB> pumvisible() ? "\<C-n>" : "\<TAB>"
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<S-TAB>"
inoremap <expr><C-j> pumvisible() ? "\<C-n>" : "\<C-j>"
inoremap <expr><C-k> pumvisible() ? "\<C-p>" : ""
inoremap <expr><C-u> pumvisible() : "\<C-p>\<C-p>\<C-p>\<C-p>" : "\<C-u>"
inoremap <expr><C-d> pumvisible() ? "\<C-n>\<C-n>\<C-n>\<C-n>" : "\<C-d>"
inoremap <expr><C-h> pumvisible() ? neocomplete#cancel_popup()."\<C-h>" : "\<C-h>"
inoremap <expr><C-l> neocomplete#cancel_popup()

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

" ================== "
"     tsuquyomi      "
" ================== "
let g:tsuquyomi_disable_quickfix = 1
let g:tsuquyomi_disable_default_mappings = 1
map <buffer> <Nop> <Plug>(TsuquyomiGoBack)

" ================= "
"   NeedCommenter   "
" ================= "
let g:NERDSpaceDelims = 1

" ==================== "
"   vim-gothrough-jk   "
" ==================== "
let g:go_through_jk_reset_interval = 2000
let g:go_through_jk_move_count = 5

" ===================== "
"   vim-multi-cursors   "
" ===================== "
let g:multi_cursor_use_default_mapping=0
let g:multi_cursor_start_word_key="<S-i>"
let g:multi_cursor_quit_key="<C-c>"

" Prevent Neocomplete in vim-multi-cursors working
function! Multiple_cursors_before()
  if exists(':NeoCompleteLock')==2
    exe 'NeoCompleteLock'
  endif
endfunction
function! Multiple_cursors_after()
  if exists(':NeoCompleteUnlock')==2
    exe 'NeoCompleteUnlock'
  endif
endfunction

" ================= "
"     Highlight     "
" ================= "
" Enable background transparency on Ubuntu. these highlight settings needs to be here.
highlight Normal ctermbg=none
highlight NonText ctermbg=none
