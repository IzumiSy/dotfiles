" =======================
"          VIMRC
" =======================

filetype off

if has('vim_starting')
  if &compatible
    set nocompatible
  endif
  set rtp+=~/.vim/vundle.git/
endif

call vundle#rc()

" ========================
"     Load VIM plugins
" ========================

" Sudo wrapper plugin
Bundle "sudo.vim"

" Syntax checking plugin
Bundle "Syntastic"

" Automatic word completion plugin
Bundle "vim-scripts/AutoComplPop"

" Word bracket handling plugin
Bundle "surround.vim"

" Asynchronous processing support
Bundle "https://github.com/Shougo/vimproc"

" Status line customizing plugin
Bundle "https://github.com/itchyny/lightline.vim"

" Interactive shell wrapper
Bundle "https://github.com/Shougo/vimshell.git"

" Plugins for compile sources without leaving VIM
Bundle "quickrun.vim"
Bundle "SingleCompile"

" Interactive fuzzy-wording finder over multiple
" sources like files, buffers, and file histories.
Bundle "https://github.com/Shougo/unite.vim"
Bundle "https://github.com/Shougo/neomru.vim"
Bundle "unite-colorscheme"
Bundle "basyura/unite-rails"

" File viewer plugins
Bundle "The-NERD-tree"
Bundle "mru.vim"

" Git plugins
Bundle "https://github.com/airblade/vim-gitgutter"
Bundle 'tpope/vim-fugitive'
Bundle 'motemen/git-vim'
Bundle 'https://github.com/kmnk/vim-unite-giti'
Bundle 'https://github.com/junegunn/gv.vim'

" Rails, CoffeeScript, TypeScript, JSON, Jade supports for Vim
Bundle "leafgarland/typescript-vim"
Bundle "kchmck/vim-coffee-script"
Bundle "rails.vim"
Bundle "leshill/vim-json"
Bundle "digitaltoad/vim-jade"

" HTML5, CSS3, SCSS, JavaScript
Bundle "othree/html5.vim"
Bundle "JulesWang/css.vim"
Bundle "hail2u/vim-css3-syntax"
Bundle "pangloss/vim-javascript"
Bundle "cakebaker/scss-syntax.vim"

" Golang
Bundle "vim-jp/vim-go-extra"
Bundle "fatih/vim-go"

" Whitespace trailer
Bundle "bronson/vim-trailing-whitespace"

" Open URL with default browser
Bundle "open-browser.vim"

" The Silver Searcher
Bundle "rking/ag.vim"

" Theme
Bundle "desert256.vim"

filetype plugin indent on

" ========================= "
"      General settings     "
" ========================= "
scriptencoding utf-8
set tabstop=4 shiftwidth=4 softtabstop=4
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
set fileencodings=iso-2022-jp,euc-jp,sjis,utf-8
set fileformats=unix,dos,mac
set backspace=indent,eol,start
syntax on
colorscheme desert256

" Prevent performance slow-down with long line
set synmaxcol=200

" ========================== "
"     Filetype detection     "
" ========================== "
autocmd FileType c,cpp,perl,python set cindent
autocmd FileType perl,cgi :compiler perl
autocmd FileType html,jade,css,scss,php set tabstop=2 shiftwidth=2 softtabstop=2
autocmd FileType javascript,coffeescript set tabstop=2 shiftwidth=2 softtabstop=2
autocmd FileType ruby,python set tabstop=2 shiftwidth=2 softtabstop=2
autocmd BufRead,BufNewFile *.gs set filetype=javascript
autocmd BufRead,BufNewFile *.scss set filetype=scss.css
autocmd BufRead,BufNewFile *.erb set filetype=html

nnoremap <silent>,tr :<C-u>NERDTree<CR>
nnoremap <silent>,ms :<C-u>VimShell<CR>
nnoremap <silent>,mr :<C-u>MRU<CR>
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

" Closes window
nnoremap <C-x> :q<CR>

" Disables arrow keys
noremap <Up> <Nop>
noremap <Down> <Nop>
noremap <Left> <Nop>
noremap <Right> <Nop>
inoremap <C-k> <Nop>
inoremap <C-l> <Nop>

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

" ================================== "
"     Alias comamnds for vimgrep     "
" ================================== "
command! -nargs=? Vgrep call s:vg_check_args(<f-args>)
command! LaunchInteractiveVgrep call s:vg_interactive()
command! -range LaunchSelectedVgrep call s:vg_execute(s:get_selected_text())
nnoremap <silent><C-f> :LaunchInteractiveVgrep<CR>
vmap <silent>,gv :LaunchSelectedVgrep<CR>

function! s:get_selected_text()
  normal gv"xy
  let result = getreg("x")
  normal gv
  return result
endfunction

function! s:vg_execute(query)
  echo "Processing vimgrep: ".a:query
  execute "vimgrep ".a:query." **/* | cw"
endfunction

function! s:vg_check_args(...)
  if a:0 >= 1
    call s:vg_execute(a:1)
  else
    echo "Needs more than one argument at least."
  end
endfunction

function! s:vg_interactive()
  let queries = inputdialog("Queries: ")
  redraw
  call s:vg_execute(queries)
endfunction

" ===================================== "
"     Autocompletion popup settigns     "
" ===================================== "
let g:acp_enableAtStartup=0
autocmd BufWinEnter * call acp#disable()
hi PmenuSel ctermbg=darkgreen
hi LineNr ctermfg=darkgray
hi StatusLine ctermbg=darkgray ctermfg=lightgray
autocmd FileType c,cpp :call acp#enable()
autocmd FileType html,jade,css,scss :call acp#enable()
autocmd FileType javascript,coffeescript :call acp#enable()
autocmd FileType ruby :call acp#enable()

" ========================= "
"     Quickrun settings     "
" ========================= "
autocmd FileType perl,cgi :nnoremap <F5> :QuickRun perl<CR>
autocmd FileType cpp :nnoremap <F5> :QuickRun cpp/g++<CR>
autocmd FileType c :nnoremap <F5> :QuickRun cpp/C<CR>
autocmd FileType python :nnoremap <F5> :QuickRun python<CR>
autocmd FileType ruby :noremap <F5> :QuickRun ruby<CR>
if !exists("g:quickrun_config")
    let g:quickrun_config={}
endif
let g:quickrun_config["_"] = {
\   'hook/time/enable': 1,
\   'runner/vimproc/updatetime': 60,
\   'outputter/buffer/split': ':botright 14sp',
\   'runner': 'vimproc'
\ }

" ======================== "
"      Unite settings      "
" ======================== "
let g:unite_source_history_yank_enable=1
let g:unite_source_file_mru_limit=200
let g:unite_source_rec_min_cache_files=500
let g:unite_source_rec_max_cache_files=99999
let g:unite_prompt=">> "

" Key mappings for Unite commands
nnoremap <silent>,fo :Unite -start-insert file<CR>
nnoremap <silent>,ro :Unite -start-insert file_rec/async:.<CR>
nnoremap <silent>,fg :Unite -start-insert file_rec/git<CR>
nnoremap <silent>,fm :Unite -start-insert file_mru<CR>
nnoremap <silent>,fh :Unite -start-insert history/yank<CR>
nnoremap <silent>,fb :Unite -start-insert buffer<CR>
nnoremap <silent>,ff :Unite grep:. -buffer-name=search-buffer -no-quit<CR>
nnoremap <silent>,gb :Unite giti/branch<CR>
nnoremap <silent>,gs :Unite giti/status -horizontal<CR>

" Command bindings for unite-rails
command Rctrl :Unite rails/controller
command Rmodel :Unite rails/model
command Rview :Unite rails/view
command Rdb :Unite rails/db
command Rconfig :Unite rails/config
command Rroutes :Unite rails/route

" Set ignore directories
call unite#custom#source('file_rec,file_rec/async', 'ignore_pattern',
\   'node_modules/\|jspm_packages/\|bower_components/\|'.
\   'tmp/\|cache/\|.git/\|.DS_Store\|png\|jpg')

" Set matchers
" call unite#filters#matcher_default#use(['matcher_fuzzy'])
" call unite#filters#sorter_default#use(['sorter_rank'])

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
\       [ 'mode', 'paste' ],
\       [ 'fugitive', 'readonly', 'filename', 'modified' ]
\     ]
\   },
\   'component': {
\     'fugitive': '%{exists("*fugitive#head")?fugitive#head():""}'
\   }
\ }

" ============================= "
"      Git plugin settings      "
" ============================= "
let g:git_command_edit = 'rightbelow vnew'
nnoremap <silent>,gg :<C-u>GitGutterToggle<CR>
nnoremap <silent>,gh :<C-u>GitGutterLineHighlightsToggle<CR>
nnoremap <silent>,gl :GV!<CR>

" ============================== "
"      Openbrowser settings      "
" ============================== "
nmap <silent>,gx <Plug>(openbrowser-smart-search)
vmap <silent>,gx <Plug>(openbrowser-smart-search)

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
let g:go_highlight_fields=1
let g:go_highlight_types=1
let g:go_highlight_operators=1

