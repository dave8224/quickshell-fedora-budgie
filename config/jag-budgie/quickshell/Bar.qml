import QtQuick
import Quickshell

// The bar window, effectiveBarHeight px tall. The quickshell-extbar patch
// makes dwm honor this window's _NET_WM_STRUT_PARTIAL and re-tile live
// when it changes — no padding sync and no placement fixups needed.
PanelWindow {
    id: root

    property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.effectiveBarHeight
    color: "transparent"
    // map once, at final size — see Theme.barStateReady
    visible: Theme.barStateReady

    Rectangle {
        id: panel
        anchors.fill: parent
        anchors.topMargin: 8
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.bottomMargin: 2

        radius: 10
        color: Qt.alpha(Theme.bg, 0.94)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)

        Behavior on color { ColorAnimation { duration: 400 } }
        Behavior on border.color { ColorAnimation { duration: 400 } }

        // right-click empty bar = the layout/tweaks picker (same popup
        // as clicking the layout button); declared before the clusters
        // so module mouse areas stack above it
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: layoutBtn.pickerVisible = !layoutBtn.pickerVisible
        }


        Row {
            id: leftCluster
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Launcher {}
            // Tags {}
            // LayoutButton { id: layoutBtn }
            // Follow {}
        }

        // Title lives in the gap between the clusters: screen-centered when
        // it fits, nudged inward when it doesn't, elided to the gap width.
        // (A symmetric clamp goes negative on narrow screens — the right
        // cluster is wide — and a negative-width Text ignores elide.)
//         Title {
//             anchors.verticalCenter: parent.verticalCenter
//             readonly property real gapL: leftCluster.x + leftCluster.width + 24
//             readonly property real gapR: rightCluster.x - 24
//             width: Math.max(0, Math.min(implicitWidth, gapR - gapL))
//             x: Math.max(gapL, Math.min((parent.width - width) / 2, gapR - width))
//             visible: width > 40
//         }

        Clock {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            id: rightCluster
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Media {}
            Weather {}
            Metrics {}
            Volume {}
            Network {}
            Updates {}
            Tray {}
            Bell {}
            MicMute {}
            CapsLock {}
            Screenshot {}
            Commands {}
        }
    }
}
