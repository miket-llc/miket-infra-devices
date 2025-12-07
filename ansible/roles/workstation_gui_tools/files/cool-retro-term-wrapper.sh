#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# Wrapper script for cool-retro-term that fixes Qt theming issues
# Sets Qt environment variables to ensure proper theme rendering

# Force Qt to use KDE platform theme (if available)
# This ensures Qt applications respect KDE system theme
export QT_QPA_PLATFORMTHEME="${QT_QPA_PLATFORMTHEME:-kde}"

# Force Qt style to Breeze (KDE default) if platform theme doesn't work
# This ensures readable text colors
export QT_STYLE_OVERRIDE="${QT_STYLE_OVERRIDE:-Breeze}"

# Set Qt color scheme to match system
# For dark themes, this ensures proper contrast
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"

# Additional Qt settings for better theme integration
# Force Qt to use system color scheme
export QT_AUTO_SCREEN_SCALE_FACTOR=1

# If qt5ct/qt6ct is installed, use it for better theme control
if command -v qt5ct >/dev/null 2>&1; then
    export QT_QPA_PLATFORMTHEME=qt5ct
elif command -v qt6ct >/dev/null 2>&1; then
    export QT_QPA_PLATFORMTHEME=qt6ct
fi

# Find cool-retro-term binary
COOL_RETRO_TERM_BIN=""
if command -v cool-retro-term >/dev/null 2>&1; then
    COOL_RETRO_TERM_BIN="cool-retro-term"
elif [ -f /usr/bin/cool-retro-term ]; then
    COOL_RETRO_TERM_BIN="/usr/bin/cool-retro-term"
elif [ -f /usr/local/bin/cool-retro-term ]; then
    COOL_RETRO_TERM_BIN="/usr/local/bin/cool-retro-term"
else
    # Try to find it in common locations
    COOL_RETRO_TERM_BIN=$(find /usr -name "cool-retro-term" -type f 2>/dev/null | head -1)
fi

if [ -z "$COOL_RETRO_TERM_BIN" ]; then
    echo "Error: cool-retro-term not found" >&2
    exit 1
fi

# Execute cool-retro-term with all arguments
exec "$COOL_RETRO_TERM_BIN" "$@"


