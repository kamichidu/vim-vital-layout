let s:save_cpo= &cpo
set cpo&vim

function! s:_vital_loaded(V)
  let s:BM= a:V.import('Vim.BufferManager')
  let s:L=  a:V.import('Data.List')
endfunction

function! s:_vital_depends()
  return ['Vim.BufferManager', 'Data.List']
endfunction

" buffer:
"   id: required
"   bufnr: optional
"   bufname: optional (default: '')
"   range: optional (default: 'tabpage')
"   __manager: internal use
let s:window_layout= {
\ '__buffers': {},
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
function! s:window_layout.layout(buffers, layout_data, ...)
  let force= get(a:000, 0, 1)

  if !has_key(a:layout_data, 'layout')
    throw "vital: Vim.WindowLayout: You must specify `layout'."
  elseif !has_key(self.__layouts, a:layout_data.layout)
    throw printf("vital: Vim.WindowLayout: No such layout `%s'.", a:layout_data.layout)
  endif

  " validate
  call self.validate_layout_data(a:layout_data)

  " ensure buffer exists
  for buf in a:buffers
    if !has_key(self.__buffers, buf.id)
      let self.__buffers[buf.id]= deepcopy(buf)

      let _buf= self.__buffers[buf.id]

      let _buf.__manager= s:BM.new({'range': get(buf, 'range', 'tabpage')})
      " use already opened buffer
      if !has_key(buf, 'bufnr')
        let info= _buf.__manager.open(get(_buf, 'bufname', ''))
        let _buf.bufnr= info.bufnr
      else
        let _buf.bufnr= buf.bufnr
        call _buf.__manager.add(_buf.bufnr)
      endif

      let self.__buffers[_buf.id]= _buf
    endif
  endfor

  " clear tabpage layout
  if force
    only
  endif

  let save_splitright= &splitright
  let save_splitbelow= &splitbelow

  set nosplitright
  set nosplitbelow

  try
    let engine= self.__layouts[a:layout_data.layout]
    call engine.apply(self, deepcopy(a:layout_data))
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

function! s:window_layout.buffers()
  return values(self.__buffers)
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
  " adjust
  if !has_key(a:data, 'center')
    if has_key(a:data, 'west')
      let a:data.center= a:data.west
      unlet a:data.west
    elseif has_key(a:data, 'east')
      let a:data.center= a:data.east
      unlet a:data.east
    elseif has_key(a:data, 'north')
      let a:data.center= a:data.north
      unlet a:data.north
    elseif has_key(a:data, 'south')
      let a:data.center= a:data.south
      unlet a:data.south
    endif
  endif

  " split vertical
  let openers= []
  if has_key(a:data, 'north')
    let openers+= [self.make_opener('aboveleft split', a:data.north)]
  endif
  if has_key(a:data, 'south')
    let openers+= [self.make_opener('belowright split', a:data.south)]
  endif

  " split horizontal
  if has_key(a:data, 'center')
    let openers+= [self.make_opener('', a:data.center)]
  endif
  if has_key(a:data, 'east')
    let openers+= [self.make_opener('belowright vsplit', a:data.east)]
  endif
  if has_key(a:data, 'west')
    let openers+= [self.make_opener('aboveleft vsplit', a:data.west)]
  endif

  " do layout
  for opener in openers
    let winvar= getwinvar('.', '')
    call opener.apply(a:wl)
    for nr in range(1, winnr('$'))
      if getwinvar(nr, '') is winvar
        execute nr 'wincmd w'
        break
      endif
    endfor
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
      execute self.opener
    endif
    if has_key(self.data, 'bufref')
      let bufid= self.data.bufref
      let bufnr= a:wl.__buffers[bufid].bufnr

      execute 'buffer' bufnr
    endif

    " make alias for window
    if has_key(self.data, 'walias')
      call setwinvar('.', 'vital_vim_windowlayout_walias', self.data.walias)
    endif

    if has_key(self.data, 'north') || has_key(self.data, 'south') ||
    \  has_key(self.data, 'east') || has_key(self.data, 'west') ||
    \  has_key(self.data, 'center')
      call a:wl.layout(a:wl.buffers(), self.data, 0)
    endif
  endfunction

  return opener
endfunction

let s:window_layout.__layouts.border= s:border_layout
unlet s:border_layout

let &cpo= s:save_cpo
unlet s:save_cpo
" vim: tabstop=2 shiftwidth=2 expandtab
