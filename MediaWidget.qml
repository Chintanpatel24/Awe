import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property real screenWidth: 1920
    property real screenHeight: 1080
    property real posX: 80
    property real posY: 200
    property real scaleFactor: 1.0

    // Layout size (design size 360×420)
    readonly property int designW: 360
    readonly property int designH: 420

    width: Math.round(designW * scaleFactor)
    height: Math.round(designH * scaleFactor)
    x: Math.max(10, Math.min(screenWidth - width - 10, posX))
    y: Math.max(10, Math.min(screenHeight - height - 10, posY))

    // ── Media state ──
    property string title: "No media playing"
    property string artist: "Open a player (Spotify, browser…)"
    property string artUrl: ""
    property string status: "Stopped"   // Playing | Paused | Stopped
    property real positionSec: 0
    property real lengthSec: 0
    property bool hasPlayer: false

    property string posStr: "0:00"
    property string lenStr: "0:00"
    property real progress: 0

    // M3 palette (dark)
    readonly property color colBg: "#2B3236"
    readonly property color colPill: "#3F484C"
    readonly property color colAccent: "#C2E7FF"
    readonly property color colOnAccent: "#1E2A30"
    readonly property color colText: "#E3E2E6"
    readonly property color colMuted: "#A0A8AC"

    function fmtTime(sec) {
        sec = Math.max(0, Math.floor(sec))
        var m = Math.floor(sec / 60)
        var s = sec % 60
        return m + ":" + (s < 10 ? "0" + s : s)
    }

    function updateProgress() {
        posStr = fmtTime(positionSec)
        lenStr = lengthSec > 0 ? fmtTime(lengthSec) : "0:00"
        progress = lengthSec > 0 ? Math.min(1, positionSec / lengthSec) : 0
    }

    // ── Run a playerctl command (restart-safe) ──
    Process {
        id: cmdProc
        running: false
    }

    function runCmd(args) {
        cmdProc.running = false
        cmdProc.command = args
        cmdProc.running = true
    }

    function mediaAction(action) {
        if (!hasPlayer) return
        if (action === "play-pause") runCmd(["playerctl", "play-pause"])
        else if (action === "next") runCmd(["playerctl", "next"])
        else if (action === "previous") runCmd(["playerctl", "previous"])
        else if (action === "forward") runCmd(["playerctl", "position", "10+"])
        else if (action === "rewind") runCmd(["playerctl", "position", "10-"])
        // refresh soon after action
        refreshTimer.interval = 200
        refreshTimer.restart()
    }

    function seekRatio(ratio) {
        if (!hasPlayer || lengthSec <= 0) return
        var sec = Math.round(Math.max(0, Math.min(1, ratio)) * lengthSec)
        runCmd(["playerctl", "position", "" + sec])
        positionSec = sec
        updateProgress()
    }

    // ── Metadata poll ──
    Process {
        id: metaProc
        running: false
        command: [
            "sh", "-c",
            "playerctl metadata --format '{{status}}||{{title}}||{{artist}}||{{mpris:artUrl}}||{{position}}||{{mpris:length}}' 2>/dev/null || true"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var line = text.trim()
                if (!line.length || line.indexOf("No players") >= 0) {
                    root.hasPlayer = false
                    root.status = "Stopped"
                    return
                }
                var p = line.split("||")
                if (p.length < 4) {
                    root.hasPlayer = false
                    return
                }
                root.hasPlayer = true
                root.status = p[0] || "Paused"
                root.title = p[1] || "Unknown"
                root.artist = p[2] || ""
                root.artUrl = (p[3] || "").replace(/^file:\/\//, "file://")
                var posU = parseFloat(p[4] || "0") || 0
                var lenU = parseFloat(p[5] || "0") || 0
                // playerctl position/length are in microseconds
                root.positionSec = posU / 1000000.0
                root.lengthSec = lenU / 1000000.0
                root.updateProgress()
            }
        }
    }

    function refreshMeta() {
        metaProc.running = false
        metaProc.running = true
    }

    Timer {
        id: refreshTimer
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            refreshMeta()
            interval = 1000
        }
    }

    // ── Settings load/save ──
    Process {
        id: loadProc
        running: false
        command: ["sh", "-c", "cat ~/.config/quickshell/widget_settings.json 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    if (d.media) {
                        if (d.media.scale !== undefined)
                            root.scaleFactor = Math.max(0.5, Math.min(2.0, d.media.scale))
                        if (d.media.x !== undefined) root.posX = d.media.x
                        if (d.media.y !== undefined) root.posY = d.media.y
                    }
                } catch (e) {}
            }
        }
    }

    Process { id: saveProc; running: false }

    function saveSettings() {
        var script =
            "python3 -c \"import json,os;" +
            "p=os.path.expanduser('~/.config/quickshell/widget_settings.json');" +
            "d=json.load(open(p)) if os.path.exists(p) else {};" +
            "d['media']={'x':" + Math.round(root.x) +
            ",'y':" + Math.round(root.y) +
            ",'scale':" + root.scaleFactor.toFixed(2) + "};" +
            "os.makedirs(os.path.dirname(p),exist_ok=True);" +
            "open(p,'w').write(json.dumps(d,indent=2))\""
        saveProc.running = false
        saveProc.command = ["sh", "-c", script]
        saveProc.running = true
    }

    Component.onCompleted: loadProc.running = true

    // ── UI (scaled) ──
    Item {
        id: stage
        width: root.designW
        height: root.designH
        scale: root.scaleFactor
        transformOrigin: Item.TopLeft

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 28
            color: root.colBg
            antialiasing: true
            clip: true

            // DRAG LAYER — behind controls so buttons still receive clicks
            MouseArea {
                id: dragLayer
                anchors.fill: parent
                z: 0
                hoverEnabled: true
                drag.target: root
                drag.axis: Drag.XAndYAxis
                drag.minimumX: 10
                drag.maximumX: Math.max(10, root.screenWidth - root.width - 10)
                drag.minimumY: 10
                drag.maximumY: Math.max(10, root.screenHeight - root.height - 10)
                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                onReleased: {
                    if (drag.active) {
                        root.posX = root.x
                        root.posY = root.y
                        root.saveSettings()
                    }
                }
                onWheel: (w) => {
                    var ds = w.angleDelta.y / 1200.0
                    root.scaleFactor = Math.round(Math.max(0.5, Math.min(2.0, root.scaleFactor + ds)) * 100) / 100
                    root.saveSettings()
                }
            }

            Column {
                z: 1
                anchors.fill: parent
                anchors.margins: 20
                spacing: 18

                // ── Header: art + text + controls ──
                Row {
                    width: parent.width
                    height: 88
                    spacing: 14

                    // Album art
                    Rectangle {
                        width: 88
                        height: 88
                        radius: 20
                        color: root.colPill
                        clip: true
                        antialiasing: true

                        Image {
                            anchors.fill: parent
                            source: root.artUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready && root.artUrl.length > 0
                        }

                        // vinyl-style fallback
                        Rectangle {
                            anchors.fill: parent
                            visible: root.artUrl.length === 0 || true
                            z: -1
                            gradient: Gradient {
                                GradientStop { position: 0; color: "#3F484C" }
                                GradientStop { position: 1; color: "#1E2A30" }
                            }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 52; height: 52; radius: 26
                            color: "#A2C9C2"
                            visible: root.artUrl.length === 0
                            Rectangle {
                                anchors.centerIn: parent
                                width: 16; height: 16; radius: 8
                                color: root.colBg
                            }
                        }
                    }

                    // Title / artist
                    Column {
                        width: parent.width - 88 - 14 - ctrlPill.width - 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            width: parent.width
                            text: root.title
                            color: root.colText
                            font.pixelSize: 16
                            font.bold: true
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }
                        Text {
                            width: parent.width
                            text: root.artist
                            color: root.colMuted
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }

                    // Control pill
                    Rectangle {
                        id: ctrlPill
                        width: 132
                        height: 52
                        radius: 26
                        color: root.colPill
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            // Prev
                            Item {
                                width: 32; height: 32
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "⏮"
                                    color: root.colText
                                    font.pixelSize: 16
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.mediaAction("previous")
                                }
                            }

                            // Scalloped play/pause
                            Item {
                                width: 44; height: 44
                                anchors.verticalCenter: parent.verticalCenter

                                Canvas {
                                    id: playCanvas
                                    anchors.fill: parent
                                    antialiasing: true
                                    Connections {
                                        target: root
                                        function onStatusChanged() { playCanvas.requestPaint() }
                                    }
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.reset()
                                        var cx = width / 2, cy = height / 2
                                        var n = 12, ro = 21, ri = 17.5
                                        ctx.beginPath()
                                        for (var i = 0; i < n * 2; i++) {
                                            var a = (i * Math.PI) / n - Math.PI / 2
                                            var r = (i % 2 === 0) ? ro : ri
                                            var x = cx + r * Math.cos(a)
                                            var y = cy + r * Math.sin(a)
                                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                                        }
                                        ctx.closePath()
                                        ctx.fillStyle = root.colAccent
                                        ctx.fill()

                                        ctx.fillStyle = root.colOnAccent
                                        if (root.status === "Playing") {
                                            ctx.fillRect(cx - 6, cy - 8, 4, 16)
                                            ctx.fillRect(cx + 2, cy - 8, 4, 16)
                                        } else {
                                            ctx.beginPath()
                                            ctx.moveTo(cx - 5, cy - 9)
                                            ctx.lineTo(cx + 9, cy)
                                            ctx.lineTo(cx - 5, cy + 9)
                                            ctx.closePath()
                                            ctx.fill()
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.mediaAction("play-pause")
                                }
                            }

                            // Next
                            Item {
                                width: 32; height: 32
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "⏭"
                                    color: root.colText
                                    font.pixelSize: 16
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.mediaAction("next")
                                }
                            }
                        }
                    }
                }

                // ── Progress ──
                Column {
                    width: parent.width
                    spacing: 6

                    Item {
                        id: track
                        width: parent.width
                        height: 16

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 6
                            radius: 3
                            color: root.colPill
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(6, parent.width * root.progress)
                            height: 6
                            radius: 3
                            color: root.colAccent
                        }
                        Rectangle {
                            width: 8; height: 16; radius: 4
                            color: root.colAccent
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.min(parent.width - width,
                                        Math.max(0, parent.width * root.progress - width / 2))
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (m) => root.seekRatio(m.x / width)
                            onPositionChanged: (m) => {
                                if (pressed) root.seekRatio(m.x / width)
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        Text {
                            text: root.posStr
                            color: root.colMuted
                            font.pixelSize: 11
                            font.bold: true
                        }
                        Item { width: parent.width - 80; height: 1 }
                        Text {
                            text: root.lenStr
                            color: root.colMuted
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }

                // Extra: ±10s row
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 24

                    Rectangle {
                        width: 64; height: 32; radius: 16
                        color: root.colPill
                        Text {
                            anchors.centerIn: parent
                            text: "−10s"
                            color: root.colText
                            font.pixelSize: 12
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mediaAction("rewind")
                        }
                    }
                    Rectangle {
                        width: 64; height: 32; radius: 16
                        color: root.colPill
                        Text {
                            anchors.centerIn: parent
                            text: "+10s"
                            color: root.colText
                            font.pixelSize: 12
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mediaAction("forward")
                        }
                    }
                }

                // ── Lyrics-style block (visual match to your screenshot) ──
                Item {
                    width: parent.width
                    height: 160

                    Column {
                        anchors.centerIn: parent
                        width: parent.width * 0.92
                        spacing: 10

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: root.hasPlayer ? "Now playing" : "No active MPRIS player"
                            color: root.colMuted
                            opacity: 0.45
                            font.pixelSize: 12
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: root.artist.length ? root.artist : "—"
                            color: root.colMuted
                            opacity: 0.7
                            font.pixelSize: 14
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: root.title
                            color: root.colText
                            font.pixelSize: 17
                            font.bold: true
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: root.status === "Playing" ? "▶ Playing" : (root.status === "Paused" ? "⏸ Paused" : "■ Stopped")
                            color: root.colMuted
                            opacity: 0.55
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
