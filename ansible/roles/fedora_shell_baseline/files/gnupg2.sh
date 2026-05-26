# Managed by Ansible role: fedora_shell_baseline
#
# Replaces Fedora's stock /etc/profile.d/gnupg2.sh (from gnupg2 package).
# Fedora 44's coreutils-9.10 made `tty` print
#   "tty: ttyname error: No such device"
# to stderr in some pty edge cases (Wayland/wezterm, tmux reattach, etc.)
# instead of the older quiet "not a tty" + rc=1. The stock script runs
# `tty` unredirected during every interactive shell startup, so the error
# surfaces every time a new shell opens.
#
# This variant matches the upstream RHEL gnupg2-2.4.9-7 fix
# ("Make the profile scripts more robust", RHEL-166369) by silencing
# the diagnostic. GPG_TTY ends up empty when stdin is not a tty,
# which is the documented behavior gpg-agent already handles.
case "$-" in *i*)
    export GPG_TTY=$(tty 2>/dev/null) ;;
esac
