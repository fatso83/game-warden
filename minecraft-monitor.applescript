-- Script to limit Minecraft usage to a certain number of hours per day and week
-- For the reference on AppleScript, see https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/introduction/ASLR_intro.html#//apple_ref/doc/uid/TP40000983-CH208-SW1

use framework "Foundation"
use framework "AppKit"
use scripting additions

property statusItem         : missing value
property interval           : 1.0
property monitoredProcess   : "minecraft"
property processGrepPattern : "java.*[m]inecraft"
property logFile            : missing value
property weeklyUsageLimit   : missing value
property dailyUsageLimit    : missing value
property plistPath          : missing value
property hasShownWarning    : false
property usageStateFile     : missing value
property exitMessage        : missing value

-- Record to store usage state
script timeBookkeeping
    property initialDailySeconds : 0
    property initialWeeklySeconds : 0
    property startOfCurrentSession : missing value
    property elapsed : 0
end script

on run argv
    if (count of argv) < 1 then
        do shell script ">&2 echo 'Error: Missing required argument (path to config.plist)'; exit 100"
    else
        set plistPath to item 1 of argv
        do shell script "[ -e " & quoted form of plistPath & " ] || (echo 'No such file: " & plistPath & "' && exit 200)"
        main()
    end if
end run

on main()
    set dataStorageDirectory to (POSIX path of (path to application support folder from user domain)) & "minecraft-monitor/"
    set weeklyUsageLimit to timeToSeconds(configWithDefault("weeklyMax", "05:00") & ":00")
    set dailyUsageLimit to timeToSeconds(configWithDefault("dailyMax", "01:00") & ":00")
    set exitMessage to configWithDefault("customExitMessage", "Timeout! Save and exit to avoid losing work.")

    set usageStateFile to dataStorageDirectory & "/mc-usage-state.txt"
    set logFile to dataStorageDirectory & "/mc-log.txt"

    do shell script "mkdir -p " & quoted form of dataStorageDirectory

    log("main: finished init")
    log("dataStorageDirectory=" & dataStorageDirectory)

    local processDetails, now
    local warnTimeDaily, warnTimeWeekly
    set timeBookkeeping's startOfCurrentSession to missing value

    loadTimeBookkeeping()

    repeat
        --log("has shown warning: " & hasShownWarning)
        tell application "System Events"
            set activeProcess to name of first process whose frontmost is true
        end tell

        set activeProcessSeemsLikeMatch to (activeProcess contains "java" or activeProcess contains monitoredProcess)

        if not activeProcessSeemsLikeMatch then
            if timeBookkeeping's startOfCurrentSession is not missing value then
                log("No active Minecraft process in the foreground. Ending current session.")
            end if
            set timeBookkeeping's startOfCurrentSession to missing value
        else
            set processDetails to (do shell script "pgrep -lf " & quoted form of processGrepPattern)

            if processDetails is not "" then
                resetStateIfRequired()

                if timeBookkeeping's startOfCurrentSession is missing value then
                    log("Minecraft process in the foreground. Starting new session.")
                    set timeBookkeeping's startOfCurrentSession to current date
                end if

                set timeBookkeeping's initialDailySeconds to timeBookkeeping's initialDailySeconds + elapsed()
                set timeBookkeeping's initialWeeklySeconds to timeBookkeeping's initialWeeklySeconds + elapsed()
                set timeBookkeeping's startOfCurrentSession to current date
                saveTimeBookkeeping()

                if currentDaily() > dailyUsageLimit or currentWeekly() > weeklyUsageLimit then
                    try
                        log("Killing Minecraft")
                        do shell script "pgrep -f " & quoted form of processGrepPattern & " | xargs kill"
                    end try
                end if

                showWarningIfCloseToThreshould()

            end if
        end if

        delay interval
    end repeat
end main

on showWarningIfCloseToThreshould()
    if not hasShownWarning then

        --log("timeBookkeeping: daily=" & timeBookkeeping's initialDailySeconds & ", weekly=" & timeBookkeeping's initialWeeklySeconds & ", session=" & (timeBookkeeping's startOfCurrentSession as string))
        local secondsBeforeWarning
        set secondsBeforeWarning to 60

        --log("dailyUsageLimit= " & dailyUsageLimit)
        --log("weeklyUsageLimit= " & weeklyUsageLimit)

        if currentDaily() > (dailyUsageLimit - secondsBeforeWarning) or currentWeekly() > (weeklyUsageLimit - secondsBeforeWarning) then
            log("showing warning")
            set hasShownWarning to true
            tell application "Finder" to activate
            delay 0.5
            display dialog exitMessage buttons {"OK"} default button "OK"
        end if
    end if
end showWarningIfCloseToThreshould

on readFileOrDefault(filePath, defaultValue)
    try
        return (do shell script "cat " & quoted form of filePath)
    on error
        writeFile(defaultValue, filePath, false)
        return defaultValue
    end try
end readFileOrDefault

on writeFile(textContent, filePath, append)
    if append is false then
        do shell script "echo " & quoted form of textContent & " > " & quoted form of filePath
    else
        do shell script "echo " & quoted form of textContent & " >> " & quoted form of filePath
    end if
end writeFile

on log(textContent)
    set timestamp to do shell script "date -u +\"%Y-%m-%dT%H:%M:%S%Z\""
    set logEntry to "[" & timestamp & "] " & textContent
    writeFile(logEntry, logFile, true)
end log

on timeToSeconds(timeString)
    set AppleScript's text item delimiters to ":"
    set {hrs, mins, secs} to text items of timeString
    set AppleScript's text item delimiters to ""
    return (hrs as integer) * 3600 + (mins as integer) * 60 + (secs as integer)
end timeToSeconds

on secondsToTime(totalSecs)
    set hrs to totalSecs div 3600
    set mins to (totalSecs mod 3600) div 60
    set secs to totalSecs mod 60
    return pad(hrs) & ":" & pad(mins) & ":" & pad(secs)
end secondsToTime

on pad(num)
    if num < 10 then
        return "0" & num
    end if
    return num as string
end pad

on formatDate(aDate)
    return ((year of aDate) as string) & pad(month of aDate as integer) & pad(day of aDate)
end formatDate

on weekNumber(aDate)
    return (do shell script "date -jf '%Y-%m-%d' '" & (year of aDate) & "-" & pad(month of aDate as integer) & "-" & pad(day of aDate) & "' '+%W'") as integer
end weekNumber

on configWithDefault(key, defaultValue)
    try
        return do shell script "/usr/libexec/PlistBuddy -c 'Print " & key & "' " & quoted form of plistPath
    on error
        return defaultValue
    end try
end configWithDefault

on resetDbCountersIfNewDayOrWeek()
    try
        tell application "System Events" to set fileDate to modification date of file usageStateFile
        set fileDateString to formatDate(fileDate)
        set currentDateString to formatDate(current date)
        if fileDateString is not currentDateString then
            log("Reset daily usage: " & fileDateString & " != " & currentDateString)
            set timeBookkeeping's initialDailySeconds to 0
        end if

        set fileWeekNumber to weekNumber(fileDate)
        set currentWeekNumber to (do shell script "date +%W") as integer
        if fileWeekNumber is not currentWeekNumber then
            log("Reset weekly usage: Week " & fileWeekNumber & " != " & currentWeekNumber)
            set timeBookkeeping's initialWeeklySeconds to 0
        end if

        saveTimeBookkeeping()
    on error err
        log("Weekly reset error: " & err)
    end try
end resetDbCountersIfNewDayOrWeek

on resetStateIfRequired()
    --log("Checking any state needs resetting")
    resetDbCountersIfNewDayOrWeek()

    if timeBookkeeping's initialWeeklySeconds is 0 or timeBookkeeping's initialWeeklySeconds is 0 then
        -- reset the flag so that we can show it again
        hasShownWarning = false
    end if
end resetStateIfRequired

on saveTimeBookkeeping()
    set dailyTime to secondsToTime(timeBookkeeping's initialDailySeconds)
    set weeklyTime to secondsToTime(timeBookkeeping's initialWeeklySeconds)
    set content to dailyTime & "," & weeklyTime
    writeFile(content, usageStateFile, false)
end saveTimeBookkeeping

on loadTimeBookkeeping()
    try
        set content to readFileOrDefault(usageStateFile, "00:00:00,00:00:00")
        set AppleScript's text item delimiters to ","
        set {daily, weekly} to text items of content
        set AppleScript's text item delimiters to ""
        set timeBookkeeping's initialDailySeconds to timeToSeconds(daily)
        set timeBookkeeping's initialWeeklySeconds to timeToSeconds(weekly)
    on error err
        log("Failed to load usage state: " & err)
        set timeBookkeeping's initialDailySeconds to 0
        set timeBookkeeping's initialWeeklySeconds to 0
    end try
end loadTimeBookkeeping

on elapsed()
    set now to current date
    return now - (timeBookkeeping's startOfCurrentSession)
end elapsed

on currentDaily()
    return timeBookkeeping's initialDailySeconds + elapsed()
end currentDaily

on currentWeekly()
    return timeBookkeeping's initialWeeklySeconds + elapsed()
end currentWeekly

