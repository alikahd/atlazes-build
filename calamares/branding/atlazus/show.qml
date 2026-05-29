import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        interval: 4000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0a0e27"
            Column {
                anchors.centerIn: parent
                spacing: 20
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "ATLAZUS OS"
                    font.pixelSize: 36
                    font.bold: true
                    color: "#00d4ff"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Secure · Private · Professional"
                    font.pixelSize: 16
                    color: "#ffffff"
                    opacity: 0.7
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0a0e27"
            Column {
                anchors.centerIn: parent
                spacing: 16
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "🔒 Security"
                    font.pixelSize: 28
                    color: "#00d4ff"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "UFW Firewall + AppArmor + Firejail"
                    font.pixelSize: 14
                    color: "#c9d1d9"
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0a0e27"
            Column {
                anchors.centerIn: parent
                spacing: 16
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "🕵️ Privacy"
                    font.pixelSize: 28
                    color: "#00d4ff"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Tor + MAC Randomization + DNS Encryption"
                    font.pixelSize: 14
                    color: "#c9d1d9"
                }
            }
        }
    }
}
