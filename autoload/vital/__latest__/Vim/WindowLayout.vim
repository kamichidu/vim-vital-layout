let s:save_cpo= &cpo
set cpo&vim

function! s:_vital_loaded(V)
endfunction

function! s:_vital_depends()
  return []
endfunction

let s:layouts= {}

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
function! s:layout(layout_data)
  if !has_key(a:layout_data, 'layout')
    throw "vital: Vim.WindowLayout: You must specify `layout'."
  elseif !has_key(s:layouts, a:layout_data.layout)
    throw printf("vital: Vim.WindowLayout: No such layout `%s'.", a:layout_data.layout)
  endif

  let save_splitright= &splitright
  let save_splitbelow= &splitbelow

  set nosplitright
  set nosplitbelow

  try
    call s:layouts[a:layout_data.layout].apply(a:layout_data)
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

function! s:border_layout.apply(data)
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
    call opener.apply()
    execute bufwinnr(prev_bufnr) 'wincmd w'
  endfor
endfunction

function! s:border_layout.make_opener(opener, data)
  let opener= {
  \ 'opener': a:opener,
  \ 'data':   a:data,
  \}

  function! opener.apply()
    if !empty(self.opener)
      if has_key(self.data, 'bufname')
        execute self.opener self.data.bufname
      else
        execute self.opener
      endif
    endif

    if has_key(self.data, 'north') || has_key(self.data, 'south') ||
    \  has_key(self.data, 'east') || has_key(self.data, 'west') ||
    \  has_key(self.data, 'center')
      call s:layout(self.data)
    endif
  endfunction

  return opener
endfunction

let s:layouts.border= s:border_layout
unlet s:border_layout

let &cpo= s:save_cpo
unlet s:save_cpo
" vim: tabstop=2 shiftwidth=2 expandtab
