# quickshell shell for dwm

The full desktop shell: bar, popups, wallpaper-driven theming, and the
network app. dwm needs the **quickshell-extbar patch**
(`suckless/dwm/patches/dwm-quickshell-extbar.diff`, applied in this tree's
dwm.c) — a hard dependency that provides everything the shell relies on:

- dock windows are adopted unmanaged and their `_NET_WM_STRUT_PARTIAL`
  reserves screen space, re-tiling live when the bar height changes
  (mainline dwm ignores struts and would tile the bar);
- `_DWM_SELTAGS` on the root window carries the raw tagset bitmask
  (faithful for multi-tag views, unlike lossy `_NET_CURRENT_DESKTOP`),
  refreshed on every tag mutation as the bar's change signal;
- root `_NET_CURRENT_DESKTOP` and client `_NET_WM_DESKTOP` ClientMessages
  are handled, so `xdotool set_desktop` / `set_desktop_for_window` work
  for bar clicks.

Occupancy comes from each client's `_NET_CLIENT_INFO` tag bitmask
(ewmhtags patch). Urgency is not exported by dwm — `urgtags` stays 0.
Sticky/all-tag windows light every occupancy dot; that matches dwm
semantics.

Launch: `qs -p ~/.config/suckless/quickshell` (autostart.sh does this), or
`scripts/bar restart|log` which handles the `-p` flag.

## Portability contract (read before porting to another WM)

The **reference implementation** lives in bspwm-setup
(`bspwm/quickshell/`); this tree is a vendored copy (like openbox-setup's).
Cohesion across projects comes from keeping the shared files byte-identical
— `diff -r` between two projects' quickshell dirs should show only the
files listed as WM-specific.

**Shared verbatim (do not fork per WM):**
`Theme.qml` `BarModule.qml` `Popout.qml` `WallpaperPicker.qml`
`Weather.qml` `NotifyPopup.qml` `Network.qml` `CalendarPopup.qml`
`Clock.qml` `Media.qml` `Metrics.qml` `Volume.qml` `Tray.qml` `Bell.qml`
`CapsLock.qml` `Screenshot.qml` `PowerButton.qml` `Launcher.qml` `Title.qml`
`Sys.qml` `TweakSlider.qml` `Tags.qml` `Commands.qml` `MicMute.qml`
`MediaPopup.qml` `Updates.qml` — plus `scripts/wallpaper-theme`
(all but its WM tail), `scripts/network`, `scripts/bar`, and the
`quickshell-network/` app. (`Tags.qml` is shared: it renders purely from
Wm's seltags/occtags/urgtags bitmasks and is byte-identical in every port.)

**WM-specific (this project's versions):**
- `Wm.qml` — dwm backend: `xprop -spy` on `_DWM_SELTAGS`,
  `_NET_NUMBER_OF_DESKTOPS`, `_NET_CLIENT_LIST`; occupancy from
  `_NET_CLIENT_INFO`; actions via xdotool (handled by the extbar patch).
- `Bar.qml` — no padding sync and no place timer: the extbar patch honors
  this window's strut directly. Right-click on empty bar opens the
  layout/tweaks picker.
- `LayoutButton.qml` `LayoutPicker.qml` — dwm-backed versions: the button
  shows the current layout's config.h glyph (scroll cycles, click opens
  the picker); right-click on empty bar opens the same popup, which is
  this port's one tweaks surface (like bspwm's — openbox's separate
  `BarTweaks.qml` has no counterpart here). The picker is a glyph-tile
  grid of all fifteen layouts, applied by writing a layouts[] index to
  `_DWM_SETLAYOUT` (extbar patch §18e), current one read from
  `_DWM_LAYOUT`; a Desktop section (§18f): window gap (persisted to the
  `dwm-gaps` state file, re-applied by autostart.sh), master width and
  master count (pertag — they tweak the focused tag and reset with dwm;
  not persisted; they dim in layouts whose arrange ignores mfact/
  nmaster — flags in Wm.layouts, keep them and the glyph/order table in
  sync with `layouts[]` in dwm's config.def.h); and a Bar section: bar
  height / element scale, persisted to the state files Theme.qml
  watches. bspwm's `LayoutIcon.qml` + `scripts/layout` have no
  counterpart here; border width has no slider (compile-time in dwm).
- Tail of `scripts/wallpaper-theme` — dwm: a marker-bracketed
  Xresources block (dwm + st colors) + `xrdb -load` + dunst respawn +
  `pkill -HUP dwm`. The markers still read `! BEGIN/END dwm-thememenu`
  after the retired theme switcher that once owned them, so upgraded
  installs replace the old block instead of stacking a second one.
- `Follow.qml` — the native bar's `>`/`v` window-follow indicator as a
  clickable module (`_DWM_FOLLOW`/`_DWM_SETFOLLOW`; Mod+n stays in sync).
- `qmldir`, this `README.md`.

**Interfaces that must never drift between projects:**
- `polybar/colors.ini` palette keys (background, background-alt, foreground,
  primary, secondary, alert, disabled, border) — Theme.qml's watch target.
- `wallpaper-theme <image> <8 semantic> <16 ansi>` argument order.
- IPC targets: `wallpapers` (toggle/random/set), `tweaks` (toggle),
  `wm` (refreshLayout, bspwm only), `layouts` (toggle, dwm only —
  `tweaks` opens the same popup here).
- Script names in `scripts/`: wallpaper-theme, network, bar, layout
  (layout is bspwm-only).
- Bar-tweaks state file names: `bar-height` and `bar-scale` in the WM
  config dir (Theme.qml's watch targets, plain integers/floats); dwm
  adds `dwm-gaps` (consumed by autostart.sh, not Theme.qml).

## Live theming

`Theme.qml` watches `polybar/colors.ini`, which `scripts/wallpaper-theme`
rewrites on every wallpaper pick — the bar re-colors in place, no restart.
The picker extracts the palette in QML (Canvas histogram; fidelity mode for
flat designed art, pastel interpretation for photos). A beacon check runs
first: a small, bright, hue-distinct cluster — a lamp, neon sign, sunset
sliver — becomes the accent even though it barely registers in the
histogram, and the dominant field hue steps down to secondary; images
without one behave exactly as before and the script fans it
out to bar/rofi/dunst/kitty/GTK/dwm borders/st. Dunst's config is symlinked
from `~/.config/dunst/dunstrc` so D-Bus-spawned dunst is themed too.
This is the single theming system on dwm — the wallpaper dictates every
color (the old dwm-thememenu preset switcher was removed).

## Controls

| Module   | Left click        | Right click   | Middle       | Scroll          |
|----------|-------------------|---------------|--------------|-----------------|
| Launcher | rofi drun         | wallpaper picker | random wallpaper | —         |
| Tags     | focus             | —             | send window  | cycle tags      |
| (empty bar) | —              | layout/tweaks picker | —     | —               |
| Follow   | toggle window-follow (arrow lit = following) | — | — | —          |
| Media    | play/pause        | now-playing popup | dismiss until track changes | prev/next track |
| Weather  | 3-day forecast popup | rofi config (city/zip · °C/°F/auto) | — | — |
| Volume   | mute              | pavucontrol   | —            | ±2%             |
| Network  | network app       | nm-connection-editor | —     | —               |
| Tray     | activate          | menu          | secondary    | —               |
| Bell     | (appears only while DND is on — click resumes, right-click history) |||
| Clock    | calendar popup    | —             | —            | —               |
| Updates  | (appears only with pending apt upgrades — click opens upgrade terminal, middle re-checks) |||
| Mic      | (appears only while the mic is muted — click unmutes) |||
| Caps     | (indicator — appears only while caps lock is on) |||
| Screenshot | flameshot gui   | —             | —            | —               |
| Commands | command menu popup | —            | —            | —               |

Keybindings: `super+shift+p` wallpaper picker · `super+shift+n` network
app · `super+shift+m` command menu.

The command menu (󰘳, right end of the bar) is the quick-settings panel:
actions with **no other bar surface**. A 2-col grid of toggle pills
(filled = on; right-click opens the full tool where one exists —
mic → pavucontrol's input tab): power
profile cycle, keep-screen-awake, mic mute, night light, DND (right-click = notification history; the Bell module is
CapsLock-pattern now — on the bar only while DND is active, so the
silenced state stays glanceable), and a pomodoro (countdown + drain bar
show on the 󰘳 pill itself; right-click cycles 15/25/45/60 presets,
scroll nudges ±5 min, idle only). Below: brightness slider (laptops
with a backlight only), then
launcher rows — apt updates, keybind help, bar restart, and the rofi
power menu (which replaced the old PowerButton module — the file stays
for other ports). Stateful glanceable modules (volume, network, DND,
media) never move in here. IPC: `commands toggle`.

Bar tweaks: right-click an empty stretch of the bar (or click the layout
button) for the picker's Bar section — **bar height** (36–72 px) and
**element scale** (0.7–2.0×) sliders. Element scale resizes
fonts, icons, module pills, tags, and tray (popups stay fixed); height is
a floor, not a cap — the bar grows to fit when scaled elements outgrow it.
Both persist to plain live-watched files — `bar-height` and `bar-scale` in
the suckless dir — so `echo 48 > ~/.config/suckless/bar-height` works
identically. Defaults (42 / 1.0) apply when the files are absent.

Weather config: right-click the module → rofi flow (`scripts/weather`) for
location (city/zip/airport; empty = auto by IP) and units (°F/°C/auto by
locale). State is two plain live-watched files — `weather-location` and
`weather-units` in the suckless dir — so `echo`/`rm` work identically for
scripts. Location auto-detect follows VPN exit nodes; the popup's 󰍎 line
shows which location the data is actually for.

Design grammar: indicators sit flat on the bar or icon-only — no
hover-expanding labels (a module growing on hover shifts the
right-anchored row out from under the cursor); details live in popups
and apps, and Volume's label flashes only on change. Pill backgrounds
mean "clickable". One popup per module — no hub:
three hub concepts (card, side panel, expanding deck) were built and
retired; every control lives in its module's obvious place. Anything
needing keyboard input (wifi passwords) is a floating window with its own
qs instance, not a popup. All popups share `Popout.qml` (card chrome +
click-outside/Escape close) — never hand-roll popup chrome. Battery joins
the flat metrics on laptops. VPN state (vpn/wireguard/tun) shows as a
green shield on the network module; the network app can toggle saved VPN
profiles (NM-managed vpn/wireguard only — externally managed tunnels
like tailscale show the shield and a read-only "external" row, but no
toggle: nmcli can down them but never bring them back), and carries the bluetooth manager (power, paired-device
connect/disconnect, PIN-less pairing via "pair new"; PIN pairing stays
blueman's job) — the section renders only when an adapter exists.

## Development notes

- New QML type → add to `qmldir` **and** fully restart (`scripts/bar
  restart`). Hot reload registers no new types and can leave stale handler
  trees running — never trust it for behavior changes.
- Debug: `scripts/bar log` · IPC surface: `scripts/bar ipc show`.
- The bar window is adopted unmanaged by the extbar patch: it does not
  appear in `_NET_CLIENT_LIST` (so the occupancy scan never sees it) and
  `scripts/bar place` no-ops, same as under bspwm.

## Fallback

Bar dies the moment you click it: check `~/.icons/default/index.theme`
for a self-referential Inherits loop — nwg-look ≤1.0.2 (what trixie
ships) generates one applying a cursor theme, and libxcb-cursor
recurses forever resolving the click cursor (found by ddubs, Aug 2026;
fixed upstream in nwg-look 1.0.3, issue #90). Delete the file or fix
the chain.

`Mod+Ctrl+b` toggles dwm's native bar back on; uncomment the slstatus line
in `scripts/autostart.sh` for status text (and don't run both bars — their
reservations stack). If quickshell misbehaves: `scripts/bar restart`.
