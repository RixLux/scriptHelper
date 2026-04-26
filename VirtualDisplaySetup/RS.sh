#!/bin/bash

/usr/bin/kscreen-doctor \
  output.eDP-1.enable \
  output.HDMI-A-1.disable \
  output.eDP-1.primary && shutdown now
