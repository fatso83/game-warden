# Testing notes
AppleScript is not so unit test friendly for someone new to the language, so I have had to manually test the logic.

## Logic related to handling date and week changes

Just use `touch` to change the mtime:
```
touch -t 202507091530 /opt/minecraft-monitor/data/mc-usage-state.txt
```
