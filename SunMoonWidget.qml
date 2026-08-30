import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property real screenWidth: 1920
    property real screenHeight: 1080

    // Position & sizing properties
    property real posX: 780
    property real posY: 280
    property real scaleFactor: 0.85

    x: Math.max(10, Math.min(root.screenWidth - root.width - 10, posX))
    y: Math.max(10, Math.min(root.screenHeight - root.height - 10, posY))
    width: Math.round(360 * scaleFactor)
    height: Math.round(220 * scaleFactor)

    // ─── Settings Persistence ───
    Process {
        id: loadSettingsProc
        command: ["sh", "-c", "cat ~/.config/quickshell/widget_settings.json 2>/dev/null || echo '{}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    if (data.sunmoon) {
                        if (data.sunmoon.scale !== undefined) root.scaleFactor = Math.max(0.5, Math.min(2.5, data.sunmoon.scale))
                        var w = Math.round(360 * root.scaleFactor)
                        var h = Math.round(220 * root.scaleFactor)
                        if (data.sunmoon.x !== undefined) root.posX = Math.max(10, Math.min(root.screenWidth - w - 10, data.sunmoon.x))
                        if (data.sunmoon.y !== undefined) root.posY = Math.max(10, Math.min(root.screenHeight - h - 10, data.sunmoon.y))
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
        var script = "python3 -c 'import json, os; p=os.path.expanduser(\"~/.config/quickshell/widget_settings.json\"); d=json.load(open(p)) if os.path.exists(p) else {}; d[\"sunmoon\"]={\"x\":" + Math.round(root.x) + ",\"y\":" + Math.round(root.y) + ",\"scale\":" + root.scaleFactor.toFixed(2) + "}; open(p,\"w\").write(json.dumps(d,indent=2))'"
        saveSettingsProc.command = ["sh", "-c", script]
        saveSettingsProc.running = true
    }

    // ─── Sun & Moon Calculations ───
    property string sunriseStr: "06:15 AM"
    property string sunsetStr: "07:45 PM"
    property string daylightRemaining: "08h 30m left"
    property real sunProgress: 0.5
    property bool isDaytime: true
    property string moonPhaseName: "Waxing Crescent"

    function updateSunMoonData() {
        var now = new Date()
        var currentMin = now.getHours() * 60 + now.getMinutes()

        var sunriseMin = 6 * 60 + 15  // 06:15 AM
        var sunsetMin = 19 * 60 + 45  // 07:45 PM

        if (currentMin >= sunriseMin && currentMin <= sunsetMin) {
            root.isDaytime = true
            var totalDayMin = sunsetMin - sunriseMin
            var elapsedDayMin = currentMin - sunriseMin
            root.sunProgress = Math.min(1.0, Math.max(0.0, elapsedDayMin / totalDayMin))

            var remMin = sunsetMin - currentMin
            var remH = Math.floor(remMin / 60)
            var remM = remMin % 60
            root.daylightRemaining = remH + "h " + (remM < 10 ? "0" + remM : remM) + "m left"
        } else {
            root.isDaytime = false
            root.sunProgress = 0.0
            root.daylightRemaining = "Nighttime"
        }

        // Moon phase estimation
        var year = now.getFullYear()
        var month = now.getMonth() + 1
        var day = now.getDate()
        if (month < 3) { year--; month += 12; }
        var a = Math.floor(year / 100)
        var b = Math.floor(a / 4)
        var c = 2 - a + b
        var e = Math.floor(365.25 * (year + 4716))
        var f = Math.floor(30.6001 * (month + 1))
        var jd = c + day + e + f - 1524.5
        var daysSinceNew = (jd - 2451549.5) % 29.53058867
        if (daysSinceNew < 0) daysSinceNew += 29.53058867

        if (daysSinceNew < 1.84566) root.moonPhaseName = "New Moon"
        else if (daysSinceNew < 5.53699) root.moonPhaseName = "Waxing Crescent"
        else if (daysSinceNew < 9.22831) root.moonPhaseName = "First Quarter"
        else if (daysSinceNew < 12.91963) root.moonPhaseName = "Waxing Gibbous"
        else if (daysSinceNew < 16.61096) root.moonPhaseName = "Full Moon"
        else if (daysSinceNew < 20.30228) root.moonPhaseName = "Waning Gibbous"
        else if (daysSinceNew < 23.99361) root.moonPhaseName = "Third Quarter"
        else if (daysSinceNew < 27.68493) root.moonPhaseName = "Waning Crescent"
        else root.moonPhaseName = "New Moon"
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateSunMoonData()
    }

    Component.onCompleted: {
        loadSettingsProc.running = true
        root.updateSunMoonData()
    }

    // ─── Material Theme Palette ───
    readonly property color colBg: "#3A454B"              // Dark Slate Main Card
    readonly property color colBadgeBg: "#4D585F"         // Slate Pill Badge
    readonly property color colSunAccent: "#FFD56B"       // Warm Solar Gold Accent
    readonly property color colMoonAccent: "#C2E7FF"      // Lunar Soft Cyan Accent
    readonly property color colTextPrimary: "#FFFFFF"
    readonly property color colTextSecondary: "#B0BEC5"

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 360
        height: 220
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
                spacing: 10

                // Header Row
                Row {
                    width: parent.width

                    Rectangle {
                        height: 22
                        width: smBadgeRow.implicitWidth + 16
                        radius: 11
                        color: root.colBadgeBg
                        antialiasing: true

                        Row {
                            id: smBadgeRow
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 3.5
                                color: root.isDaytime ? root.colSunAccent : root.colMoonAccent
                                antialiasing: true
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "DAY CYCLE & MOON"
                                color: root.colTextPrimary
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.6
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - moonText.width)
                        height: 1
                    }

                    Text {
                        id: moonText
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.moonPhaseName
                        color: root.colTextSecondary
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                    }
                }

                // Solar Arc Canvas Track
                Item {
                    width: parent.width
                    height: 110

                    Canvas {
                        id: solarArcCanvas
                        anchors.fill: parent
                        antialiasing: true

                        Connections {
                            target: root
                            function onSunProgressChanged() { solarArcCanvas.requestPaint() }
                            function onIsDaytimeChanged() { solarArcCanvas.requestPaint() }
                        }

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()

                            var cx = width / 2
                            var cy = height - 10
                            var rx = width / 2 - 24
                            var ry = height - 25

                            // Background Dashed Arc
                            ctx.strokeStyle = root.colBadgeBg
                            ctx.lineWidth = 3
                            ctx.setLineDash([5, 5])
                            ctx.beginPath()
                            ctx.ellipse(cx - rx, cy - ry, rx * 2, ry * 2)
                            ctx.stroke()
                            ctx.setLineDash([])

                            // Active Sun Progress Arc
                            if (root.isDaytime) {
                                var angle = Math.PI + root.sunProgress * Math.PI
                                var sunX = cx + rx * Math.cos(angle)
                                var sunY = cy + ry * Math.sin(angle)

                                ctx.strokeStyle = root.colSunAccent
                                ctx.lineWidth = 4
                                ctx.beginPath()
                                ctx.arc(cx, cy, rx, Math.PI, angle, false)
                                ctx.stroke()

                                // Sun Glowing Sphere Vector
                                ctx.fillStyle = root.colSunAccent
                                ctx.beginPath()
                                ctx.arc(sunX, sunY, 8, 0, Math.PI * 2)
                                ctx.fill()

                                ctx.fillStyle = "#1E2A30"
                                ctx.beginPath()
                                ctx.arc(sunX, sunY, 4, 0, Math.PI * 2)
                                ctx.fill()
                            }
                        }
                    }

                    // Solar Info Overlays
                    Column {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 12
                        horizontalAlignment: Text.AlignHCenter
                        spacing: 2

                        Text {
                            text: root.isDaytime ? root.daylightRemaining : root.moonPhaseName
                            color: root.colTextPrimary
                            font.pixelSize: 16
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        }

                        Text {
                            text: root.isDaytime ? "Daylight remaining" : "Nighttime cycle"
                            color: root.colTextSecondary
                            font.pixelSize: 10
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        }
                    }
                }

                // Bottom Sunrise / Sunset Bar
                Row {
                    width: parent.width

                    Column {
                        spacing: 1

                        Text {
                            text: "SUNRISE"
                            color: root.colTextSecondary
                            font.pixelSize: 9
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        }

                        Text {
                            text: root.sunriseStr
                            color: root.colTextPrimary
                            font.pixelSize: 11
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - parent.children[2].width)
                        height: 1
                    }

                    Column {
                        horizontalAlignment: Text.AlignRight
                        spacing: 1

                        Text {
                            text: "SUNSET"
                            color: root.colTextSecondary
                            font.pixelSize: 9
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        }

                        Text {
                            text: root.sunsetStr
                            color: root.colTextPrimary
                            font.pixelSize: 11
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
