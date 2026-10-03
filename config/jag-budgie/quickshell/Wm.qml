pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tag state + control — dwm backend. Requires the quickshell-extbar patch
// (suckless/dwm/patches/dwm-quickshell-extbar.diff): it publishes
// _DWM_SELTAGS (raw tagset bitmask, faithful for multi-tag views) plus
// the layout/tweak atoms below, and accepts _NET_CURRENT_DESKTOP /
// _NET_WM_DESKTOP client messages so xdotool works for actions.
// Occupancy is recomputed from each client's _NET_CLIENT_INFO tag
// bitmask (debounced). The focused window title comes from the same
// two-stage xprop spy as the other backends.
Singleton {
    id: root

    property int seltags: 1
    property int occtags: 0
    property int urgtags: 0     // dwm exports no urgency atom yet
    property int tagCount: 12
    property string title: ""
    property string activeWinId: ""

    // --- layout: _DWM_LAYOUT publishes the current layouts[] index;
    // writing one to _DWM_SETLAYOUT applies it (a root property, so
    // plain xprop drives it and keybind-less layouts are reachable).
    // Order, glyphs, and the mfact/nmaster does-this-layout-use-them
    // flags mirror layouts[] in suckless/dwm/config.h — keep in sync. ---
    readonly property var layouts: [
        { name: "dwindle",        glyph: "󰕴", mfact: true,  nmaster: false },
        { name: "tile",           glyph: "󰙀", mfact: true,  nmaster: true  },
        { name: "columns",        glyph: "󰕭", mfact: false, nmaster: false },
        { name: "centered",       glyph: "󰕬", mfact: true,  nmaster: true  },
        { name: "floating",       glyph: "󰕰", mfact: false, nmaster: false },
        { name: "bstack",         glyph: "󱒈", mfact: true,  nmaster: true  },
        { name: "n-row grid",     glyph: "󰕯", mfact: false, nmaster: true  },
        { name: "deck",           glyph: "󱇙", mfact: true,  nmaster: true  },
        { name: "gapless grid",   glyph: "󰕫", mfact: false, nmaster: false },
        { name: "spiral",         glyph: "󰪷", mfact: true,  nmaster: false },
        { name: "monocle",        glyph: "󰕮", mfact: false, nmaster: false },
        { name: "grid",           glyph: "󰝘", mfact: false, nmaster: false },
        { name: "bstack horiz",   glyph: "󱒉", mfact: true,  nmaster: true  },
        { name: "centered float", glyph: "󰕱", mfact: true,  nmaster: true  },
        { name: "horiz grid",     glyph: "󱇚", mfact: false, nmaster: false }
    ]
    property int layoutIndex: 0

    // desktop tweaks, same publish/set mechanism (_DWM_GAPS/_DWM_MFACT/
    // _DWM_NMASTER read, _DWM_SET* written). mfact is a percent; mfact
    // and nmaster are pertag — they follow the focused tag.
    property int gaps: 8
    property int mfact: 50
    property int nmaster: 1
    property bool follow: true  // window-follow on tag/monitor send (wfsymbol)

    property bool _followSeen: false
    function _setFollow(f) {
        // notify on real changes only — click and Mod+n both land here
        if (_followSeen && f !== follow)
            Quickshell.execDetached(["notify-send", "-a", "dwm", "-t", "1500",
                "Window follow", f ? "Sent windows are followed" : "Sent windows stay put"])
        _followSeen = true
        follow = f
    }

    function _setProp(atom, v) {
        Quickshell.execDetached(["xprop", "-root", "-f", atom, "32c",
            "-set", atom, String(v)])
    }
    function setLayout(i) { _setProp("_DWM_SETLAYOUT", i) }
    function cycleLayout(dir) {
        setLayout(((layoutIndex + dir) % layouts.length + layouts.length) % layouts.length)
    }
    function setGaps(v) { _setProp("_DWM_SETGAPS", v) }
    function setMfact(pct) { _setProp("_DWM_SETMFACT", pct) }
    function setNmaster(n) { _setProp("_DWM_SETNMASTER", n) }
    function toggleFollow() { _setProp("_DWM_SETFOLLOW", follow ? 0 : 1) }

    // xprop -spy silently drops atoms that don't exist when it starts
    // ("no such atom", then never reports them) — and on login the bar
    // can beat dwm's atom seeding. Restart the spy until every atom
    // resolves; bounded, since an unpatched dwm never publishes them.
    property int _spyRetries: 0
    Timer {
        id: spyRetry
        interval: 2000
        onTriggered: { spy.running = false; spy.running = true }
    }
    Process {
        id: spy
        command: ["xprop", "-spy", "-root",
                  "_DWM_SELTAGS", "_NET_NUMBER_OF_DESKTOPS", "_NET_CLIENT_LIST",
                  "_DWM_LAYOUT", "_DWM_GAPS", "_DWM_MFACT", "_DWM_NMASTER",
                  "_DWM_FOLLOW"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("no such atom") >= 0) {
                    if (root._spyRetries++ < 15)
                        spyRetry.restart()
                    return
                }
                // tweak atoms never affect occupancy — parse and bail
                const tweaks = {"_DWM_LAYOUT":  v => root.layoutIndex = v,
                                "_DWM_GAPS":    v => root.gaps = v,
                                "_DWM_MFACT":   v => root.mfact = v,
                                "_DWM_NMASTER": v => root.nmaster = v,
                                "_DWM_FOLLOW":  v => root._setFollow(v > 0)}
                const eq = line.indexOf("(")
                const key = eq > 0 ? line.slice(0, eq) : ""
                if (tweaks[key]) {
                    const m = line.match(/= (\d+)/)
                    if (m)
                        tweaks[key](parseInt(m[1]))
                    return
                }
                if (line.indexOf("_DWM_SELTAGS") === 0) {
                    const m = line.match(/= (\d+)/)
                    if (m)
                        root.seltags = parseInt(m[1])
                } else if (line.indexOf("_NET_NUMBER_OF_DESKTOPS") === 0) {
                    const m = line.match(/= (\d+)/)
                    if (m)
                        root.tagCount = parseInt(m[1])
                }
                // any of these events can change occupancy (open/close/move)
                occRefresh.restart()
            }
        }
    }

    Timer {
        id: occRefresh
        interval: 150
        onTriggered: {
            occProc.running = false
            occProc.running = true
        }
    }

    property int _occ: 0
    Process {
        id: occProc
        command: ["sh", "-c",
            "for w in $(xprop -root _NET_CLIENT_LIST 2>/dev/null | grep -oE '0x[0-9a-f]+'); do " +
            "xprop -id $w _NET_CLIENT_INFO 2>/dev/null | sed -n 's/.*= \\([0-9]*\\).*/\\1/p'; done"]
        stdout: SplitParser {
            onRead: line => {
                const t = parseInt(line)
                if (!isNaN(t))
                    root._occ |= t
            }
        }
        onRunningChanged: {
            if (running) root._occ = 0
            // mask off scratchpad/hidden tag bits above the visible tags
            else root.occtags = root._occ & ((1 << root.tagCount) - 1)
        }
    }

    // --- focused window title ---

    Process {
        command: ["xprop", "-spy", "-root", "_NET_ACTIVE_WINDOW"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/window id # (0x[0-9a-fA-F]+)/)
                const id = m ? m[1] : ""
                if (id !== root.activeWinId) {
                    root.activeWinId = id
                    titleSpy.running = false
                    if (id !== "")
                        titleSpy.running = true
                    else
                        root.title = ""
                }
            }
        }
    }

    Process {
        id: titleSpy
        command: ["xprop", "-spy", "-id", root.activeWinId, "_NET_WM_NAME"]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/= "([\s\S]*)"$/)
                if (m)
                    root.title = m[1].replace(/\\"/g, '"').replace(/\\\\/g, "\\")
            }
        }
    }

    // --- actions (handled by the extbar patch's clientmessage additions) ---

    function viewTag(i) { Quickshell.execDetached(["xdotool", "set_desktop", String(i)]) }
    function toggleViewTag(i) { viewTag(i) }
    function sendToTag(i) {
        Quickshell.execDetached(["xdotool", "getactivewindow", "set_desktop_for_window", String(i)])
    }
    function cycleTag(dir) {
        Quickshell.execDetached(["xdotool", "set_desktop", "--relative", "--", String(dir)])
    }

    function openLauncher() {
        Quickshell.execDetached(["rofi", "-show", "drun", "-modi", "drun",
            "-line-padding", "4", "-hide-scrollbar", "-show-icons",
            "-theme", Theme.configDir + "/rofi/config.rasi"])
    }
    function openPowerMenu() {
        Quickshell.execDetached([Theme.configDir + "/scripts/power"])
    }
}
