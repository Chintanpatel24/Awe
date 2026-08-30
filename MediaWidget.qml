import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property real screenWidth: 1920
    property real screenHeight: 1080

    // Position & sizing properties
    property real posX: 10
    property real posY: 450
    property real scaleFactor: 0.85

    x: Math.max(10, Math.min(root.screenWidth - root.width - 10, posX))
    y: Math.max(10, Math.min(root.screenHeight - root.height - 10, posY))
    width: Math.round(340 * scaleFactor)
    height: Math.round(380 * scaleFactor)

    // ─── Settings Persistence ───
    Process {
        id: loadSettingsProc
        command: ["sh", "-c", "cat ~/.config/quickshell/widget_settings.json 2>/dev/null || echo '{}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    if (data.media) {
                        if (data.media.scale !== undefined) root.scaleFactor = Math.max(0.5, Math.min(2.5, data.media.scale))
                        var w = Math.round(340 * root.scaleFactor)
                        var h = Math.round(380 * root.scaleFactor)
                        if (data.media.x !== undefined) root.posX = Math.max(10, Math.min(root.screenWidth - w - 10, data.media.x))
                        if (data.media.y !== undefined) root.posY = Math.max(10, Math.min(root.screenHeight - h - 10, data.media.y))
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: saveSettingsProc
        running: false
    }

    function saveSettings() {
        var script = "python3 -c 'import json, os; p=os.path.expanduser(\"~/.config/quickshell/widget_settings.json\"); d=json.load(open(p)) if os.path.exists(p) else {}; d[\"media\"]={\"x\":" + Math.round(root.x) + ",\"y\":" + Math.round(root.y) + ",\"scale\":" + root.scaleFactor.toFixed(2) + "}; open(p,\"w\").write(json.dumps(d,indent=2))'"
        saveSettingsProc.command = ["sh", "-c", script]
        saveSettingsProc.running = true
    }

    // ─── Built-in Demo Playlist & Lyrics ───
    property var demoTracks: [
        {
            title: "Pretty Patterns",
            artist: "ATLAS",
            duration: 225,
            lyrics: [
                "And if the stars aligned in the clear night sky",
                "Would you remind me of how the time flies?",
                "I just want to feel your touch but I'm alive",
                "If fading is a chance to bring a new dawn",
                "Erasing all the haste to grieve in my flaws",
                "As the light comes looking for the morning",
                "We are searchers looking for a place to stay"
            ]
        },
        {
            title: "Midnight Horizon",
            artist: "Pixel Waves",
            duration: 198,
            lyrics: [
                "Driving through the neon lights tonight",
                "City shadows fading in the rear view mirror",
                "Electric pulse echoing through the dark",
                "We chase the horizon until the sunrise",
                "Fading into memories of silver and blue",
                "Lost in the rhythm of the endless road"
            ]
        },
        {
            title: "Summer Breeze",
            artist: "California Drive",
            duration: 240,
            lyrics: [
                "Golden sunlight streaming through the trees",
                "Warm air whispering sweet melodies",
                "Ocean waves crash softly on the shore",
                "Moments like this could last forevermore",
                "Summer breeze carry all our worries away"
            ]
        },
        {
            title: "Neon Sunset",
            artist: "Studio M3",
            duration: 210,
            lyrics: [
                "Colors bleeding across the twilight sky",
                "Synthesizers hum a calm lullaby",
                "Reflections glowing on the pavement wet",
                "Lost inside this glowing neon sunset",
                "Until tomorrow brings another day"
            ]
        }
    ]
    property int currentDemoTrackIndex: 0

    // ─── Media State Properties ───
    property string title: "Pretty Patterns"
    property string artist: "ATLAS"
    property string artUrl: ""
    property string status: "Playing"
    property real positionSec: 72
    property real lengthSec: 225
    property string posStr: "1:12"
    property string lenStr: "3:45"
    property real progress: 0.32
    property bool hasActivePlayer: false
    property var currentLyrics: []
    property int activeLyricIndex: 2

    function fmtTime(seconds) {
        var m = Math.floor(seconds / 60)
        var s = Math.floor(seconds % 60)
        return m + ":" + (s < 10 ? "0" + s : s)
    }

    // Process for executing media commands
    Process {
        id: controlProc
        running: false
    }

    function sendMediaCmd(action) {
        if (hasActivePlayer) {
            if (action === "play-pause") controlProc.command = ["playerctl", "play-pause"]
            else if (action === "next") controlProc.command = ["playerctl", "next"]
            else if (action === "previous") controlProc.command = ["playerctl", "previous"]
            else if (action === "rewind") controlProc.command = ["playerctl", "position", "10-"]
            else if (action === "forward") controlProc.command = ["playerctl", "position", "10+"]
            controlProc.running = true
        } else {
            // Built-in Player Simulation when no system MPRIS player is running
            if (action === "play-pause") {
                root.status = (root.status === "Playing") ? "Paused" : "Playing"
            } else if (action === "next") {
                root.currentDemoTrackIndex = (root.currentDemoTrackIndex + 1) % root.demoTracks.length
                root.loadDemoTrack(root.currentDemoTrackIndex)
            } else if (action === "previous") {
                root.currentDemoTrackIndex = (root.currentDemoTrackIndex - 1 + root.demoTracks.length) % root.demoTracks.length
                root.loadDemoTrack(root.currentDemoTrackIndex)
            } else if (action === "rewind") {
                root.positionSec = Math.max(0, root.positionSec - 10)
            } else if (action === "forward") {
                root.positionSec = Math.min(root.lengthSec, root.positionSec + 10)
            }
            root.updateTimes()
        }
    }

    function loadDemoTrack(idx) {
        var trk = root.demoTracks[idx]
        root.title = trk.title
        root.artist = trk.artist
        root.lengthSec = trk.duration
        root.positionSec = 0
        root.currentLyrics = trk.lyrics
        root.updateTimes()
    }

    function updateTimes() {
        root.posStr = root.fmtTime(root.positionSec)
        root.lenStr = root.lengthSec > 0 ? root.fmtTime(root.lengthSec) : "0:00"
        root.progress = root.lengthSec > 0 ? Math.min(1.0, root.positionSec / root.lengthSec) : 0

        if (root.currentLyrics && root.currentLyrics.length > 0) {
            var step = root.lengthSec / root.currentLyrics.length
            var calculatedIdx = Math.floor(root.positionSec / (step > 0 ? step : 1))
            root.activeLyricIndex = Math.max(0, Math.min(root.currentLyrics.length - 1, calculatedIdx))
        }
    }

    // ─── MPRIS Process Query ───
    Process {
        id: mediaProc
        command: ["playerctl", "metadata", "--format", "{{title}};;{{artist}};;{{mpris:artUrl}};;{{position}};;{{mpris:length}};;{{status}}"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var line = text.trim()
                if (line.length > 0 && line.includes(";;") && !line.includes("No players found")) {
                    var parts = line.split(";;")
                    root.hasActivePlayer = true
                    var newTitle = parts[0] || "Unknown Title"
                    if (newTitle !== root.title) {
                        root.title = newTitle
                        root.artist = parts[1] || "Unknown Artist"
                        root.artUrl = parts[2] || ""
                        // Default fallback lyrics for external MPRIS tracks
                        root.currentLyrics = [
                            "Playing via system MPRIS player...",
                            "Enjoying " + root.title + " by " + root.artist,
                            "Listening live on desktop widget"
                        ]
                    }

                    var posMicro = parseFloat(parts[3]) || 0
                    var lenMicro = parseFloat(parts[4]) || 0
                    root.positionSec = posMicro / 1000000.0
                    root.lengthSec = lenMicro / 1000000.0
                    root.status = parts[5] || "Playing"

                    root.updateTimes()
                } else {
                    if (root.hasActivePlayer) {
                        root.hasActivePlayer = false
                        root.loadDemoTrack(root.currentDemoTrackIndex)
                    }
                }
            }
        }
    }

    // Playback Progress Timer
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            mediaProc.running = true
            if (!root.hasActivePlayer && root.status === "Playing") {
                root.positionSec = (root.positionSec + 1) % (root.lengthSec + 1)
                root.updateTimes()
            }
        }
    }

    Component.onCompleted: {
        loadSettingsProc.running = true
        root.loadDemoTrack(0)
        mediaProc.running = true
    }

    // ─── Material You / M3 Dark Slate Palette ───
    readonly property color colBg: "#293237"              // Deep M3 Slate Dark Card
    readonly property color colHeaderBg: "#1F262A"          // Slightly darker top header card
    readonly property color colPillBg: "#3A464C"          // Control Pill Fill
    readonly property color colAccent: "#C2E7FF"          // M3 Light Cyan Active Accent
    readonly property color colAccentDark: "#1E2A30"      // Dark Fill for Scalloped Button Icon
    readonly property color colTextPrimary: "#E1E2E5"
    readonly property color colTextSecondary: "#9AA8AD"
    readonly property color colTextFaded: "#5A676D"

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 340
        height: 380
        scale: root.scaleFactor
        transformOrigin: Item.TopLeft

        Rectangle {
            anchors.fill: parent
            color: root.colBg
            radius: 36
            antialiasing: true

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                // ─── Header Section (Album Art + Song Title/Artist + Quick M3 Controls) ───
                Rectangle {
                    width: parent.width
                    height: 100
                    radius: 28
                    color: root.colHeaderBg
                    antialiasing: true

                    Row {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 12

                        // Album Art Cover
                        Rectangle {
                            width: 80
                            height: 80
                            radius: 20
                            color: root.colPillBg
                            clip: true
                            antialiasing: true

                            Image {
                                anchors.fill: parent
                                source: root.artUrl
                                fillMode: Image.PreserveAspectCrop
                                visible: root.artUrl.length > 0 && status === Image.Ready
                                asynchronous: true
                            }

                            // Fallback Material Vector Art
                            Item {
                                anchors.fill: parent
                                visible: !root.artUrl || root.artUrl.length === 0

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#374349"
                                }

                                Canvas {
                                    anchors.fill: parent
                                    antialiasing: true
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.reset()
                                        ctx.fillStyle = "#A2C9C2"
                                        ctx.beginPath()
                                        ctx.arc(40, 40, 26, 0, Math.PI * 2)
                                        ctx.fill()
                                        ctx.fillStyle = root.colHeaderBg
                                        ctx.beginPath()
                                        ctx.arc(40, 40, 9, 0, Math.PI * 2)
                                        ctx.fill()
                                    }
                                }
                            }
                        }

                        // Track Meta & M3 Action Controls Row
                        Column {
                            width: parent.width - 80 - 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            // Track Title & Artist
                            Column {
                                width: parent.width
                                spacing: 2

                                Text {
                                    text: root.title
                                    color: root.colTextPrimary
                                    font.pixelSize: 15
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: parent.width
                                    font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                                }

                                Text {
                                    text: root.artist
                                    color: root.colTextSecondary
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    width: parent.width
                                    font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                                }
                            }

                            // Quick Header Action Controls (Cast, Scalloped Play/Pause, Next)
                            Row {
                                width: parent.width
                                spacing: 10

                                Item {
                                    width: Math.max(0, parent.width - 100)
                                    height: 1
                                }

                                // Cast / Device Pill Button
                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: root.colPillBg
                                    anchors.verticalCenter: parent.verticalCenter
                                    antialiasing: true

                                    Canvas {
                                        anchors.fill: parent
                                        antialiasing: true
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            ctx.strokeStyle = root.colTextSecondary
                                            ctx.lineWidth = 1.6
                                            ctx.strokeRect(8, 8, 12, 9)
                                            ctx.fillStyle = root.colTextSecondary
                                            ctx.fillRect(12, 17, 4, 3)
                                        }
                                    }
                                }

                                // Scalloped Play/Pause Button (Matching player.png)
                                Item {
                                    width: 34
                                    height: 34
                                    anchors.verticalCenter: parent.verticalCenter

                                    Canvas {
                                        id: headerScallopCanvas
                                        anchors.fill: parent
                                        antialiasing: true

                                        Connections {
                                            target: root
                                            function onStatusChanged() { headerScallopCanvas.requestPaint() }
                                        }

                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            var cx = width / 2
                                            var cy = height / 2
                                            var rOuter = 16
                                            var rInner = 13.5
                                            var points = 12

                                            ctx.beginPath()
                                            for (var i = 0; i < points * 2; i++) {
                                                var angle = (i * Math.PI) / points
                                                var r = (i % 2 === 0) ? rOuter : rInner
                                                var x = cx + r * Math.cos(angle)
                                                var y = cy + r * Math.sin(angle)
                                                if (i === 0) ctx.moveTo(x, y)
                                                else ctx.lineTo(x, y)
                                            }
                                            ctx.closePath()
                                            ctx.fillStyle = root.colAccent
                                            ctx.fill()

                                            ctx.fillStyle = root.colAccentDark
                                            if (root.status === "Playing") {
                                                ctx.fillRect(cx - 4.5, cy - 5.5, 3.5, 11)
                                                ctx.fillRect(cx + 1, cy - 5.5, 3.5, 11)
                                            } else {
                                                ctx.beginPath()
                                                ctx.moveTo(cx - 3, cy - 6)
                                                ctx.lineTo(cx + 5, cy)
                                                ctx.lineTo(cx - 3, cy + 6)
                                                ctx.closePath()
                                                ctx.fill()
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.sendMediaCmd("play-pause")
                                    }
                                }

                                // Next Button
                                Item {
                                    width: 28
                                    height: 28
                                    anchors.verticalCenter: parent.verticalCenter

                                    Canvas {
                                        anchors.fill: parent
                                        antialiasing: true
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            ctx.fillStyle = root.colTextPrimary
                                            ctx.beginPath()
                                            ctx.moveTo(8, 8)
                                            ctx.lineTo(16, 14)
                                            ctx.lineTo(8, 20)
                                            ctx.closePath()
                                            ctx.fill()
                                            ctx.fillRect(18, 8, 2, 12)
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.sendMediaCmd("next")
                                    }
                                }
                            }
                        }
                    }
                }

                // ─── Lyrics Section (Exact visual match to player.png) ───
                Item {
                    width: parent.width
                    height: 200
                    clip: true

                    Column {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: 12

                        Repeater {
                            model: root.currentLyrics

                            Text {
                                text: modelData
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                font.pixelSize: index === root.activeLyricIndex ? 15 : (Math.abs(index - root.activeLyricIndex) === 1 ? 13 : 11)
                                font.bold: index === root.activeLyricIndex
                                color: index === root.activeLyricIndex ? "#FFFFFF" : (Math.abs(index - root.activeLyricIndex) === 1 ? root.colTextSecondary : root.colTextFaded)
                                opacity: index === root.activeLyricIndex ? 1.0 : (Math.abs(index - root.activeLyricIndex) === 1 ? 0.6 : 0.25)
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"

                                Behavior on opacity { NumberAnimation { duration: 250 } }
                                Behavior on font.pixelSize { NumberAnimation { duration: 200 } }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.activeLyricIndex = index
                                        if (root.currentLyrics.length > 0) {
                                            root.positionSec = Math.round((index / root.currentLyrics.length) * root.lengthSec)
                                            root.updateTimes()
                                            if (root.hasActivePlayer) {
                                                controlProc.command = ["playerctl", "position", root.positionSec]
                                                controlProc.running = true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ─── Bottom Progress Bar & Seek Handle ───
                Column {
                    width: parent.width
                    spacing: 4

                    Item {
                        id: progressTrack
                        width: parent.width
                        height: 12

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
                            color: root.colPillBg
                            antialiasing: true
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(4, parent.width * root.progress)
                            height: 4
                            radius: 2
                            color: root.colAccent
                            antialiasing: true
                        }

                        Rectangle {
                            width: 6
                            height: 12
                            radius: 3
                            color: root.colAccent
                            x: Math.min(parent.width - width, Math.max(0, parent.width * root.progress - width / 2))
                            anchors.verticalCenter: parent.verticalCenter
                            antialiasing: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: (mouse) => {
                                var ratio = Math.max(0, Math.min(1.0, mouse.x / width))
                                root.progress = ratio
                                root.positionSec = Math.round(ratio * root.lengthSec)
                                root.updateTimes()
                                if (root.hasActivePlayer) {
                                    controlProc.command = ["playerctl", "position", root.positionSec]
                                    controlProc.running = true
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width

                        Text {
                            text: root.posStr
                            color: root.colTextSecondary
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                        }

                        Item {
                            width: Math.max(0, parent.width - parent.children[0].width - parent.children[2].width)
                            height: 1
                        }

                        Text {
                            text: root.lenStr
                            color: root.colTextSecondary
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                        }
                    }
                }
            }
        }
    }

    // ─── Drag & Resize MouseArea ───
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        drag.target: root
        drag.axis: Drag.XAndYAxis
        drag.minimumX: 10
        drag.maximumX: Math.max(10, root.screenWidth - root.width - 10)
        drag.minimumY: 10
        drag.maximumY: Math.max(10, root.screenHeight - root.height - 10)
        cursorShape: drag.active ? Qt.ClosedHandCursor : (containsMouse ? Qt.OpenHandCursor : Qt.ArrowCursor)

        onReleased: {
            root.posX = root.x
            root.posY = root.y
            root.saveSettings()
        }

        onWheel: (wheel) => {
            var delta = wheel.angleDelta.y / 1200.0
            var newScale = Math.max(0.5, Math.min(2.5, root.scaleFactor + delta))
            root.scaleFactor = Math.round(newScale * 100) / 100
            root.saveSettings()
        }
    }
}
