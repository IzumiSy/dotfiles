" =======================
"          VIMRC
" =======================

filetype off

if has('vim_starting')
  if &compatible
    set nocompatible
  endif
  set rtp+=~/.vim/bundle/Vundle.vim/
endif

call vundle#begin()

" ========================
"     Load VIM plugins
" ========================

Plugin 'VundleVim/Vundle.vim'

" Sudo wrapper plugin
Plugin 'sudo.vim'

" Syntax checking plugin
Plugin 'Syntastic'

" Word bracket, commenting plugins
Plugin 'surround.vim'
Plugin 'scrooloose/nerdcommenter'

" Asynchronous processing support
Plugin 'https://github.com/Shougo/vimproc'

" Auto complete popup
Plugin 'https://github.com/Shougo/neocomplcache'

" Status line customizing plugin
Plugin 'https://github.com/itchyny/lightline.vim'

" Plugins for compile sources without leaving VIM
Plugin 'quickrun.vim'
Plugin 'SingleCompile'

" Interactive fuzzy-wording finder over multiple
" sources like files, buffers, and file histories.
Plugin 'https://github.com/Shougo/unite.vim'
Plugin 'https://github.com/Shougo/neomru.vim'
Plugin 'unite-colorscheme'

" Plugins for quickfix
Plugin 'osyo-manga/unite-quickfix'
Plugin 'osyo-manga/shabadou.vim'

" File viewer plugins
Plugin 'The-NERD-tree'

" Git plugins
Plugin 'https://github.com/airblade/vim-gitgutter'
Plugin 'tpope/vim-fugitive'
Plugin 'motemen/git-vim'
Plugin 'https://github.com/kmnk/vim-unite-giti'
Plugin 'https://github.com/junegunn/gv.vim'

" Rails, CoffeeScript, TypeScript, JSON, Pug supports for Vim
Plugin 'leafgarland/typescript-vim'
Plugin 'kchmck/vim-coffee-script'
Plugin 'rails.vim'
Plugin 'leshill/vim-json'
Plugin 'digitaltoad/vim-pug'

" HTML5, CSS3, SCSS, JavaScript
Plugin 'othree/html5.vim'
Plugin 'othree/yajs.vim'
Plugin 'JulesWang/css.vim'
Plugin 'hail2u/vim-css3-syntax'
Plugin 'cakebaker/scss-syntax.vim'

" Vue file support
Plugin 'posva/vim-vue'

" Golang
Plugin 'vim-jp/vim-go-extra'
Plugin 'fatih/vim-go'

" Whitespace trailer
Plugin 'bronson/vim-trailing-whitespace'

" The Silver Searcher
Plugin 'rking/ag.vim'

" Vim motion on speed
Plugin 'easymotion/vim-easymotion'

" Theme
Plugin 'desert256.vim'

call vundle#end()
filetype plugin indent on

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
set cursorline
set showmatch
set showcmd
set splitright
set laststatus=2
set encoding=utf-8
set fileencodings=utf-8,iso-2022-jp,euc-jp,sjis
set fileformats=unix,dos,mac
set backspace=indent,eol,start
syntax on
silent! colorscheme desert256

" Prevent performance slow-down with long line
set synmaxcol=200

" ========================== "
"     Filetype detection     "
" ========================== "
au BufRead,BufNewFile,BufReadPost *.gs set filetype=javascript
au BufRead,BufNewFile,BufReadPost *.erb set filetype=eruby.html
au BufRead,BufNewFile,BufReadPost *.scss set filetype=scss.css
au BufRead,BufNewFile,BufReadPost *.coffee set filetype=coffee
au BufRead,BufNewFile,BufReadPost *.json set syntax=json
au BufRead,BufNewFile {*.md} set filetype=markdown
au BufRead,BufNewFile {COMMIT_EDITMSG} set filetype=gitcommit

" wanna use vim-vue, but for now this is the best
autocmd BufRead,BufNewFile,BufReadPost *.vue set filetype=html

au FileType c,golang set tabstop=4 shiftwidth=4 softtabstop=4
autocmd FileType c,cpp,perl,python set cindent
autocmd FileType perl,cgi :compiler perl

nnoremap <silent>,tr :NERDTree<CR>
nnoremap <F7> :Errors<CR>
nnoremap <F8> :make<CR>

command VIMRC edit $MYVIMRC
command Encutf8 :e ++enc=utf8
command Sudow :w sudo:%
command Sudoe :e sudo:%

" =============================== "
"     Customized key mappings     "
" =============================== "
nnoremap <C-t> :tabnew<CR>
nnoremap <C-n> :tabn<CR>
nnoremap <C-b> :tabp<CR>

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
inoremap <C-k> <Nop>
inoremap <C-l> <Nop>

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

" Check files' modifiction more frequently
augroup checktime
  autocmd!
  autocmd WinEnter * checktime
augroup END

" Trim whitespace before saving a file
autocmd BufWritePre * :FixWhitespace

" ========================= "
"     Quickrun settings     "
" ========================= "
autocmd FileType perl,cgi :nnoremap <silent>,rr :QuickRun perl<CR>
autocmd FileType cpp :nnoremap <silent>,rr :QuickRun g++<CR>
autocmd FileType c :nnoremap <silent>,rr :QuickRun c<CR>
autocmd FileType python :nnoremap <silent>,rr :QuickRun python<CR>
autocmd FileType ruby :nnoremap <silent>,rr :QuickRun ruby<CR>
autocmd FileType go :nnoremap <silent>,rr :QuickRun go<CR>
autocmd FileType sh :noremap <silent>,rr :QuickRun sh<CR>
if !exists("g:quickrun_config")
    let g:quickrun_config={}
endif
let g:quickrun_config["_"] = {
\   'hook/time/enable': 1,
\   'runner/vimproc/updatetime': 60,
\   'outputter/buffer/split': ':botright 14sp',
\   'runner': 'vimproc'
\ }
let g:quickrun_config["go"] = {
\   'command': 'go run'
\ }
let g:quickrun_config["sh"] = {
\   'command': 'bash'
\ }

" ======================== "
"      Unite settings      "
" ======================== "
let g:unite_source_history_yank_enable=1
let g:unite_source_file_mru_limit=200
let g:unite_source_rec_min_cache_files=500
let g:unite_source_rec_max_cache_files=99999
let g:unite_redraw_hold_candidates = 50000
let g:unite_prompt=">> "

" Key mappings for Unite commands
nnoremap <silent>,fo :Unite -start-insert file<CR>
nnoremap <silent>,ro :Unite -start-insert file_rec/async:.<CR>
nnoremap <silent>,fg :Unite -start-insert file_rec/git<CR>
nnoremap <silent>,fm :Unite -start-insert file_mru<CR>
nnoremap <silent>,fh :Unite -start-insert history/yank<CR>
nnoremap <silent>,fb :Unite -start-insert buffer<CR>
nnoremap <silent>,ff :Unite grep:. -buffer-name=search-buffer -no-quit<CR>
nnoremap <silent>,fl :UniteWithCursorWord grep:. -buffer-name=search-buffer -no-quit<CR>
nnoremap <silent>,gb :Unite giti/branch<CR>
nnoremap <silent>,gs :Unite giti/status -horizontal<CR>

" Use highway/ag for full-text document search
if executable('hw')
  let g:unite_source_grep_command='hw'
  let g:unite_source_grep_default_opts='--follow-link --line-number --no-group --no-color'
  let g:unite_source_rec_async_command='hw --follow-link --line-number --no-group --no-color'
elseif executable('ag')
  let g:unite_source_grep_command='ag'
  let g:unite_source_grep_default_opts='--follow --nogroup --nocolor'
  let g:unite_source_rec_async_command='ag --follow --nogroup --nocolor'
endif

let g:unite_source_grep_recursive_opt=''

function! SetupUniteOptions()
  if exists(':Unite')
    " Set ignore directories
    call unite#custom#source('file_rec,file_rec/async', 'ignore_pattern',
    \   'node_modules/\|jspm_packages/\|bower_components/\|'.
    \   'tmp/\|cache/\|.git/\|.DS_Store\|png\|jpg')

    " Set matchers
    " call unite#filters#matcher_default#use(['matcher_fuzzy'])
    call unite#filters#sorter_default#use(['sorter_rank'])
  endif
endfunction
autocmd VimEnter * call SetupUniteOptions()

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
\       ['fugitive', 'readonly', 'filename', 'modified']
\     ]
\   },
\   'component': {
\     'fugitive': '%{exists("*fugitive#head") ? fugitive#head() : ""}',
\     'readonly': '%{&readonly ? "🔒" : ""}'
\   }
\ }

" ============================= "
"      Git plugin settings      "
" ============================= "
let g:git_command_edit = 'rightbelow vnew'
nnoremap <silent>,gg :GitGutterToggle<CR>
nnoremap <silent>,gh :GitGutterLineHighlightsToggle<CR>
nnoremap <silent>,gl :GV!<CR>

" ========================== "
"     Syntastic settings     "
" ========================== "
let g:syntastic_enable_signs=1
let g:syntastic_enable_highlighting=1
let g:syntastic_disabled_filetypes=['html']
let g:syntastic_html_checkers=['']

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

" =========================== "
"   Settings for easymotion   "
" =========================== "
let g:EasyMotion_do_mapping=0
nmap <C-j><C-j> <Plug>(easymotion-s2)
nmap <C-k><C-k> <Plug>(easymotion-s2)

" ============================== "
"   Settings for NeoComplCache   "
" ============================== "
let g:neocomplcache_enable_at_startup=1
let g:neocomplcache_enable_ignore_case=1
let g:neocomplcache_smart_case=1
" let g:neocomplcache_enable_auto_select=1
let g:neocomplcache_min_syntax_length=2
let g:neocomplcache_lock_buffer_name_pattern="\*ku\*"
let g:neocomplcache_enable_camel_case_completion=1
let g:neocomplcache_enable_underbar_completon=1
let g:neocomplcache_dictionary_filetype_lists = {
    \ 'default': ''
    \ }

inoremap <silent> <CR> <C-r>=<SID>my_cr_function()<CR>
function! s:my_cr_function()
    return neocomplcache#smart_close_popup()."\<CR>"
endfunction

inoremap <expr><TAB> pumvisible() ? "\<C-n>" : "\<TAB>"
inoremap <expr><C-j> pumvisible() ? "\<C-n>" : "\<C-j>"
inoremap <expr><C-k> pumvisible() ? "\<C-p>" : "\<C-k>"
" inoremap <expr><C-u> pumvisible() : "\<C-p>\<C-p>\<C-p>\<C-p>" : "\<C-u>"
" inoremap <expr><C-d> pumvisible() ? "\<C-n>\<C-n>\<C-n>\<C-n>" : "\<C-d>"
inoremap <expr><C-l> pumvisible() ? neocomplcache#smart_close_popup() : "\<C-l>"
inoremap <expr><C-h> pumvisible() ? neocomplcache#cancel_popup()."\<C-h>" : "\<C-h>"

" Define keyword.
if !exists('g:neocomplcache_keyword_patterns')
  let g:neocomplcache_keyword_patterns = {}
endif
let g:neocomplcache_keyword_patterns['default'] = '\h\w*'

" Enable background transparency on Ubuntu
" these highlight settings needs to be here.
highlight Normal ctermbg=none
highlight NonText ctermbg=none
