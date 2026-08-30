import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property real screenWidth: 1920
    property real screenHeight: 1080
    property real posX: 400
    property real posY: 480
    property real scaleFactor: 0.9

    readonly property int designSize: 200
    width: Math.round(designSize * scaleFactor)
    height: Math.round(designSize * scaleFactor)
    x: Math.max(10, Math.min(screenWidth - width - 10, posX))
    y: Math.max(10, Math.min(screenHeight - height - 10, posY))

    property string imagePath: ""
    property string pendingPath: ""
    property int shapeIndex: 0
    property bool showConfirm: false

    readonly property color colBg: "#1E2A30"
    readonly property color colSurface: "#2B3236"
    readonly property color colPill: "#3F484C"
    readonly property color colAccent: "#C2E7FF"
    readonly property color colOnAccent: "#1E2A30"
    readonly property color colText: "#E3E2E6"
    readonly property color colMuted: "#A0A8AC"

    property var shapeNames: [
        "circle", "squircle", "stadium_h", "arch",
        "semicircle_top", "ellipse", "pebble", "pillow",
        "flower_4", "scallop_8", "clover_4", "badge_4",
        "pill_v", "heart"
    ]

    // ── Settings ──
    Process {
        id: loadProc
        running: false
        command: ["sh", "-c", "cat ~/.config/quickshell/widget_settings.json 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    if (d.poster) {
                        if (d.poster.scale !== undefined)
                            root.scaleFactor = Math.max(0.5, Math.min(2.5, d.poster.scale))
                        if (d.poster.x !== undefined) root.posX = d.poster.x
                        if (d.poster.y !== undefined) root.posY = d.poster.y
                        if (d.poster.imagePath !== undefined) root.imagePath = d.poster.imagePath
                        if (d.poster.shapeIndex !== undefined) root.shapeIndex = d.poster.shapeIndex
                    }
                } catch (e) {}
            }
        }
    }

    Process { id: saveProc; running: false }

    function saveSettings() {
        var safe = root.imagePath.replace(/\\/g, "\\\\").replace(/"/g, '\\"')
        var script =
            "python3 -c \"import json,os;" +
            "p=os.path.expanduser('~/.config/quickshell/widget_settings.json');" +
            "d=json.load(open(p)) if os.path.exists(p) else {};" +
            "d['poster']={'x':" + Math.round(root.x) +
            ",'y':" + Math.round(root.y) +
            ",'scale':" + root.scaleFactor.toFixed(2) +
            ",'imagePath':\\\"\" + safe + "\\\"" +
            ",'shapeIndex':" + root.shapeIndex + "};" +
            "os.makedirs(os.path.dirname(p),exist_ok=True);" +
            "open(p,'w').write(json.dumps(d,indent=2))\""
        saveProc.running = false
        saveProc.command = ["sh", "-c", script]
        saveProc.running = true
    }

    // File pickers (zenity first)
    Process {
        id: filePicker
        running: false
        command: ["sh", "-c",
            "zenity --file-selection --title='Select Image' " +
            "--file-filter='Images | *.png *.jpg *.jpeg *.webp *.bmp *.gif' 2>/dev/null || true"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = text.trim()
                if (s.length > 0) {
                    root.pendingPath = s
                    root.showConfirm = true
                }
            }
        }
    }

    Process {
        id: pathPrompt
        running: false
        command: ["sh", "-c",
            "zenity --entry --title='Image Path' --text='File path or URL:' 2>/dev/null || true"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = text.trim()
                if (s.length > 0) {
                    root.pendingPath = s
                    root.showConfirm = true
                }
            }
        }
    }

    function toImageUrl(p) {
        if (!p || p.length === 0) return ""
        if (p.indexOf("://") >= 0) return p
        if (p.charAt(0) === "/") return "file://" + p
        return p
    }

    function drawShapePath(ctx, shape, w, h) {
        var cx = w / 2, cy = h / 2, r = Math.min(w, h) / 2 - 2
        ctx.beginPath()

        if (shape === "circle") {
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
        } else if (shape === "squircle") {
            var rad = r * 0.45
            ctx.moveTo(cx - r + rad, cy - r)
            ctx.lineTo(cx + r - rad, cy - r)
            ctx.quadraticCurveTo(cx + r, cy - r, cx + r, cy - r + rad)
            ctx.lineTo(cx + r, cy + r - rad)
            ctx.quadraticCurveTo(cx + r, cy + r, cx + r - rad, cy + r)
            ctx.lineTo(cx - r + rad, cy + r)
            ctx.quadraticCurveTo(cx - r, cy + r, cx - r, cy + r - rad)
            ctx.lineTo(cx - r, cy - r + rad)
            ctx.quadraticCurveTo(cx - r, cy - r, cx - r + rad, cy - r)
        } else if (shape === "stadium_h") {
            var ry = r * 0.62
            ctx.moveTo(cx - r + ry, cy - ry)
            ctx.lineTo(cx + r - ry, cy - ry)
            ctx.arc(cx + r - ry, cy, ry, -Math.PI / 2, Math.PI / 2)
            ctx.lineTo(cx - r + ry, cy + ry)
            ctx.arc(cx - r + ry, cy, ry, Math.PI / 2, 3 * Math.PI / 2)
        } else if (shape === "arch") {
            ctx.moveTo(cx - r, cy + r)
            ctx.lineTo(cx + r, cy + r)
            ctx.lineTo(cx + r, cy)
            ctx.arc(cx, cy, r, 0, Math.PI, true)
            ctx.closePath()
            return
        } else if (shape === "semicircle_top") {
            ctx.moveTo(cx - r, cy + r * 0.35)
            ctx.arc(cx, cy + r * 0.35, r, Math.PI, 0, false)
            ctx.closePath()
            return
        } else if (shape === "ellipse") {
            ctx.save()
            ctx.translate(cx, cy)
            ctx.scale(1.0, 0.72)
            ctx.arc(0, 0, r, 0, Math.PI * 2)
            ctx.restore()
        } else if (shape === "pebble") {
            ctx.moveTo(cx - r * 0.8, cy - r * 0.5)
            ctx.bezierCurveTo(cx - r, cy - r, cx + r * 0.2, cy - r, cx + r * 0.9, cy - r * 0.4)
            ctx.bezierCurveTo(cx + r * 1.1, cy, cx + r * 0.8, cy + r * 0.9, cx, cy + r)
            ctx.bezierCurveTo(cx - r * 0.9, cy + r * 0.9, cx - r * 1.1, cy, cx - r * 0.8, cy - r * 0.5)
        } else if (shape === "pillow") {
            ctx.moveTo(cx, cy - r)
            ctx.quadraticCurveTo(cx + r * 0.8, cy - r * 0.8, cx + r, cy)
            ctx.quadraticCurveTo(cx + r * 0.8, cy + r * 0.8, cx, cy + r)
            ctx.quadraticCurveTo(cx - r * 0.8, cy + r * 0.8, cx - r, cy)
            ctx.quadraticCurveTo(cx - r * 0.8, cy - r * 0.8, cx, cy - r)
        } else if (shape === "scallop_8" || shape === "flower_4" || shape === "clover_4" || shape === "badge_4") {
            var teeth = shape === "scallop_8" ? 8 : 4
            var soft = shape === "badge_4"
            for (var a = 0; a <= 360; a += 2) {
                var radA = a * Math.PI / 180
                var wave = soft
                    ? 0.75 + 0.25 * Math.abs(Math.sin(2 * radA))
                    : (0.72 + 0.28 * (Math.cos(teeth * radA) + 1) / 2)
                var rr = r * wave
                var x = cx + rr * Math.sin(radA)
                var y = cy - rr * Math.cos(radA)
                if (a === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
        } else if (shape === "pill_v") {
            var px = r * 0.55
            ctx.moveTo(cx - px, cy - r + px)
            ctx.arc(cx, cy - r + px, px, Math.PI, 0, false)
            ctx.lineTo(cx + px, cy + r - px)
            ctx.arc(cx, cy + r - px, px, 0, Math.PI, false)
            ctx.closePath()
            return
        } else if (shape === "heart") {
            ctx.moveTo(cx, cy + r * 0.75)
            ctx.bezierCurveTo(cx - r * 1.1, cy + r * 0.2, cx - r * 1.1, cy - r * 0.7, cx, cy - r * 0.35)
            ctx.bezierCurveTo(cx + r * 1.1, cy - r * 0.7, cx + r * 1.1, cy + r * 0.2, cx, cy + r * 0.75)
        } else {
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
        }
        ctx.closePath()
    }

    Component.onCompleted: loadProc.running = true

    Item {
        id: stage
        width: root.designSize
        height: root.designSize
        scale: root.scaleFactor
        transformOrigin: Item.TopLeft

        Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true
            renderTarget: Canvas.FramebufferObject
            renderStrategy: Canvas.Cooperative

            property string loadedUrl: ""

            function reload() {
                var url = root.toImageUrl(root.imagePath)
                if (url.length === 0) {
                    loadedUrl = ""
                    requestPaint()
                    return
                }
                if (loadedUrl !== url) {
                    // unload previous if needed
                    loadedUrl = url
                    canvas.loadImage(url)
                } else {
                    requestPaint()
                }
            }

            Connections {
                target: root
                function onImagePathChanged() { canvas.reload() }
                function onShapeIndexChanged() { canvas.requestPaint() }
            }

            onImageLoaded: requestPaint()
            Component.onCompleted: reload()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.clearRect(0, 0, width, height)

                var shape = root.shapeNames[root.shapeIndex % root.shapeNames.length]
                root.drawShapePath(ctx, shape, width, height)
                ctx.clip()

                var url = root.toImageUrl(root.imagePath)
                if (url.length > 0 && canvas.isImageLoaded(url)) {
                    // cover-fit
                    ctx.drawImage(url, 0, 0, width, height)
                } else {
                    var g = ctx.createLinearGradient(0, 0, width, height)
                    g.addColorStop(0, "#3F484C")
                    g.addColorStop(1, "#1E2A30")
                    ctx.fillStyle = g
                    ctx.fill()

                    ctx.fillStyle = root.colAccent
                    ctx.font = "bold 12px sans-serif"
                    ctx.textAlign = "center"
                    ctx.textBaseline = "middle"
                    ctx.fillText("Click · pick image", width / 2, height / 2 - 10)

                    ctx.fillStyle = root.colMuted
                    ctx.font = "11px sans-serif"
                    ctx.fillText("Double-click · shape", width / 2, height / 2 + 10)
                    ctx.fillText("Right-click · path", width / 2, height / 2 + 26)
                }
            }
        }

        // Confirm overlay
        Rectangle {
            visible: root.showConfirm
            anchors.fill: parent
            radius: 24
            color: "#E61E2A30"
            z: 20
            border.color: root.colPill
            border.width: 1

            Column {
                anchors.centerIn: parent
                width: parent.width - 24
                spacing: 10

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Use this image?"
                    color: root.colText
                    font.bold: true
                    font.pixelSize: 13
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.pendingPath
                    color: root.colMuted
                    font.pixelSize: 10
                    elide: Text.ElideMiddle
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Rectangle {
                        width: 72; height: 30; radius: 15
                        color: root.colAccent
                        Text {
                            anchors.centerIn: parent
                            text: "Apply"
                            color: root.colOnAccent
                            font.bold: true
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.imagePath = root.pendingPath
                                root.showConfirm = false
                                root.saveSettings()
                            }
                        }
                    }
                    Rectangle {
                        width: 72; height: 30; radius: 15
                        color: root.colPill
                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: root.colText
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.showConfirm = false
                        }
                    }
                }
            }
        }

        // Interaction (on top of canvas, under confirm)
        MouseArea {
            anchors.fill: parent
            z: 10
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            drag.target: root
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 10
            drag.maximumX: Math.max(10, root.screenWidth - root.width - 10)
            drag.minimumY: 10
            drag.maximumY: Math.max(10, root.screenHeight - root.height - 10)

            property bool dragged: false
            property real pressX: 0
            property real pressY: 0

            onPressed: (m) => {
                dragged = false
                pressX = m.x
                pressY = m.y
            }
            onPositionChanged: (m) => {
                if (Math.abs(m.x - pressX) > 4 || Math.abs(m.y - pressY) > 4)
                    dragged = true
            }
            onReleased: {
                if (dragged) {
                    root.posX = root.x
                    root.posY = root.y
                    root.saveSettings()
                }
            }

            Timer {
                id: clickWait
                interval: 240
                onTriggered: {
                    if (!parent.dragged && !root.showConfirm)
                        filePicker.running = true
                }
            }

            onClicked: (m) => {
                if (dragged || root.showConfirm) return
                if (m.button === Qt.RightButton) {
                    clickWait.stop()
                    pathPrompt.running = false
                    pathPrompt.running = true
                } else {
                    clickWait.restart()
                }
            }

            onDoubleClicked: (m) => {
                if (m.button !== Qt.LeftButton) return
                clickWait.stop()
                if (dragged) return
                root.shapeIndex = (root.shapeIndex + 1) % root.shapeNames.length
                root.saveSettings()
            }

            onWheel: (w) => {
                var ds = w.angleDelta.y / 1200.0
                root.scaleFactor = Math.round(Math.max(0.5, Math.min(2.5, root.scaleFactor + ds)) * 100) / 100
                root.saveSettings()
            }

            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }
    }
}
