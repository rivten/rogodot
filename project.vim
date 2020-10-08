set errorformat=%ESCRIPT\ ERROR:\ %m,%Z\ \ \ At:\ res://%f:%l%s
set makeprg=~/programs/Godot_v3.2.3-stable_x11.64\ data\/scenes\/game.tscn
"set makeprg=~/programs/Godot_v3.2.3-stable_x11.64\ --verbose\ data\/scenes\/game.tscn
nnoremap <leader>b :call asyncrun#run('', {'program': 'make'}, '')<ENTER>

" NOTE(rivten): maybe I should remove the starting \s* to make sure to have only
" the global declarations
" but that could cause some false positive
nnoremap <C-T> :1vimgrep! /^\s*\(\(static \)\?func\\|class_name\\|class\\|var\\|enum\) \<\zs<C-R><C-W>\ze\>/ code/**/*.gd<enter>
