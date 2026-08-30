import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property real screenWidth: 1920
    property real screenHeight: 1080

    // Position & sizing properties
    property real posX: 780
    property real posY: 517
    property real scaleFactor: 0.85

    x: Math.max(10, Math.min(root.screenWidth - root.width - 10, posX))
    y: Math.max(10, Math.min(root.screenHeight - root.height - 10, posY))
    width: Math.round(360 * scaleFactor)
    height: Math.round(210 * scaleFactor)

    // ─── Settings Persistence ───
    Process {
        id: loadSettingsProc
        command: ["sh", "-c", "cat ~/.config/quickshell/widget_settings.json 2>/dev/null || echo '{}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    if (data.worldclock) {
                        if (data.worldclock.scale !== undefined) root.scaleFactor = Math.max(0.5, Math.min(2.5, data.worldclock.scale))
                        var w = Math.round(360 * root.scaleFactor)
                        var h = Math.round(210 * root.scaleFactor)
                        if (data.worldclock.x !== undefined) root.posX = Math.max(10, Math.min(root.screenWidth - w - 10, data.worldclock.x))
                        if (data.worldclock.y !== undefined) root.posY = Math.max(10, Math.min(root.screenHeight - h - 10, data.worldclock.y))
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
        var script = "python3 -c 'import json, os; p=os.path.expanduser(\"~/.config/quickshell/widget_settings.json\"); d=json.load(open(p)) if os.path.exists(p) else {}; d[\"worldclock\"]={\"x\":" + Math.round(root.x) + ",\"y\":" + Math.round(root.y) + ",\"scale\":" + root.scaleFactor.toFixed(2) + "}; open(p,\"w\").write(json.dumps(d,indent=2))'"
        saveSettingsProc.command = ["sh", "-c", script]
        saveSettingsProc.running = true
    }

    // ─── Time Zones Model ───
    property var timezones: [
        { city: "London", zone: "Europe/London" },
        { city: "New York", zone: "America/New_York" },
        { city: "Tokyo", zone: "Asia/Tokyo" },
        { city: "Sydney", zone: "Australia/Sydney" }
    ]

    property var clockData: []

    function updateClocks() {
        var list = []
        var now = new Date()

        for (var i = 0; i < root.timezones.length; i++) {
            var item = root.timezones[i]
            try {
                var options = { timeZone: item.zone, hour: '2-digit', minute: '2-digit', hour12: false }
                var timeStr = now.toLocaleTimeString([], options)

                var hourOptions = { timeZone: item.zone, hour: 'numeric', hour12: false }
                var hourNum = parseInt(now.toLocaleTimeString([], hourOptions))
                var isDay = (hourNum >= 6 && hourNum < 18)

                var dayOptions = { timeZone: item.zone, weekday: 'short' }
                var dayStr = now.toLocaleDateString([], dayOptions)

                list.push({
                    city: item.city,
                    time: timeStr,
                    day: dayStr,
                    isDay: isDay
                })
            } catch (e) {
                list.push({
                    city: item.city,
                    time: "12:00",
                    day: "Today",
                    isDay: true
                })
            }
        }
        root.clockData = list
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateClocks()
    }

    Component.onCompleted: {
        loadSettingsProc.running = true
        root.updateClocks()
    }

    // ─── Material Theme Palette ───
    readonly property color colBg: "#3A454B"              // Dark Slate Main Card
    readonly property color colBadgeBg: "#4D585F"         // Slate Pill Badge
    readonly property color colPillDay: "#C2E7FF"          // Day Pill Cyan Accent
    readonly property color colPillNight: "#1E2A30"        // Night Pill Dark Accent
    readonly property color colTextPrimary: "#FFFFFF"
    readonly property color colTextSecondary: "#B0BEC5"

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 360
        height: 210
        scale: root.scaleFactor
        transformOrigin: Item.TopLeft

        Rectangle {
            anchors.fill: parent
            color: root.colBg
            radius: 32
            antialiasing: true

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // Header Row
                Row {
                    width: parent.width

                    Rectangle {
                        height: 22
                        width: wcBadgeRow.implicitWidth + 16
                        radius: 11
                        color: root.colBadgeBg
                        antialiasing: true

                        Row {
                            id: wcBadgeRow
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 3.5
                                color: "#C2E7FF"
                                antialiasing: true
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "WORLD CLOCK"
                                color: root.colTextPrimary
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.6
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - titleText.width)
                        height: 1
                    }

                    Text {
                        id: titleText
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Global Times"
                        color: root.colTextSecondary
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                    }
                }

                // Grid of 4 Time Zones
                Grid {
                    width: parent.width
                    columns: 2
                    spacing: 10

                    Repeater {
                        model: root.clockData

                        Rectangle {
                            width: (parent.width - 10) / 2
                            height: 68
                            radius: 20
                            color: root.colBadgeBg
                            antialiasing: true

                            Item {
                                anchors.fill: parent
                                anchors.margins: 12

                                Column {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: modelData.city
                                        color: root.colTextPrimary
                                        font.pixelSize: 12
                                        font.bold: true
                                        font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                                    }

                                    Text {
                                        text: modelData.day
                                        color: root.colTextSecondary
                                        font.pixelSize: 10
                                        font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                                    }
                                }

                                Column {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    horizontalAlignment: Text.AlignRight
                                    spacing: 4

                                    Text {
                                        text: modelData.time
                                        color: root.colTextPrimary
                                        font.pixelSize: 16
                                        font.bold: true
                                        font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                                    }

                                    // Day / Night Status Pill
                                    Rectangle {
                                        anchors.right: parent.right
                                        height: 14
                                        width: 38
                                        radius: 7
                                        color: modelData.isDay ? root.colPillDay : root.colPillNight
                                        antialiasing: true

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.isDay ? "DAY" : "NIGHT"
                                            color: modelData.isDay ? "#1E2A30" : "#C2E7FF"
                                            font.pixelSize: 8
                                            font.bold: true
                                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                                        }
                                    }
                                }
                            }
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
