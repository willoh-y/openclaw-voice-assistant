import Quickshell
import Quickshell.Io
import QtQuick

PanelWindow {
    id: window

    anchors {
        top: true
        right: true
    }

    margins {
        top: 20
        right: 20
    }

    implicitWidth: 60
    implicitHeight: 60

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // State from open_claw_voice.py
    property string state: "dormant"

    // Window is invisible when dormant
    visible: state !== "dormant"
    
    // Animation frame counter
    property int frame: 0

    // State-based configuration
    property var stateConfig: ({
        "dormant": {
            "chars": [""],
            "color": "transparent",
            "interval": 1000
        },
        "idle": {
            "chars": [".", "o", "O", "o"],
            "color": "#888888",
            "interval": 500
        },
        "listening": {
            "chars": ["|", "/", "-", "\\"],
            "color": "#4fc3f7",
            "interval": 80
        },
        "thinking": {
            "chars": [".", "..", "..."],
            "color": "#ffd54f",
            "interval": 300
        },
        "speaking": {
            "chars": ["((", "()", "))"],
            "color": "#81c784",
            "interval": 150
        },
        "error": {
            "chars": ["!", "!", " ", " "],
            "color": "#ef5350",
            "interval": 200
        }
    })

    // Current config based on state
    property var currentConfig: stateConfig[state] || stateConfig["dormant"]

    // Read state file
    FileView {
        id: stateFile
        path: Qt.resolvedUrl("./state.txt")
        watchChanges: true
        
        onFileChanged: this.reload()
        onLoaded: {
            var content = this.text().trim()
            if (content) {
                window.state = content
            }
        }
    }

    // Poll state file periodically as backup
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (stateFile.loaded) {
                stateFile.reload()
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: {
            var chars = currentConfig.chars
            return chars[frame % chars.length]
        }
        color: currentConfig.color
        font.pixelSize: 32
        font.family: "monospace"
        font.bold: true
    }

    Timer {
        id: animTimer
        interval: currentConfig.interval
        running: true
        repeat: true
        onTriggered: window.frame++
    }
}
