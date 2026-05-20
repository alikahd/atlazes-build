/* =============================================================================
   ATLAZES OS - Calamares Installation Slideshow
   ============================================================================= */

import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function nextSlide() {
        presentation.goToNextSlide()
    }

    Timer {
        id: advanceTimer
        interval: 5000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    // ── Slide 1: Welcome ──────────────────────────────────────────────────────
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"

            Column {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Welcome to ATLAZES OS"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#388bfd"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Secure · Private · Professional"
                    font.pixelSize: 18
                    color: "#8b949e"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Installing your new operating system..."
                    font.pixelSize: 14
                    color: "#c9d1d9"
                }
            }
        }
    }

    // ── Slide 2: Privacy ──────────────────────────────────────────────────────
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"

            Column {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "🔒 Privacy First"
                    font.pixelSize: 28
                    font.bold: true
                    color: "#388bfd"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "• No telemetry or background tracking"
                    font.pixelSize: 16
                    color: "#c9d1d9"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "• DNS over HTTPS encrypted by default"
                    font.pixelSize: 16
                    color: "#c9d1d9"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "• MAC address randomization"
                    font.pixelSize: 16
                    color: "#c9d1d9"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "• Hardened Firefox ESR with uBlock Origin"
                    font.pixelSize: 16
                    color: "#c9d1d9"
                }
            }
        }
    }

    // ── Slide 3: Security ─────────────────────────────────────────────────────
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"

            Column {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "🛡️ Security Hardened"
                    font.pixelSize: 28
                    font.bold: true
                    color: "#388bfd"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "• Full disk encryption with LUKS2"
                    font.pixelSize: 16
                    color: "#c9d1d9"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "• AppArmor mandatory access control"
                    font.pixelSize: 16
                    color: "#c9d1d9"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "• UFW firewall enabled by default"
                    font.pixelSize: 16
                    color: "#c9d1d9"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "• Hardened kernel parameters"
                    font.pixelSize: 16
                    color: "#c9d1d9"
                }
            }
        }
    }

    // ── Slide 4: Developer Tools ──────────────────────────────────────────────
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"

            Column {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "⚡ Developer Ready"
                    font.pixelSize: 28
                    font.bold: true
                    color: "#388bfd"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "• VSCodium (VS Code without telemetry)"
                    font.pixelSize: 16
                    color: "#c9d1d9"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "• Node.js, Python, Git pre-installed"
                    font.pixelSize: 16
                    color: "#c9d1d9"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "• Docker and container tools"
                    font.pixelSize: 16
                    color: "#c9d1d9"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "• Full build toolchain included"
                    font.pixelSize: 16
                    color: "#c9d1d9"
                }
            }
        }
    }

    // ── Slide 5: Almost done ──────────────────────────────────────────────────
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"

            Column {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "✅ Almost Done!"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#3fb950"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "ATLAZES OS is being installed on your system."
                    font.pixelSize: 16
                    color: "#c9d1d9"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "This will only take a few more minutes."
                    font.pixelSize: 14
                    color: "#8b949e"
                }
            }
        }
    }
}
