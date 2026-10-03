#!/bin/sh

# dwm SIGHUP-restart re-runs this script. Guard each daemon with `pgrep -x`
# so subsequent invocations are no-ops instead of spawning duplicates.

# ─── HiDPI / 4K displays ──────────────────────────────────────────────
# There's no single scaling knob — dwm doesn't scale, so each toolkit has
# to be told separately. If type is tiny on a 4K screen, uncomment this
# whole block and log out / back in.
#
# The values give ~200% (good for a 4K laptop or 27"). For ~150%, use
# Xft.dpi 144, drop GDK_SCALE, and set the cursor sizes to 36. Exports live
# up here so apps launched from sxhkd inherit them.
#
# printf 'Xft.dpi: 192\nXcursor.size: 48\n' | xrdb -merge   # X apps, fonts + cursor
# export GDK_SCALE=2          # GTK app widgets (thunar, geany)
# export GDK_DPI_SCALE=0.5    # cancel GTK's double font scaling on top of GDK_SCALE
# export QT_AUTO_SCREEN_SCALE_FACTOR=1   # Qt apps follow Xft.dpi
# export XCURSOR_SIZE=48
# ──────────────────────────────────────────────────────────────────────

# native-bar fallback — uncomment together with showbar=1 (or Mod+Ctrl+b)
# pgrep -x slstatus  >/dev/null || slstatus &
pgrep -x lxpolkit  >/dev/null || lxpolkit &

# quickshell bar (`-n` exits if already running, so the SIGHUP re-run of
# this script is a no-op while the bar is up)
if command -v qs >/dev/null 2>&1; then
	qs -p "$HOME/.config/suckless/quickshell" -d -n >/dev/null 2>&1 &
fi

# wallpaper (one-shot — feh exits after setting bg, no dedup needed)
feh --bg-fill "$HOME/.config/suckless/wallpaper/butterhead1.png" &

# DISABLED-FIRST-TEST: # sxhkd — start once; reload config via `pkill -USR1 sxhkd` after editing rc
# DISABLED-FIRST-TEST: if hash sxhkd >/dev/null 2>&1; then
# DISABLED-FIRST-TEST: 	pgrep -x sxhkd >/dev/null || sxhkd -c "$HOME/.config/suckless/sxhkd/sxhkdrc" &
# DISABLED-FIRST-TEST: fi

pgrep -x dunst >/dev/null || dunst -config ~/.config/suckless/dunst/dunstrc &
pgrep -x picom >/dev/null || picom --config ~/.config/suckless/picom/picom.conf -b &

# hide cursor when idle (mitigates dwm sloppy-focus typing-in-wrong-window)
# optional — install with `apt install unclutter`
if command -v unclutter >/dev/null 2>&1; then
	pgrep -x unclutter >/dev/null || unclutter -idle 1 -root &
fi

# re-apply the picker's saved window gap — every dwm restart resets gaps
# to the compiled default; the delay lets dwm's event loop come up first
if [ -r "$HOME/.config/suckless/dwm-gaps" ]; then
	(sleep 1; xprop -root -f _DWM_SETGAPS 32c \
		-set _DWM_SETGAPS "$(cat "$HOME/.config/suckless/dwm-gaps")") &
fi

# First-login welcome (shown once, dismissable)
if [ ! -f "$HOME/.cache/dwm/welcomed" ]; then
	mkdir -p "$HOME/.cache/dwm"
	touch "$HOME/.cache/dwm/welcomed"
	(sleep 3; notify-send -u normal -t 15000 \
		"Welcome to dwm" \
		"Press Super + / anytime to see all keybindings.&#10;See ~/QUICKSTART-dwm.md for a cheat sheet.") &
fi
