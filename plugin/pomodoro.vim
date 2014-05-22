"AUTHOR:   Greg Sexton <gregsexton@gmail.com>
"LICENSE:  Same terms as Vim itself (see :help license).

if exists("g:loaded_pomodoro") || v:version < 700
  finish
endif
let g:loaded_pomodoro = 1

let s:savecpo = &cpo
set cpo&vim

" Globals {{{1

if !exists("g:Pomo_ToDoTodayFilePath")
    let g:Pomo_ToDoTodayFilePath = expand("$HOME") . '/todotoday'
endif

if !exists("g:Pomo_ArchiveFilePath")
    let g:Pomo_ArchiveFilePath = expand("$HOME") . '/archive'
endif

if !exists("g:Pomo_MinWindowHeight")
    let g:Pomo_MinWindowHeight = expand("$HOME") . '/archive'
endif

" Commands: {{{1

"TODO: break out commands for splits, vertical and tab as well as normal.
command! -nargs=0 -bar PomodoroToDoToday call s:OpenToDoToday()
command! -nargs=0 -bar PomodoroOpenArchive call s:OpenArchive()
command! -nargs=0 -bar PomodoroPerformArchive call s:TransferAndOpenArchive()

" Functions: {{{1

fu! s:ResizeWindow()
    exec 'resize' max([line('$'), g:Pomo_MinWindowHeight])
endfu

fu! s:OpenToDoToday()
    exec "botright sp" g:Pomo_ToDoTodayFilePath
    call s:ResizeWindow()
    set winfixheight
    set ft=pomtodo
    1
endfu

fu! s:OpenArchive()
    exec "e" g:Pomo_ArchiveFilePath
    set ft=pomarchive
    $
endfu

fu! s:ArchiveHeader()
    return "* " . strftime("%Y-%m-%d")
endfu

fu! s:TransferAndOpenArchive() abort
    call s:OpenArchive()
    let lines = readfile(g:Pomo_ToDoTodayFilePath)
    if empty(lines)
        echomsg "Todo Today file is empty."
    else
        let failed = append(line('$'), "")
        let failed += append(line('$'), s:ArchiveHeader())
        let failed += append(line('$'), lines)
        if failed > 0
            echoerr "Failed to append to the archive file."
        endif
    endif
endfu

fu! s:PomodoroAlignCheckBoxes()
    let save_cursor = getpos('.')
    try
        if exists(":Tabularize")
            %Tabularize /\c[([][ X-_][)\]]/l1l0
        endif
    finally
        call setpos('.', save_cursor)
    endtry
endfu

fu! PomodoroAddTickBox(cnt)
    if getline('.') =~ '\[X]'
        exec 'normal! '.a:cnt.'A( )'
    else
        exec 'normal! '.a:cnt.'A[ ]'
    endif

    call s:PomodoroAlignCheckBoxes()
endfu

fu! PomodoroStartOrFinish()
    let time = s:PomodoroTimePassed()
    if time == -1
      call s:PomodoroStartTimer()
    elseif time < 25
      echo "Pomodoro active for ".time." minutes"
      " TODO: move active pomo to current line
    elseif time >= 25
      call s:PomodoroCompleteActive()
    endif
endfu

fu! s:PomodoroCompleteActive()
  let pomo_line = s:PomodoroFindActive()
  if pomo_line != 0
    exec pomo_line.'s/\([[(]\)_\([)\]]\)/\1X\2'
    call s:PomodoroStopTimer()
  else
    echoerr "Couldn't find active pomo marked with [_)"
  endif
endfu

" Returns number of minutes since started
" or -1 if inactive
fu! s:PomodoroTimePassed()
    let minutes = -1
    if getline(1) =~ '^Timer: \d\d'
        let start = system("date +'%s' --date=\'".substitute(getline(1), '^Timer: ', '', '')."'")
        let end = system("date +'%s'")
        let minutes = (end-start)/60
    endif
    return minutes
endfu

" returns line number or 0 if not found
fu! s:PomodoroFindActive()
    let [lnum, column] = searchpos('\([[(]\)_\([)\]]\)')
    return lnum
endfu

fu! s:PomodoroStartTimer()
    if getline(1) !~ '^Timer:'
      call append(0, 'Timer: stopped')
    endif
    let save_cursor = getpos('.')
    if save_cursor[1] != 1
      call PomodoroMarkTodoElapsed("_")
      exec ':0s/\v(Timer:)(.*)/\1 '.strftime('%Y-%m-%d %H:%M:%S'.'')
      call setpos('.', save_cursor)
      silent w
      call system('killall -USR1 i3status')
      call system('~/bin/timer 25m "pomodoro" &')
      echo "Started pomodoro"
    else
      echo "Move to line with task first"
    end
endfu

fu! s:PomodoroStopTimer()
    let save_cursor = getpos('.')
    if getline(1) =~ '^Timer: '
      :1d "_
    endif
    call append(0, 'Timer: stopped')
    call setpos('.', save_cursor)
endfu

fu! PomodoroMarkTodoElapsed(marker)
    "if a pomodoro has been allocated tick it off, otherwise add an unplanned pomodoro
    try
        exec 's/\([[(]\) \([)\]]\)/\1'.a:marker.'\2'.(a:marker == '-'?'/g':'')
    catch /E486/
        exec "normal!" "A(".a:marker.")"
    endtry
    call s:PomodoroAlignCheckBoxes()
endfu
"}}}1

let &cpo = s:savecpo
unlet s:savecpo

 " vim:fdm=marker
