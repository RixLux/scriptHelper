#!/bin/bash

# Restore display first
/usr/bin/kscreen-doctor \
  output.eDP-1.enable \
  output.HDMI-A-1.disable \
  output.eDP-1.primary

# Small delay so KWin settles
sleep 0.5

# Close Steam Big Picture (non-blocking)
steam steam://close/bigpicture >/dev/null 2>&1

sleep 2

xdotool search --onlyvisible --class "steam" windowminimize

