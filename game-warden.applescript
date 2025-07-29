#!/usr/bin/env osascript
use framework "Foundation"
use scripting additions

property reportInterval : 5.0
property fifoPath       : "/tmp/game-warden.fifo"
property errorLogPath   : POSIX path of (path to home folder) & "game-warden-client.log"

on run
    set currentUser to do shell script "whoami"
    
    repeat
        if not (do shell script "test -p " & quoted form of fifoPath & " && echo yes || echo no") is "yes" then
            do shell script "echo " & quoted form of ("[ERROR] FIFO missing at " & fifoPath) & " >> " & quoted form of errorLogPath
        else
            try
                tell application "System Events"
                    set frontProc to first process whose frontmost is true
                    set procName to name of frontProc
                    set procPID to unix id of frontProc
                end tell

                set msg to currentUser & " " & procPID & " " & procName
                do shell script "echo " & quoted form of msg & " > " & quoted form of fifoPath

            on error errMsg number errNum
                do shell script "echo " & quoted form of ("[ERROR] " & errMsg) & " >> " & quoted form of errorLogPath
            end try
        end if

        delay reportInterval
    end repeat
end run
