; Author: Thomas Churchman
; https://github.com/Beskhue
; 
; Filter joins and parts, smartly.
; 
; Copyright (c) 2016 Thomas Churchman
; 
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
; 
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
; 
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

on *:START: {
  ; Called on script start. Read settings from ini and set cleanup timer.
  SET %timeout $readini(smartfilter.ini, settings, timeout)
  SET %minNicks $readini(smartfilter.ini, settings, minNicks)
  if (%timeout == $null) {
    SET %timeout 300
  }
  if (%minNicks == $null) {
    SET %minNicks 20
  }
  timerSMARTFILTERCLEANUP 0 300 cleanup
}

alias isIdle {
  ; Determines whether the given timestamp (in settings) counts as being idle.
  if ($1 == $null) {
    return $true
  }
  elseif ($ctime > $calc($1 + %timeout)) {
    return $true
  }
  else {
    return $false
  }
}

alias cleanup { 
  ; Cleanup the used activity timestamps.
  var %n = $var(lastTalk. $+ *,0), %var, %varVal
  while (%n >= 1) {
    %var = $gettok($var(lastTalk. $+ *,%n),2-,46)
    %varVal = %lastTalk. [ $+ [ %var ] ]
    if ($isIdle(%varVal)) {
      UNSET %lastTalk. [ $+ [ %var ] ]
    }
    dec %n
  }
}

on *:TEXT:*:#: {
  ; Called when a nick speaks in a channel. Update the activity timestamp for
  ; the given nick in the appropriate channel and network.
  SET %lastTalk. [ $+ [ $network ] $+ . $+ [ $chan ] $+ . $+ [ $nick ] ] $ctime
}

on ^*:JOIN:#: {
  ; Called when a nick joins a channel. Checks whether they were active in
  ; the given channel and network, and if not, surpresses the join message.
  if ($nick($chan,0) >= %minNicks && $isIdle(%lastTalk. [ $+ [ $network ] $+ . $+ [ $chan ] $+ . $+ [ $nick ] ])) {
    HALT
    ;$nick($chan,0) only hide when larger than threshold
  }
}

on ^*:PART:#: {
  ; Called when a nick leaves a channel. Checks whether they were active in
  ; the given channel and network, and if not, surpresses the join message.
  if ($nick($chan,0) >= %minNicks && $isIdle(%lastTalk. [ $+ [ $network ] $+ . $+ [ $chan ] $+ . $+ [ $nick ] ])) {
    HALT
  }
}

on ^*:QUIT: {
  ; Called when a nick quits. For each common channel, checks whether they 
  ; were active in the given channel and network. If so: send a (custom) 
  ; quit message. Surpresses all default quit messages.
  var %i = 0, %chan
  while (%i < $comchan($nick,0)) {
    inc %i
    %chan = $comchan($nick,%i)
    if ($nick(%chan,0) < %minNicks || !$isIdle(%lastTalk. [ $+ [ $network ] $+ . $+ [ %chan ] $+ . $+ [ $nick ] ])) {
      echo $colour(quit) -t %chan * $nick ( [ $+ [ $fulladdress ] $+ ] ) Quit ( [ $+ [ $1- ] $+ ] )
    }
  }

  HALTDEF
}

dialog smartFilter {
  ; Setup settings dialog.
  title "Smart Join and Part Filter"
  size -1 -1 260 235
  text "Smart Join and Part Filter v1.2 by Beskhue. The idle timeout controls after how many seconds of idling in a specific channel joins/parts of a nick will not be shown in that channel.",1,15 15 230 50
  box "Idle timeout (seconds)", 2, 15 75 230 48
  edit %timeout, 3, 20 93 220 20
  box "Min. nicks on channel to enable filter", 4, 15 135 230 48
  edit %minNicks, 5, 20 153 220 20
  button "Ok", 6, 15 195 100 20, ok
  button "Cancel", 7, 145 195 100 20, cancel
}

alias smartfilter { 
  ; Show the settings dialog.
  if (!$dialog(smartFilter)) { 
    dialog -m smartFilter smartFilter
  } 
}

on *:dialog:smartfilter:*:*: {
  ; Called when a settings dialog event occurs.
  if ($devent == init) {
    ; Called on dialog initialization.
    did -ra $dname 3 $iif(%timeout,%timeout,-No settings-)
  }
  elseif ($devent == edit) {
    ; Called when the data was edited.
    if($did == 3)
    {
      set %timeout $did(3)
      writeini smartfilter.ini settings timeout %timeout
    }
    if($did == 5)
    {
      set %minNicks $did(5)
      writeini smartfilter.ini settings minNicks %minNicks
    }
  }
}

menu * {
  ; Add script to the context menu.
  -
  Join/Part Filter
  .Settings: smartfilter
  .-
  .About: echo -at ==------------------------oOo------------------------== | echo -at - Smart Join and Part Filter v1.2 by Beskhue. | echo -at - Contact me at chat.freenode.net: Besk. | echo -at - https://github.com/Beskhue | echo -at ==------------------------oOo------------------------==
  -
}
