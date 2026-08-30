import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property real screenWidth: 1920
    property real screenHeight: 1080

    // Position & sizing properties
    property real posX: 400
    property real posY: 480
    property real scaleFactor: 0.85

    x: Math.max(10, Math.min(root.screenWidth - root.width - 10, posX))
    y: Math.max(10, Math.min(root.screenHeight - root.height - 10, posY))
    width: Math.round(200 * scaleFactor)
    height: Math.round(200 * scaleFactor)

    // Properties
    property string imagePath: ""
    property string tempPathInput: ""
    property int shapeIndex: 0
    property bool showPathDialog: false

    // Material 3 Colors
    readonly property color colBgDark: "#1E2A30"
    readonly property color colSurface: "#2B3236"
    readonly property color colPrimary: "#A8C7FA"
    readonly property color colOnPrimary: "#062E6F"
    readonly property color colTextMain: "#E3E2E6"
    readonly property color colTextSub: "#C4C6CA"

    // ─── Settings Persistence ───
    Process {
        id: loadSettingsProc
        command: ["sh", "-c", "cat ~/.config/quickshell/widget_settings.json 2>/dev/null || echo '{}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    if (data.poster) {
                        if (data.poster.scale !== undefined) root.scaleFactor = Math.max(0.5, Math.min(2.5, data.poster.scale))
                        var w = Math.round(200 * root.scaleFactor)
                        var h = Math.round(200 * root.scaleFactor)
                        if (data.poster.x !== undefined) root.posX = Math.max(10, Math.min(root.screenWidth - w - 10, data.poster.x))
                        if (data.poster.y !== undefined) root.posY = Math.max(10, Math.min(root.screenHeight - h - 10, data.poster.y))
                        if (data.poster.imagePath !== undefined) root.imagePath = data.poster.imagePath
                        if (data.poster.shapeIndex !== undefined) root.shapeIndex = data.poster.shapeIndex
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
        var safePath = root.imagePath.replace(/'/g, "'\\''")
        var script = "python3 -c 'import json, os; p=os.path.expanduser(\"~/.config/quickshell/widget_settings.json\"); d=json.load(open(p)) if os.path.exists(p) else {}; d[\"poster\"]={\"x\":" + Math.round(root.x) + ",\"y\":" + Math.round(root.y) + ",\"scale\":" + root.scaleFactor.toFixed(2) + ",\"imagePath\":\"" + safePath + "\",\"shapeIndex\":" + root.shapeIndex + "}; open(p,\"w\").write(json.dumps(d,indent=2))'"
        saveSettingsProc.command = ["sh", "-c", script]
        saveSettingsProc.running = true
    }

    // ─── Robust Native File Pickers (Zenity -> Python Fallback) ───
    Process {
        id: pathPromptProc
        command: ["sh", "-c", "zenity --entry --title='Image Path' --text='Paste image file path or URL:' 2>/dev/null || python3 -c \"import tkinter as tk, tkinter.simpledialog as sd; root=tk.Tk(); root.withdraw(); root.attributes('-topmost', True); path=sd.askstring('Image Path', 'Paste image file path or URL:'); print(path if path else '')\" 2>/dev/null || echo ''"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var selected = text.trim()
                if (selected.length > 0) {
                    root.tempPathInput = selected
                    root.showPathDialog = true
                }
            }
        }
    }

    Process {
        id: pickerProc
        command: ["sh", "-c", "zenity --file-selection --title='Select Image for Frame' --file-filter='Images | *.png *.jpg *.jpeg *.webp *.bmp *.gif' 2>/dev/null || python3 -c \"import tkinter as tk, tkinter.filedialog as fd; root=tk.Tk(); root.withdraw(); root.attributes('-topmost', True); path=fd.askopenfilename(title='Select Image', filetypes=[('Images', '*.png *.jpg *.jpeg *.webp *.bmp *.gif')]); print(path if path else '')\" 2>/dev/null || echo ''"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var selected = text.trim()
                if (selected.length > 0) {
                    root.tempPathInput = selected
                    root.showPathDialog = true
                }
            }
        }
    }

    Component.onCompleted: {
        loadSettingsProc.running = true
    }

    // ─── Math for Smooth / Curved Shapes ───
    property var shapeNames: [
        "circle", "squircle", "stadium_h", "arch",
        "semicircle_top", "ellipse", "pebble", "pillow",
        "flower_4", "scallop_8", "clover_4", "badge_4",
        "pill_v", "heart"
    ]

    function drawShapePath(ctx, shapeType, w, h) {
        var cx = w / 2; var cy = h / 2; var r = Math.min(w, h) / 2 - 2;
        ctx.beginPath()

        if (shapeType === "circle") ctx.arc(cx, cy, r, 0, Math.PI * 2)
        else if (shapeType === "squircle") {
            var rad = r * 0.45; ctx.moveTo(cx - r + rad, cy - r); ctx.lineTo(cx + r - rad, cy - r);
            ctx.quadraticCurveTo(cx + r, cy - r, cx + r, cy - r + rad); ctx.lineTo(cx + r, cy + r - rad);
            ctx.quadraticCurveTo(cx + r, cy + r, cx + r - rad, cy + r); ctx.lineTo(cx - r + rad, cy + r);
            ctx.quadraticCurveTo(cx - r, cy + r, cx - r, cy + r - rad); ctx.lineTo(cx - r, cy - r + rad);
            ctx.quadraticCurveTo(cx - r, cy - r, cx - r + rad, cy - r);
        } else if (shapeType === "heart") {
            ctx.moveTo(cx, cy + r * 0.75);
            ctx.bezierCurveTo(cx - r * 1.1, cy + r * 0.2, cx - r * 1.1, cy - r * 0.7, cx, cy - r * 0.35);
            ctx.bezierCurveTo(cx + r * 1.1, cy - r * 0.7, cx + r * 1.1, cy + r * 0.2, cx, cy + r * 0.75);
        } else if (shapeType === "flower_4") {
            var rIn = r * 0.65
            for (var fl = 0; fl <= 360; fl += 3) {
                var flR = rIn + (r - rIn) * (Math.cos(4 * (fl * Math.PI / 180)) + 1.0) / 2.0
                var fx = cx + flR * Math.sin(fl * Math.PI / 180)
                var fy = cy - flR * Math.cos(fl * Math.PI / 180)
                if (fl === 0) ctx.moveTo(fx, fy); else ctx.lineTo(fx, fy);
            }
        } 
        // Fallback catch-all for simplicity of demo
        else ctx.arc(cx, cy, r, 0, Math.PI * 2)
        
        ctx.closePath()
    }

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 200
        height: 200
        scale: root.scaleFactor
        transformOrigin: Item.TopLeft

        Canvas {
            id: shapeCanvas
            anchors.fill: parent
            antialiasing: true

            Connections {
                target: root
                function onImagePathChanged() { 
                    if (root.imagePath.length > 0) {
                        var safeUrl = root.imagePath.startsWith("/") ? "file://" + root.imagePath : root.imagePath
                        shapeCanvas.loadImage(safeUrl)
                    } else {
                        shapeCanvas.requestPaint()
                    }
                }
                function onShapeIndexChanged() { shapeCanvas.requestPaint() }
            }

            onImageLoaded: {
                shapeCanvas.requestPaint()
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()

                var currentShape = root.shapeNames[root.shapeIndex % root.shapeNames.length]

                // Draw path & clip bounds to it
                root.drawShapePath(ctx, currentShape, width, height)
                ctx.clip()

                var safeUrl = root.imagePath.startsWith("/") ? "file://" + root.imagePath : root.imagePath

                if (root.imagePath.length > 0 && shapeCanvas.isImageLoaded(safeUrl)) {
                    // Draw actual image inside the shape
                    ctx.drawImage(safeUrl, 0, 0, width, height)
                } else {
                    // M3 Style Empty/Placeholder State
                    var grad = ctx.createLinearGradient(0, 0, width, height)
                    grad.addColorStop(0, "#3F484C")
                    grad.addColorStop(1, "#1E2A30")
                    ctx.fillStyle = grad
                    ctx.fill()

                    ctx.fillStyle = root.colPrimary
                    ctx.font = "bold 12px sans-serif"
                    ctx.textAlign = "center"
                    ctx.textBaseline = "middle"
                    ctx.fillText("Click to add Pic", width / 2, height / 2 - 8)
                    
                    ctx.fillStyle = root.colTextSub
                    ctx.font = "11px sans-serif"
                    ctx.fillText("Double-tap for Shape", width / 2, height / 2 + 12)
                }
            }
        }

        // ─── M3 Confirmation Overlay ───
        Rectangle {
            id: pathConfirmOverlay
            visible: root.showPathDialog
            anchors.fill: parent
            radius: 28
            color: Qt.rgba(0.17, 0.2, 0.21, 0.95) // Dark transparent surface
            border.color: "#3F484C"
            border.width: 1
            z: 100

            Column {
                anchors.centerIn: parent
                spacing: 12
                width: parent.width - 32

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Apply Image?"
                    color: root.colTextMain
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.tempPathInput.length > 25 ? "..." + root.tempPathInput.slice(-22) : root.tempPathInput
                    color: root.colTextSub
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    // Apply Button
                    Rectangle {
                        width: 70
                        height: 32
                        radius: 16
                        color: root.colPrimary

                        Text {
                            anchors.centerIn: parent
                            text: "Apply"
                            color: root.colOnPrimary
                            font.pixelSize: 12
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.imagePath = root.tempPathInput
                                root.showPathDialog = false
                                root.saveSettings()
                            }
                        }
                    }

                    // Cancel Button
                    Rectangle {
                        width: 70
                        height: 32
                        radius: 16
                        color: "#3F484C"

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: root.colTextMain
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.showPathDialog = false
                        }
                    }
                }
            }
        }
    }

    // Timer to handle double-click without firing single-click
    Timer {
        id: singleClickTimer
        interval: 250
        repeat: false
        onTriggered: {
            pickerProc.running = true
        }
    }

    // ─── Mouse Handling ───
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        property bool isDragging: false
        drag.target: root
        drag.axis: Drag.XAndYAxis

        onPressed: isDragging = false
        onPositionChanged: if (drag.active) isDragging = true
        
        cursorShape: drag.active ? Qt.ClosedHandCursor : (containsMouse ? Qt.OpenHandCursor : Qt.ArrowCursor)

        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton && !isDragging) {
                singleClickTimer.stop()
                root.shapeIndex = (root.shapeIndex + 1) % root.shapeNames.length
                root.saveSettings()
            }
        }

        onClicked: (mouse) => {
            if (isDragging || root.showPathDialog) return;
            
            if (mouse.button === Qt.RightButton) {
                singleClickTimer.stop()
                pathPromptProc.running = true
            } else if (mouse.button === Qt.LeftButton) {
                singleClickTimer.start()
            }
        }

        onReleased: {
            if (isDragging) {
                root.posX = root.x
                root.posY = root.y
                root.saveSettings()
            }
        }

        onWheel: (wheel) => {
            var delta = wheel.angleDelta.y / 1200.0
            root.scaleFactor = Math.max(0.5, Math.min(2.5, root.scaleFactor + delta))
            root.saveSettings()
        }
    }
}
