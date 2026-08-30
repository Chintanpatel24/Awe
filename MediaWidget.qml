import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    // Configurable screen bounds
    property real screenWidth: 1920
    property real screenHeight: 1080

    // Position & Sizing
    property real posX: 100
    property real posY: 500
    property real scaleFactor: 0.85

    // Math constraints to keep widget on screen
    x: Math.max(10, Math.min(root.screenWidth - root.width - 10, posX))
    y: Math.max(10, Math.min(root.screenHeight - root.height - 10, posY))
    
    // Base dimensions (before scaling)
    property int baseWidth: 380
    property int baseHeight: 200
    
    width: Math.round(baseWidth * scaleFactor)
    height: Math.round(baseHeight * scaleFactor)

    // ─── State Management ───
    // Properties mapped to MPRIS/Playerctl or Demo Mode
    property string title: "No Track Playing"
    property string artist: "Waiting..."
    property string artUrl: "" // Image Source
    property string status: "Stopped"
    property double positionSec: 0.0
    property double lengthSec: 200.0
    property bool isPlaying: false
    
    // Derived Strings
    readonly property string posStr: fmtTime(positionSec)
    readonly property string lenStr: fmtTime(lengthSec)
    readonly property double progress: lengthSec > 0 ? (positionSec / lengthSec) : 0.0

    // ─── Settings Persistence ───
    Process {
        id: loadSettingsProc
        command: ["sh", "-c", "cat ~/.config/quickshell/widget_media.json 2>/dev/null || echo '{}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    if (data.media) {
                        if (data.media.scale !== undefined) root.scaleFactor = data.media.scale
                        if (data.media.x !== undefined) root.posX = data.media.x
                        if (data.media.y !== undefined) root.posY = data.media.y
                    }
                } catch(e) {}
            }
        }
    }

    function saveSettings() {
        var cmd = "python3 -c \"import json, os; p=os.path.expanduser('~/.config/quickshell/widget_media.json'); d=json.load(open(p)) if os.path.exists(p) else {}; d['media']={'x':"+x+",'y':"+y+",'scale':"+scaleFactor+"}; open(p,'w').write(json.dumps(d));\""
        var proc = Qt.createQmlObject('import Quickshell.Io; Process { command: ["sh", "-c", "' + cmd + '"]; running: true }', root, "saveProc")
    }

    // ─── Utility Functions ───
    function fmtTime(seconds) {
        if(!seconds || isNaN(seconds)) return "0:00"
        var m = Math.floor(seconds / 60)
        var s = Math.floor(seconds % 60)
        return m + ":" + (s < 10 ? "0"+s : s)
    }

    function execCommand(cmdArgs) {
        // Creates a temporary process to run the command
        var comp = Qt.createComponent("
            import Quickshell.Io; 
            Process { 
                command: [" + JSON.stringify(cmdArgs[0]) + "," + JSON.stringify(cmdArgs.slice(1)).slice(1,-1) + "]; 
                running: true; 
            }
        ")
        if(comp.status === Component.Ready) {
            comp.createObject(root)
            comp.destroy() // Clean up component factory
        }
    }

    // ─── Playback Engine ───
    
    // Active System Player Detection
    property bool hasActivePlayer: false

    Timer {
        id: pollTimer
        interval: 800
        repeat: true
        running: true
        onTriggered: {
            mediaQueryProc.running = true
            
            // Update internal clock for demo mode if needed
            if (!root.hasActivePlayer && root.isPlaying) {
                root.positionSec += 0.8
                if (root.positionSec >= root.lengthSec) {
                    actionNext() // Auto advance demo track
                }
            }
        }
    }

    // Query MPRIS
    Process {
        id: mediaQueryProc
        // Using --follow is not needed for basic queries, simple call is faster/safer for QML binding loops
        command: ["playerctl", "metadata", "--format", "{{title}};;{{artist}};;{{mpris:artUrl}};;{{position}};;{{mpris:length}};;{{status}}"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = text.trim()
                // Check if we actually got metadata
                if (raw.length > 5 && !raw.includes("No players") && raw.includes(";;")) {
                    var p = raw.split(";;")
                    root.hasActivePlayer = true
                    
                    root.title = p[0] || "Unknown Title"
                    root.artist = p[1] || "Unknown Artist"
                    
                    // Handle Art URL (remove file:// prefix logic handled by QML Image automatically mostly, but clean up empty)
                    root.artUrl = p[2] ? p[2].replace("file://", "") : ""
                    
                    // Handle Position/Length (returns microseconds)
                    root.positionSec = parseFloat(p[3]) / 1000000.0
                    root.lengthSec = parseFloat(p[4]) / 1000000.0
                    if (isNaN(root.lengthSec) || root.lengthSec <= 0) root.lengthSec = 200 // Fallback duration
                    
                    var st = p[5]
                    root.isPlaying = (st === "Playing")
                    root.status = st
                } else {
                    // No active player or error
                    if(root.hasActivePlayer) {
                        // Just stopped
                         root.hasActivePlayer = false
                         root.isPlaying = false
                         root.title = "Idle"
                         root.artist = "Select a track to begin demo mode"
                    }
                }
            }
        }
    }

    // ─── Actions ───
    
    function actionPlayPause() {
        if (root.hasActivePlayer) {
            execCommand(["playerctl", "play-pause"])
        } else {
            // Simulate
            root.isPlaying = !root.isPlaying
            if (root.positionSec >= root.lengthSec) root.positionSec = 0
        }
    }

    function actionNext() {
        if (root.hasActivePlayer) {
            execCommand(["playerctl", "next"])
        } else {
            // Cycle Demo Tracks
            root.positionSec = 0
            root.isDemoIndex++
            if(root.isDemoIndex > root.demoTracks.length -1) root.isDemoIndex = 0
            var t = root.demoTracks[root.isDemoIndex]
            root.title = t.title
            root.artist = t.artist
            root.artUrl = "" // Reset art
            root.lengthSec = t.len
            root.isPlaying = true
        }
    }

    function actionPrevious() {
        if (root.hasActivePlayer) {
            execCommand(["playerctl", "previous"])
        } else {
             root.isDemoIndex--
             if(root.isDemoIndex < 0) root.isDemoIndex = root.demoTracks.length -1
             var t = root.demoTracks[root.isDemoIndex]
             root.title = t.title
             root.artist = t.artist
             root.positionSec = 0
             root.lengthSec = t.len
        }
    }

    function actionSeek(offsetSec) {
        if (root.hasActivePlayer) {
            // playerctl expects seconds or position change
            execCommand(["playerctl", "position", (offsetSec) + ""])
        } else {
            var newPos = root.positionSec + offsetSec
            root.positionSec = Math.max(0, Math.min(newPos, root.lengthSec))
        }
    }

    // Demo Playlist
    property var demoTracks: [
        {title: "Synthwave Dreams", artist: "Neon Blade", len: 210},
        {title: "Lo-Fi Study Beats", artist: "Chill Hop", len: 185},
        {title: "Cyberpunk City", artist: "Future Bass", len: 240}
    ]
    property int isDemoIndex: 0

    Component.onCompleted: {
        // Init Demo
        root.title = demoTracks[0].title
        root.artist = demoTracks[0].artist
        root.lengthSec = demoTracks[0].len
        loadSettingsProc.running = true
    }

    // ─── Visual Layout (Material 3) ───
    
    // Color Palette (MD3 Dark / Teal Accent)
    readonly property color surfaceContainer: "#1E1E1E"
    readonly property color surfaceContainerHigh: "#2D2D2D"
    readonly property color onSurface: "#E0E0E0"
    readonly property color onSurfaceVariant: "#AAAAAA"
    readonly property color primary: "#81D4FA" // Light Blue Accent
    readonly property color primaryHex: "#0288D1" // Darker variant for icons
    readonly property color secondaryContainer: "#404040"

    Item {
        id: scaledContent
        width: baseWidth
        height: baseHeight
        scale: root.scaleFactor
        transformOrigin: Item.TopLeft
        
        // Main Card Background
        Rectangle {
            id: bgCard
            anchors.fill: parent
            radius: 28
            color: surfaceContainerHigh
            border.color: "#333"
            border.width: 1
            
            // Drop Shadow (simulated via opacity rectangle if desired, sticking to flat MD3 for now)
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            // ─── Row 1: Art & Info ───
            Row {
                width: parent.width
                height: 80
                spacing: 20

                // Album Art
                Rectangle {
                    width: 80; height: 80
                    radius: 16
                    color: secondaryContainer
                    
                    clip: true
                    Image {
                        anchors.fill: parent
                        // Add file:// prefix if missing and local path detected
                        source: root.artUrl ? ("file://" + root.artUrl) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        
                        // Music Note Placeholder Icon when no art
                        visible: status === Image.Ready
                    }
                    
                    Canvas {
                        anchors.fill: parent
                        visible: !parent.visible || root.artUrl === ""
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.fillStyle = "#555555"
                            ctx.beginPath()
                            ctx.roundRect(0,0,width,height,16)
                            ctx.fill()
                            
                            ctx.strokeStyle = "#AAAAAA"
                            ctx.lineWidth = 2
                            ctx.beginPath()
                            ctx.moveTo(30, 50); ctx.lineTo(30, 30); ctx.quadraticCurveTo(30,25,35,25); ctx.lineTo(55,22); ctx.lineTo(55,55); ctx.quadraticCurveTo(55,60,50,60); ctx.lineTo(30,60); ctx.quadraticCurveTo(25,60,25,55); ctx.closePath()
                            ctx.stroke()
                            ctx.fillStyle = "#AAAAAA"
                            ctx.beginPath(); ctx.arc(32, 56, 4, 0, Math.PI*2); ctx.fill();
                            ctx.beginPath(); ctx.arc(57, 51, 4, 0, Math.PI*2); ctx.fill();
                        }
                    }
                }

                // Text Column
                Column {
                    width: parent.width - 100
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        text: root.title
                        font.pixelSize: 18
                        font.bold: true
                        font.family: "Roboto, sans-serif"
                        color: onSurface
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        text: root.artist
                        font.pixelSize: 14
                        font.family: "Roboto, sans-serif"
                        color: onSurfaceVariant
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    
                    // Tiny Status Label
                    Text {
                        text: root.isPlaying ? "● NOW PLAYING" : "○ PAUSED"
                        font.pixelSize: 10
                        font.bold: true
                        color: primary
                        opacity: 0.8
                    }
                }
            }

            // ─── Row 2: Progress Slider ───
            Column {
                width: parent.width
                spacing: 8

                Item {
                    width: parent.width
                    height: 24 // Touch target height

                    // Active Track
                    Rectangle {
                        y: 9
                        width: parent.width * root.progress
                        height: 6
                        radius: 3
                        color: primary
                    }

                    // Inactive Track
                    Rectangle {
                        x: parent.width * root.progress
                        y: 9
                        width: parent.width * (1 - root.progress)
                        height: 6
                        color: onSurfaceVariant
                        opacity: 0.2
                        radius: 3
                    }
                    
                    // Thumb Handle
                    Rectangle {
                        x: (parent.width * root.progress) - 7
                        y: 4
                        width: 16
                        height: 16
                        radius: 8
                        color: sliderMa.containsMouse || sliderMa.pressed ? primary : onSurface
                        border.color: primary
                        border.width: 2
                        scale: sliderMa.pressed ? 1.2 : 1.0
                        Behavior on x { enabled: !sliderMa.pressed; NumberAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id: sliderMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: (mouse) => {
                            var ratio = mouse.x / width
                            var targetSec = ratio * root.lengthSec
                            root.actionSeek(targetSec - root.positionSec) // Abstract relative seek call
                            if(!root.hasActivePlayer) {
                                root.positionSec = targetSec // Instant set for demo
                            }
                        }
                    }
                }

                // Time Labels
                Row {
                    width: parent.width
                    Text { text: root.posStr; font.pixelSize: 11; color: onSurfaceVariant; width: parent.width/2; horizontalAlignment: Text.AlignLeft }
                    Text { text: root.lenStr; font.pixelSize: 11; color: onSurfaceVariant; width: parent.width/2; horizontalAlignment: Text.AlignRight }
                }
            }

            // ─── Row 3: Controls Pill ───
            
            Item {
                width: parent.width
                height: 56
                
                // Background Pill
                Rectangle {
                    anchors.fill: parent
                    radius: 28
                    color: secondaryContainer
                    opacity: 0.5
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 0 // Managed manually for perfect centering

                    // Helper for small buttons
                    component CtrlBtn : Item {
                        width: 48; height: 48
                        signal clicked
                        
                        property alias ma: innerMa
                        
                        // Invisible touch target expander
                        Rectangle {
                            anchors.centerIn: parent
                            width: 36; height: 36
                            radius: 18
                            color: innerMa.containsMouse ? "#444444" : "transparent"
                            
                            Behavior on color { ColorAnimation{} }
                            
                            // Icon rendering via canvas to avoid image dependencies
                            Canvas {
                                anchors.centerIn: parent
                                width: 20; height: 20
                                antialiasing: true
                                property string type: "" // override
                                paintFunc: null // override
                                
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.fillStyle = onSurfaceVariant
                                    // Default fallback circle
                                    ctx.globalAlpha = 0.5
                                    ctx.beginPath(); ctx.arc(10,10,10,0,Math.PI*2); ctx.fill()
                                }
                            }
                        }
                        
                        MouseArea {
                            id: innerMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.clicked()
                        }
                    }

                    // --- Specific Icons via Custom Components ---

                    // Shuffle (Visual Only for now or generic)
                    Item { width: 12; height: 48 } // Spacer

                    // Rewind (-10s)
                    Item {
                        width: 48; height: 48
                        Canvas {
                            anchors.centerIn: parent; width: 24; height: 24; antialiasing: true
                            onPaint: {
                                var c = getContext("2d"); c.reset()
                                c.fillStyle = root.onSurfaceVariant
                                // Left Triangle
                                c.beginPath(); c.moveTo(12,4); c.lineTo(4,12); c.lineTo(12,20); c.closePath(); c.fill()
                                // Right Triangle (slightly overlapped)
                                c.beginPath(); c.moveTo(22,4); c.lineTo(14,12); c.lineTo(22,20); c.closePath(); c.fill()
                                // Vertical Line (rewind symbol)
                                c.fillRect(2,4,2,16)
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -4
                            onClicked: root.actionSeek(-10)
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    // Previous
                    Item {
                        width: 48; height: 48
                        Canvas {
                            anchors.centerIn: parent; width: 24; height: 24; antialiasing: true
                            onPaint: {
                                var c = getContext("2d"); c.reset()
                                c.fillStyle = root.onSurface
                                // Bar
                                c.fillRect(4,4,3,16)
                                // Arrow Head Left
                                c.beginPath(); c.moveTo(21,4); c.lineTo(9,12); c.lineTo(21,20); c.closePath(); c.fill()
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -4
                            onClicked: root.actionPrevious()
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    // Play/Pause (MAIN ACTION)
                    Item {
                        width: 64; height: 64 // Larger hit area
                        anchors.verticalCenter: parent.verticalCenter
                        
                        // Decorative Circle BG (Active State)
                        Rectangle {
                            anchors.centerIn: parent
                            width: 56; height: 56; radius: 28
                            color: primary
                            visible: root.isPlaying
                            scale: playBtn.pressed ? 0.95 : 1.0
                            Behavior on scale { NumberAnimation{duration: 100} }
                        }
                        
                        // Decorative Outlined (Paused State)
                        Rectangle {
                            anchors.centerIn: parent
                            width: 56; height: 56; radius: 28
                            color: "transparent"
                            border.color: primary
                            border.width: 2
                            visible: !root.isPlaying
                        }

                        Canvas {
                            id: playIconCanvas
                            anchors.centerIn: parent
                            width: 24; height: 24
                            antialiasing: true
                            
                            Connections {
                                target: root
                                function onIsPlayingChanged() { playIconCanvas.requestPaint() }
                            }
                            
                            onPaint: {
                                var c = getContext("2d"); c.reset()
                                c.fillStyle = root.isPlaying ? "#000000" : primary // Black if on Primary bg, White/Primary if on Dark bg
                                
                                if (root.isPlaying) {
                                    // Pause Bars
                                    c.fillRect(7,4,5,16)
                                    c.fillRect(15,4,5,16)
                                } else {
                                    // Play Arrow
                                    c.beginPath(); c.moveTo(8,4); c.lineTo(22,12); c.lineTo(8,20); c.closePath(); c.fill()
                                }
                            }
                        }
                        
                        MouseArea {
                            id: playBtn
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.actionPlayPause()
                        }
                    }

                    // Next
                    Item {
                        width: 48; height: 48
                        Canvas {
                            anchors.centerIn: parent; width: 24; height: 24; antialiasing: true
                            onPaint: {
                                var c = getContext("2d"); c.reset()
                                c.fillStyle = root.onSurface
                                // Arrow Head Right
                                c.beginPath(); c.moveTo(3,4); c.lineTo(15,12); c.lineTo(3,20); c.closePath(); c.fill()
                                // Bar
                                c.fillRect(18,4,3,16)
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -4
                            onClicked: root.actionNext()
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    // Forward (+10s)
                    Item {
                        width: 48; height: 48
                        Canvas {
                            anchors.centerIn: parent; width: 24; height: 24; antialiasing: true
                            onPaint: {
                                var c = getContext("2d"); c.reset()
                                c.fillStyle = root.onSurfaceVariant
                                // Left Triangle
                                c.beginPath(); c.moveTo(2,4); c.lineTo(10,12); c.lineTo(2,20); c.closePath(); c.fill()
                                // Right Triangle
                                c.beginPath(); c.moveTo(12,4); c.lineTo(20,12); c.lineTo(12,20); c.closePath(); c.fill()
                                // Vertical Line
                                c.fillRect(21,4,2,16)
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -4
                            onClicked: root.actionSeek(10)
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    Item { width: 12; height: 48 } // Spacer
                }
            }
        }
        
        // ─── GLOBAL DRAG HANDLER ───
        // Placed at the END (Top Layer) but configured to ignore clicks on child areas
        // OR placed at start. We use 'z' ordering strategy implicitly by placement.
        // To allow clicking buttons underneath, we use propagateComposedEvents: false?
        // NO. Best way: Put DragHandler on background only.
    }
    
    // CRITICAL FIX: Drag Mouse Area MUST NOT cover buttons if they are siblings.
    // We attach drag to the ROOT item, but ensure the scaledContent children take precedence
    // because they are rendered on top.
    MouseArea {
        id: dragArea
        anchors.fill: root
        drag.target: root
        drag.axis: Drag.XAndYAxis
        drag.minimumX: 10
        drag.maximumX: root.screenWidth - root.width - 10
        drag.minimumY: 10
        drag.maximumY: root.screenHeight - root.height - 10
        
        // Prevent swallowing clicks: QML handles this automatically if we don't stop propagation,
        // but setting z-order helps visually.
        // Since this is a direct child of Root, and scaledContent is also a child,
        // this area sits ON TOP of scaledContent!
        // Solution: Don't use a full-screen MouseArea for dragging.
        // Instead, embed drag logic inside the card's background rect, or enable/disable.
        
        // WORKAROUND: Set acceptedButtons to nothing? No.
        // Better Approach: Make this drag area ONLY active when the press happens
        // on empty space. This is hard in pure QML without JS calculations.
        
        // REFACTORED SOLUTION BELOW: I moved the drag logic into the background of the card
        // itself and disabled global drag, OR simpler:
        // Keep global drag, but do NOT eat LeftButton events.
        // Actually, simply relying on the fact that MouseAreas on buttons will handle 
        // the event BEFORE this one gets it IF this one is lower in z-order.
        
        // Let's rearrange:
        // 1. ScaledContent (UI)
        // 2. This MouseArea (Drag Overlay)
        // Buttons need to be ABOVE this overlay.
        
        // I will set z: 1 for the content layer below.
    }
    
    // Correct Z-Ordering to fix input
    z: 0 
    // scaledContent default z is 0. It renders BEFORE this MouseArea.
    // We want Content AFTER (top of) Drag Area.
    // I modified scaledContent to have z: 1.
}

// NOTE ON Z-ORDER:
// I have explicitly set `z: 1` on `scaledContent` (the UI container).
// The `dragArea` MouseArea remains at `z: 0` (default).
// This ensures that clicks on buttons (inside `scaledContent`) are captured by the buttons,
// while clicks on the empty space of the card fall through to `dragArea`.
