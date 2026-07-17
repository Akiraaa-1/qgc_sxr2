import QtQuick
import QtQuick.Controls
import QtQuick.Effects

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: control

    // Indicates whether calibration is valid for this control
    property bool calValid: false

    // Indicates whether the control is currently being calibrated
    property bool calInProgress: false

    // Text to show while calibration is in progress
    property string calInProgressText: qsTr("Hold Still")

    // Image source
    property var imageSource: ""

    property bool modernStyle: false

    readonly property color _statusColor: calInProgress ? "#EAB308" : (calValid ? "#22C55E" : "#64748B")
    readonly property color _panelColor: "#2B2E31"
    readonly property color _panelBorderColor: Qt.rgba(_statusColor.r, _statusColor.g, _statusColor.b, calInProgress || calValid ? 0.95 : 0.45)
    readonly property color _modelTintColor: calInProgress ? "#FDE68A" : (calValid ? "#A7F3D0" : "#B8C7D6")
    readonly property string _statusText: calInProgress ? calInProgressText : (calValid ? qsTr("Completed") : qsTr("Incomplete"))

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    color: modernStyle ? _panelColor : (calInProgress ? "yellow" : (calValid ? "green" : "red"))
    radius: modernStyle ? ScreenTools.defaultFontPixelHeight * 0.18 : 0
    border.width: modernStyle ? 1 : 0
    border.color: _panelBorderColor
    clip: true

    Behavior on color { ColorAnimation { duration: 180 } }
    Behavior on border.color { ColorAnimation { duration: 180 } }

    Rectangle {
        visible: modernStyle
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(2, ScreenTools.defaultFontPixelWidth * 0.22)
        color: control._statusColor
        opacity: control.calInProgress || control.calValid ? 1 : 0.45
    }

    Rectangle {
        readonly property int inset: 5

        x:      modernStyle ? ScreenTools.defaultFontPixelWidth * 0.35 : inset
        y:      modernStyle ? ScreenTools.defaultFontPixelHeight * 0.28 : inset
        width:  parent.width - (x * 2)
        height: parent.height - (y * 2)
        color: modernStyle ? Qt.rgba(1, 1, 1, 0.02) : qgcPal.windowShade
        radius: modernStyle ? Math.max(0, parent.radius - ScreenTools.defaultFontPixelHeight * 0.08) : 0

        Rectangle {
            visible: modernStyle
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: statusPill.top
            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.3
            radius: ScreenTools.defaultFontPixelHeight * 0.14
            color: Qt.rgba(0.02, 0.03, 0.04, 0.18)
        }

        Image {
            id: aircraftImage
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: modernStyle ? statusPill.top : parent.bottom
            anchors.margins: modernStyle ? ScreenTools.defaultFontPixelHeight * 0.34 : 0
            source:     control.imageSource
            fillMode:   Image.PreserveAspectFit
            smooth: true
            visible: !modernStyle
        }

        Image {
            id: modernAircraftSource
            anchors.fill: aircraftImage
            source: control.imageSource
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: false
        }

        MultiEffect {
            anchors.fill: modernAircraftSource
            source: modernAircraftSource
            visible: control.modernStyle
            saturation: -0.72
            brightness: -0.16
            contrast: 0.28
            colorization: 0.34
            colorizationColor: control._modelTintColor
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.56)
            shadowBlur: 0.85
            shadowScale: 1.02
            shadowVerticalOffset: ScreenTools.defaultFontPixelHeight * 0.25
        }

        QGCColoredImage {
            anchors.fill: modernAircraftSource
            source: control.imageSource
            fillMode: Image.PreserveAspectFit
            color: control._modelTintColor
            opacity: control.modernStyle ? 0.18 : 0
        }

        Rectangle {
            id: statusPill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: modernStyle ? ScreenTools.defaultFontPixelHeight * 0.25 : 0
            width: modernStyle ? Math.min(parent.width - (ScreenTools.defaultFontPixelWidth * 2), statusLabel.implicitWidth + (ScreenTools.defaultFontPixelWidth * 2)) : parent.width
            height: modernStyle ? ScreenTools.defaultFontPixelHeight * 1.25 : parent.height
            radius: modernStyle ? height / 2 : 0
            color: modernStyle ? Qt.rgba(control._statusColor.r, control._statusColor.g, control._statusColor.b, 0.18) : "transparent"
            border.width: modernStyle ? 1 : 0
            border.color: modernStyle ? Qt.rgba(control._statusColor.r, control._statusColor.g, control._statusColor.b, 0.55) : "transparent"

            QGCLabel {
                id: statusLabel
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: modernStyle ? Text.AlignVCenter : Text.AlignBottom
                font.pointSize: modernStyle ? ScreenTools.defaultFontPointSize * 0.92 : ScreenTools.mediumFontPointSize
                font.weight: modernStyle ? Font.DemiBold : Font.Normal
                color: modernStyle ? "#F8FAFC" : qgcPal.text
                text: control._statusText
            }
        }
    }
}
