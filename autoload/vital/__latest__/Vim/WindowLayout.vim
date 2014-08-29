let s:save_cpo= &cpo
set cpo&vim

function! s:_vital_loaded(V)
  let s:BM= a:V.import('Vim.BufferManager')
  let s:L=  a:V.import('Data.List')
endfunction

function! s:_vital_depends()
  return ['Vim.BufferManager', 'Data.List']
endfunction

let s:window_layout= {
\ '__buffer_managers': {},
\ '__layouts': {},
\}

function! s:new(...)
  let wl= deepcopy(s:window_layout)

  return wl
endfunction

" layout_data
" ---
" meta data
" ---
" layout:  'layout name'
" walias:  'window name'
"
" layout specific options
" ---
" bufname: 'buffer name'
" north:   {layout_data}
" south:   {layout_data}
" west:    {layout_data}
" east:    {layout_data}
" center:  {layout_data}
" width:   30 or 0.3
" height:  30 or 0.3
"
" limitation
" ---
" north.width = south.width = west.width + center.width + east.width
" north.height + south.height + center.height = parent.height
"
function! s:window_layout.layout(layout_data)
  if !has_key(a:layout_data, 'layout')
    throw "vital: Vim.WindowLayout: You must specify `layout'."
  elseif !has_key(self.__layouts, a:layout_data.layout)
    throw printf("vital: Vim.WindowLayout: No such layout `%s'.", a:layout_data.layout)
  endif

  " validate
  call self.validate_layout_data(a:layout_data)

  let save_splitright= &splitright
  let save_splitbelow= &splitbelow

  set nosplitright
  set nosplitbelow

  try
    let engine= self.__layouts[a:layout_data.layout]
    call engine.apply(self, a:layout_data)
  finally
    let &splitright= save_splitright
    let &splitbelow= save_splitbelow
  endtry
endfunction

function! s:window_layout.winnr(walias)
  for nr in range(1, winnr('$'))
    let name= getwinvar(nr, 'vital_vim_windowlayout_walias')

    if name ==# a:walias
      return nr
    endif
  endfor
  return -1
endfunction

function! s:window_layout.validate_layout_data(data, ...)
  if has_key(a:data, 'layout') && !has_key(self.__layouts, a:data.layout)
    throw printf("vital: Vim.WindowLayout: No such layout `%s'.", a:data.layout)
  endif

  let workbuf= get(a:000, 0, {'waliases': []})

  " check meta options
  if has_key(a:data, 'walias')
    if s:L.has(workbuf.waliases, a:data.walias)
      throw printf("vital: Vim.WindowLayout: Duplicated walias `%s' is not valid.", a:data.walias)
    endif
    let workbuf.waliases+= [a:data.walias]
  endif

  " check engine specific options
  if has_key(a:data, 'layout')
    let engine= self.__layouts[a:data.layout]
    if has_key(engine, 'validate_layout_data')
      call engine.validate_layout_data(self, a:data, workbuf)
    endif
  endif
endfunction

"
" Border Layout
"
" +----------------------+
" |        north         |
" +------+--------+------+
" | west | center | east |
" +------+--------+------+
" |        south         |
" +----------------------+
"
" north.width = south.width = west.width + center.width + east.width
" north.height + south.height + center.height = parent.height
"
let s:border_layout= {}

function! s:border_layout.validate_layout_data(wl, data, workbuf)
  for region in ['north', 'south', 'west', 'center', 'east']
    if has_key(a:data, region)
      call a:wl.validate_layout_data(a:data[region], a:workbuf)
    endif
  endfor
endfunction

function! s:border_layout.apply(wl, data)
  " split vertical
  let openers= []
  if has_key(a:data, 'north')
    let openers+= [self.make_opener('aboveleft new', a:data.north)]
  endif
  if has_key(a:data, 'south')
    let openers+= [self.make_opener('belowright new', a:data.south)]
  endif

  " split horizontal
  if has_key(a:data, 'center')
    let openers+= [self.make_opener('', a:data.center)]
  endif
  if has_key(a:data, 'east')
    let openers+= [self.make_opener('belowright vnew', a:data.east)]
  endif
  if has_key(a:data, 'west')
    let openers+= [self.make_opener('aboveleft vnew', a:data.west)]
  endif

  " do layout
  for opener in openers
    let prev_bufnr= bufnr('%')
    call opener.apply(a:wl)
    execute bufwinnr(prev_bufnr) 'wincmd w'
  endfor

  " adjust size
endfunction

function! s:border_layout.make_opener(opener, data)
  let opener= {
  \ 'opener': a:opener,
  \ 'data':   a:data,
  \}

  function! opener.apply(wl)
    if !empty(self.opener)
      let bufname= get(self.data, 'bufname', '')
      if !has_key(a:wl.__buffer_managers, bufname)
        let a:wl.__buffer_managers[bufname]= s:BM.new()
      endif
      call a:wl.__buffer_managers[bufname].open(bufname, {'opener': self.opener})
    endif

    " make alias for window
    if has_key(self.data, 'walias')
      call setwinvar('.', 'vital_vim_windowlayout_walias', self.data.walias)
    endif

    if has_key(self.data, 'north') || has_key(self.data, 'south') ||
    \  has_key(self.data, 'east') || has_key(self.data, 'west') ||
    \  has_key(self.data, 'center')
      call a:wl.layout(self.data)
    endif
  endfunction

  return opener
endfunction

let s:window_layout.__layouts.border= s:border_layout
unlet s:border_layout

let &cpo= s:save_cpo
unlet s:save_cpo
" vim: tabstop=2 shiftwidth=2 expandtab
