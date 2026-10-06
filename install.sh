#!/bin/zsh
# Builds EyeBreak and registers it with launchd so it starts at login.
# Usage: ./install.sh [minutes]   (default 20)
set -e
cd "${0:A:h}"
MINUTES=${1:-20}
LABEL=local.eyebreak
PLIST=~/Library/LaunchAgents/$LABEL.plist

swiftc -O -o eyebreak eyebreak.swift

mkdir -p ~/Library/LaunchAgents
cat > $PLIST <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key><array><string>$PWD/eyebreak</string><string>$MINUTES</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
    <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PLIST

launchctl bootout gui/$(id -u)/$LABEL 2>/dev/null || true
launchctl bootstrap gui/$(id -u) $PLIST
echo "EyeBreak installed: break every $MINUTES min of screen time. Look for the eye icon in your menu bar."
