let s:save_cpo= &cpo
set cpo&vim

function! s:_vital_loaded(V)
  let s:BM= a:V.import('Vim.BufferManager')
endfunction

function! s:_vital_depends()
  return ['Vim.BufferManager']
endfunction

let s:window_layout= {
\ '__buffer_managers': {},
\ '__layouts': {},
\ '__range': '',
\}

function! s:new(...)
  let wl= deepcopy(s:window_layout)

  " wl.__range= get(a:000, 0, 'tabpage')

  return wl
endfunction

" layout_data
" ---
" north:   {layout_data}
" south:   {layout_data}
" west:    {layout_data}
" east:    {layout_data}
" center:  {layout_data}
" bufname: 'buffer name'
" width:   30 or 0.3
" height:  30 or 0.3
" layout:  'layout name'
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

  let save_splitright= &splitright
  let save_splitbelow= &splitbelow

  set nosplitright
  set nosplitbelow

  try
    call self.__layouts[a:layout_data.layout].apply(self, a:layout_data)
  finally
    let &splitright= save_splitright
    let &splitbelow= save_splitbelow
  endtry
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

let s:border_layout= {}

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

  for opener in openers
    let prev_bufnr= bufnr('%')
    call opener.apply(a:wl)
    execute bufwinnr(prev_bufnr) 'wincmd w'
  endfor
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

    if has_key(self.data, 'width')
      " execute 'vertical resize' self.data.width
    endif

    if has_key(self.data, 'height')
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
