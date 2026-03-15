import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects

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

    implicitWidth: 100
    implicitHeight: 100

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // State from openclaw_voice_assistant.py
    property string state: "dormant"

    // Window is invisible when dormant
    visible: state !== "dormant"

    // State-based configuration
    property var stateConfig: ({
        "dormant": {
            "char": "",
            "color": "transparent",
            "minOpacity": 1.0,
            "maxOpacity": 1.0,
            "pulseDuration": 1000
        },
        "idle": {
            "char": "󰒲",
            "color": "#888888",
            "minOpacity": 0.5,
            "maxOpacity": 1.0,
            "pulseDuration": 2000
        },
        "listening": {
            "char": "󰟅",
            "color": "#4fc3f7",
            "minOpacity": 0.7,
            "maxOpacity": 1.0,
            "pulseDuration": 800
        },
        "thinking": {
            "char": "󰧑",
            "color": "#ff9800",
            "minOpacity": 0.5,
            "maxOpacity": 1.0,
            "pulseDuration": 1200
        },
        "speaking": {
            "char": "󰗋",
            "color": "#81c784",
            "minOpacity": 0.7,
            "maxOpacity": 1.0,
            "pulseDuration": 500
        },
        "error": {
            "char": "x",
            "color": "#ef5350",
            "minOpacity": 0.5,
            "maxOpacity": 1.0,
            "pulseDuration": 600
        }
    })

    // Current config based on state
    property var currentConfig: stateConfig[state] || stateConfig["dormant"]

    // Restart pulse animation when state changes
    onStateChanged: {
        pulseAnimation.restart()
    }

    // Read state file
    // In dev mode: ./state.txt (relative to script)
    // In production: $XDG_RUNTIME_DIR/openclaw-voice-assistant/state.txt
    property string stateFilePath: {
        var envPath = Quickshell.env("OPENCLAW_VOICE_ASSISTANT_STATE_FILE")
        if (envPath) return envPath

        var runtimeDir = Quickshell.env("XDG_RUNTIME_DIR")
        if (runtimeDir) return runtimeDir + "/openclaw-voice-assistant/state.txt"

        // Fallback to relative path for dev mode
        return Qt.resolvedUrl("./state.txt")
    }

    FileView {
        id: stateFile
        path: window.stateFilePath
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

    // Outer border with shadow
    Rectangle {
        id: outerBorder
        anchors.centerIn: parent
        width: 74
        height: 74
        radius: 0
        color: "#888888"

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#80000000"
            shadowHorizontalOffset: 2
            shadowVerticalOffset: 2
            shadowBlur: 0.5
        }

        // Inner background
        Rectangle {
            id: background
            anchors.centerIn: parent
            width: 70
            height: 70
            radius: 0
            color: "#dcdad5"

            Column {
                anchors.centerIn: parent
                spacing: 4

                Text {
                    id: stateIcon
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: currentConfig.char
                    color: currentConfig.color
                    font.pixelSize: 32
                    font.family: "GohuFont 14 Nerd Font Mono"
                    font.bold: true

                    // Opacity pulse animation
                    SequentialAnimation on opacity {
                        id: pulseAnimation
                        loops: Animation.Infinite
                        running: window.state !== "dormant"

                        NumberAnimation {
                            from: window.currentConfig.maxOpacity
                            to: window.currentConfig.minOpacity
                            duration: window.currentConfig.pulseDuration / 2
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            from: window.currentConfig.minOpacity
                            to: window.currentConfig.maxOpacity
                            duration: window.currentConfig.pulseDuration / 2
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                // State label
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: window.state
                    color: currentConfig.color
                    font.pixelSize: 10
                    font.family: "GohuFont 14 Nerd Font Mono"
                }
            }
        }
    }
}
