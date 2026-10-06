#!/bin/zsh
# Stops EyeBreak and removes it from login.
LABEL=local.eyebreak
launchctl bootout gui/$(id -u)/$LABEL 2>/dev/null
rm -f ~/Library/LaunchAgents/$LABEL.plist
echo "EyeBreak removed."
