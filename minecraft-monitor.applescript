use scripting additions
use framework "Foundation"
use framework "AppKit"

property statusItem         : missing value
property interval           : 1.0
property dailyUsageTime     : "00:00:00"
property weeklyUsageTime    : "00:00:00"
property monitoredProcess   : "minecraft"
property processGrepPattern : "[m]inecraft"
property dailyUsageFile     is missing value
property weeklyUsageFile    is missing value
property logFile            is missing value
property weeklyUsageLimit   is missing value
property dailyUsageLimit    is missing value
property plistPath          is missing value

on run argv
	if (count of argv) < 1 then
		do shell script ">&2 echo 'Error: Missing required argument (path to config.plist)'; exit 1"
	else
        set plistPath to item 1 of argv
        do shell script " [ -e " & plistPath & " ] || (echo 'No such file: " & plistPath & "' && exit 1)"
        main()
	end if
end run

on main()
    -- read hour:minute from the config file
    set dataStorageDirectory    to  configWithDefault("dataDir", "/opt/minecraft-monitor/data") 
    set weeklyUsageLimit        to  configWithDefault("weeklyMax", "05:00") & ":00"
    set dailyUsageLimit         to  configWithDefault("dailyMax", "01:00") & ":00"

    set dailyUsageFile  to dataStorageDirectory & "/mc-daily-usage.txt"
    set weeklyUsageFile to dataStorageDirectory & "/mc-weekly-usage.txt"
    set logFile         to dataStorageDirectory & "/mc-usage-log.txt"
    
    do shell script "mkdir -p " & dataStorageDirectory
    writeFile("", logFile, 0)

    -- Reset daily usage file if the day changed
    try
        tell application "System Events" to set fileDate to creation date of file dailyUsageFile
        set fileDateString to formatDate(fileDate)
        set currentDateString to formatDate(current date)
        if fileDateString ≠ currentDateString then
            writeFile("Reset daily usage: " & fileDateString & " ≠ " & currentDateString, logFile, 1)
            do shell script "rm -f " & quoted form of dailyUsageFile
            writeFile(dailyUsageTime, dailyUsageFile, 0)
        end if
    on error err
        writeFile("Daily reset error: " & err, logFile, 1)
    end try

    -- Reset weekly usage file if week changed
    try
        tell application "System Events" to set fileDate to creation date of file weeklyUsageFile
        set fileWeekNumber to weekNumber(fileDate)
        set currentWeekNumber to (do shell script "date +%W") as integer
        if fileWeekNumber ≠ currentWeekNumber then
            writeFile("Reset weekly usage: Week " & fileWeekNumber & " ≠ " & currentWeekNumber, logFile, 1)
            do shell script "rm -f " & quoted form of weeklyUsageFile
            writeFile(weeklyUsageTime, weeklyUsageFile, 0)
        end if
    on error err
        writeFile("Weekly reset error: " & err, logFile, 1)
    end try

    local startDate
    local processDetails
    local elapsed
    local now
    local initialDailySeconds
    local initialWeeklySeconds
    set startDate to missing value

    repeat
        tell application "System Events"
            set activeProcess to name of first process whose frontmost is true
        end tell

        if activeProcess contains "java" or activeProcess contains monitoredProcess then

            set processDetails to (do shell script "pgrep -lf " & quoted form of processGrepPattern)
            if processDetails ≠ "" then

                if startDate is missing value then
                    -- Mark start of monitoring session
                    set startDate to current date

                    -- Read initial times from file
                    set initialDailySeconds to timeToSeconds(readFileOrDefault(dailyUsageFile, "00:00:00"))
                    set initialWeeklySeconds to timeToSeconds(readFileOrDefault(weeklyUsageFile, "00:00:00"))
                end if

                -- Get current time and calculate elapsed
                set now to current date
                set elapsed to now - startDate -- seconds

                set currentDaily to initialDailySeconds + elapsed
                set currentWeekly to initialWeeklySeconds + elapsed
                set dailyUsageTime to secondsToTime(currentDaily)

                writeFile(dailyUsageTime, dailyUsageFile, 0)
                writeFile(secondsToTime(currentWeekly), weeklyUsageFile, 0)

                my updateStatusItem("Minecraft Today: " & dailyUsageTime & " Week: " & weeklyUsageTime)

                if currentDaily > timeToSeconds(dailyUsageLimit) or currentWeekly > timeToSeconds(weeklyUsageLimit) then
                    try
                        do shell script "pgrep -f " & quoted form of processGrepPattern & " | xargs kill"
                    end try
                end if
            end if
        else
            set startDate to missing value
        end if

        delay interval
    end repeat
end main

on updateStatusItem(statusText)
	try
		current application's NSStatusBar's systemStatusBar()'s removeStatusItem:statusItem
	on error err
		writeFile("Status bar removal error: " & err, logFile, 1)
	end try
	set my statusItem to current application's NSStatusBar's systemStatusBar's statusItemWithLength:(current application's NSVariableStatusItemLength)
	statusItem's setTitle:statusText
end updateStatusItem

on readFileOrDefault(filePath, defaultValue)
	try
		return (do shell script "cat " & quoted form of filePath)
	on error
		writeFile(defaultValue, filePath, 0)
		return defaultValue
	end try
end readFileOrDefault

on writeFile(textContent, filePath, eofMode)
	if eofMode = 0 then
		do shell script "echo " & quoted form of textContent & " > " & quoted form of filePath
	else
		do shell script "echo " & quoted form of textContent & " >> " & quoted form of filePath
	end if
end writeFile

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
       if num < 10 then return "0" & num
       return num as string
end pad

on formatDate(aDate)
       return ((year of aDate) as string) & pad(month of aDate as integer) & pad(day of aDate)
end formatDate

on weekNumber(aDate)
       return (do shell script "date -jf '%Y-%m-%d' '" & (year of aDate) & "-" & pad(month of aDate as integer) & "-" & pad(day of aDate) & "' '+%W'") as integer
end weekNumber

on configWithDefault(key, defaultValue)
    -- PlistBuddy could fail if the value does not exist, fall back to default
    try
        return do shell script "/usr/libexec/PlistBuddy -c 'Print " & key & "' " & quoted form of plistPath
    on error
        return defaultValue
    end try
end configWithDefault
