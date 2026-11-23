" Atlas — parchment lettering on dark survey ink
set background=dark
hi clear
if exists('syntax_on')
  syntax reset
endif
let g:colors_name = 'atlas'
hi Normal       guifg=#f6e7d1 guibg=#0f1d28
hi Comment      guifg=#96a6a6 gui=italic
hi Constant     guifg=#ddb261
hi String       guifg=#a2bd94
hi Identifier   guifg=#78b8bf
hi Function     guifg=#78b8bf gui=bold
hi Statement    guifg=#f28c77
hi PreProc      guifg=#c8a2b8
hi Type         guifg=#8bcab5
hi Special      guifg=#eca46e
hi Error        guifg=#0f1d28 guibg=#f28c77
hi Todo         guifg=#0b1620 guibg=#ddb261
hi Search       guifg=#0b1620 guibg=#ddb261
hi Visual       guibg=#354e59
hi CursorLine   guibg=#172a35
hi LineNr       guifg=#96a6a6
hi StatusLine   guifg=#0f1d28 guibg=#78b8bf gui=NONE
hi Pmenu        guifg=#f6e7d1 guibg=#0b1620
hi PmenuSel     guifg=#0f1d28 guibg=#78b8bf
