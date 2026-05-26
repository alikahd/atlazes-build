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
        interval: 5500
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#090d18"

            Column {
                anchors.centerIn: parent
                spacing: 18

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "logo.png"
                    width: 128
                    height: 128
                    fillMode: Image.PreserveAspectFit
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "ATLAZES OS"
                    font.pixelSize: 34
                    font.bold: true
                    color: "#00d4ff"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Private desktop. Hardened defaults. Lightweight base."
                    font.pixelSize: 16
                    color: "#c9d1d9"
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#090d18"

            Column {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Privacy by default"
                    font.pixelSize: 28
                    font.bold: true
                    color: "#00d4ff"
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Firefox privacy policies"; font.pixelSize: 16; color: "#c9d1d9" }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "MAC randomization for new network profiles"; font.pixelSize: 16; color: "#c9d1d9" }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Tor, proxychains, and metadata cleaning tools"; font.pixelSize: 16; color: "#c9d1d9" }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#090d18"

            Column {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Security without bloat"
                    font.pixelSize: 28
                    font.bold: true
                    color: "#00d4ff"
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "AppArmor, UFW, and hardened sysctl defaults"; font.pixelSize: 16; color: "#c9d1d9" }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Firejail sandboxing for supported applications"; font.pixelSize: 16; color: "#c9d1d9" }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Heavy scanners are optional, not always running"; font.pixelSize: 16; color: "#c9d1d9" }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#090d18"

            Column {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "A clean XFCE experience"
                    font.pixelSize: 28
                    font.bold: true
                    color: "#00d4ff"
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "ATLAZES artwork across boot, login, desktop, and installer"; font.pixelSize: 16; color: "#c9d1d9" }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Small, familiar tools for daily private work"; font.pixelSize: 16; color: "#c9d1d9" }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Built from Debian compatibility with its own visible identity"; font.pixelSize: 16; color: "#c9d1d9" }
            }
        }
    }
}
