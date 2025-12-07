#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# Wrapper script for cool-retro-term on KDE Plasma
#
# Purpose: Force Qt Quick Controls to use Material Dark theme for readable UI
#
# Root cause: cool-retro-term's Qt Quick settings UI has hardcoded colors that
# don't respect system themes. This is an upstream bug - the app uses raw QML
# Text elements instead of themed Label components in some places.
#
# Workaround: Material Dark theme makes MOST of the UI readable, though some
# labels remain invisible due to hardcoded colors in the app's QML.
#
# This wrapper ONLY affects cool-retro-term. Other Qt apps use KDE's native
# theming via plasma-integration and qqc2-desktop-style.
#
# See: docs/runbooks/QT_THEMING_KDE.md

# Force Material Dark theme for this app only
export QT_QUICK_CONTROLS_STYLE=Material
export QT_QUICK_CONTROLS_MATERIAL_THEME=Dark

# Execute cool-retro-term
if [ -x /usr/bin/cool-retro-term ]; then
    exec /usr/bin/cool-retro-term "$@"
else
    echo "Error: cool-retro-term not found at /usr/bin/cool-retro-term" >&2
    exit 1
fi
