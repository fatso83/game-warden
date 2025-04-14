# minecraft-monitor
Monitor screen time on macOS of Minecraft Java version

This is a straight up copy of "jhopgei"'s Applescript shared on the
[Mojang bug tracker (MCL-14705)](https://bugs.mojang.com/browse/MCL/issues/MCL-14705).
I asked ChatGPT to translate the field names into English and made the user home folder 
irrespective of the current user (it was basically hardcoded to `/Users/jhopgei`).

I also made the script uncompiled, meaning it is simple to view and edit with a 
simple text editor, and of course, easily tracked in Git.

# Installation
You can customise this as you want, for instance changing the paths 
to avoid cluttering your home directory. Just remember to update
all the other paths.

## Copy the script to your home directory
- Open [the raw script](https://raw.githubusercontent.com/fatso83/minecraft-monitor/refs/heads/main/minecraft-monitor.applescript)
- Save the content to your home directory (Cmd-S on a Mac will prompt you where to save the file)

## Script to put in the crontab
Assuming you put the script in your home directory you would typically 
have a script like this that you can put whereever you like, but for simplicity
just put it in the home directory (unless you know what you are doing):

```bash
#!/usr/bin/env bash
NAME=minecraft-monitor.applescript

if ! pgrep -f "osascript.*${NAME}" >/dev/null; then
    osascript "$HOME/${NAME}" &
fi
```
