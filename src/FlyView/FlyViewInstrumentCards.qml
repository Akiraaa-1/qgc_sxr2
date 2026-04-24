import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

Item {
    id: root
    implicitWidth: ScreenTools.defaultFontPixelWidth * 33
    implicitHeight: ScreenTools.defaultFontPixelHeight * 24
    clip: true

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var _activeBattery: root._activeBatteryForVehicle(vehicle)
    property var flightTimeFact: vehicle ? vehicle.getFact("flightTime") : null
    property var batteryFact: _activeBattery ? _activeBattery.percentRemaining : null
    property var altitudeFact: vehicle ? vehicle.altitudeRelative : null
    property var airSpeedFact: vehicle ? vehicle.airSpeed : null
    property var climbRateFact: vehicle ? vehicle.climbRate : null
    property real extraInset: 0
    property real extraValuesWidth: 0
    property bool showHeader: true
    property bool showHeaderAction: true
    property string headerTitle: qsTr("INSTRUMENTS")
    property real headerHeight: ScreenTools.defaultFontPixelHeight * 1.08
    property real headerSpacing: ScreenTools.defaultFontPixelWidth * 0.16
    property real headerTitleSize: ScreenTools.defaultFontPixelHeight * 0.66
    property color headerTitleColor: qgcPal.text
    property real headerActionSize: ScreenTools.defaultFontPixelHeight * 1.08
    property real headerActionRightMargin: ScreenTools.defaultFontPixelWidth * 0.06
    property real headerActionRadius: ScreenTools.defaultFontPixelHeight * 0.12
    property real headerActionIconScale: 0.46
    property color headerActionColor: "transparent"
    property color headerActionHoverColor: "transparent"
    property color headerActionPressedColor: "transparent"
    property color headerActionBorderColor: "transparent"
    property color headerActionIconColor: qgcPal.text
    property int headerTransitionDuration: 200
    property real panelLeftMargin: ScreenTools.defaultFontPixelHeight * 0.35
    property real panelRightMargin: ScreenTools.defaultFontPixelHeight * 0.35
    property real panelTopMargin: ScreenTools.defaultFontPixelHeight * 0.16
    property real panelBottomMargin: ScreenTools.defaultFontPixelHeight * 0.35
    readonly property bool hasTurnValue: vehicle && root._hasFactValue(vehicle.roll)
    readonly property real turnValue: hasTurnValue ? Number(vehicle.roll.rawValue) : 0
    readonly property real turnNeedleRotation: Math.max(-45, Math.min(45, turnValue))
    readonly property bool hasClimbRate: root._hasFactValue(climbRateFact)
    readonly property real climbRate: hasClimbRate ? Number(climbRateFact.rawValue) : 0
    readonly property real verticalNeedleRotation: Math.max(-120, Math.min(120, climbRate * 35))
    readonly property bool hasAirspeed: root._hasFactValue(airSpeedFact)
    readonly property real airSpeedValue: hasAirspeed ? Math.max(0, Number(airSpeedFact.rawValue)) : 0
    readonly property real airSpeedNeedleRotation: Math.max(-125, Math.min(125, (airSpeedValue / 20) * 250 - 125))
    readonly property color _cardColor: qgcPal.windowShadeDark
    readonly property color _cardBorderColor: qgcPal.windowShade
    readonly property color _textMutedColor: qgcPal.text
    readonly property real _rowSpacing: ScreenTools.defaultFontPixelHeight * 0.24
    readonly property real _columnSpacing: ScreenTools.defaultFontPixelWidth * 0.24
    readonly property real _dialCardHeight: ScreenTools.defaultFontPixelHeight * 8.3
    signal headerActionTriggered()

    function _hasFactValue(fact) { return fact && !isNaN(Number(fact.rawValue)) }
    function _activeBatteryForVehicle(vehicleObject) {
        if (!vehicleObject || !vehicleObject.batteries || vehicleObject.batteries.count === 0) { return null }
        return vehicleObject.batteries.get(0)
    }
    function _batteryPercentForVehicle(vehicleObject) {
        if (!vehicleObject || !vehicleObject.batteries || vehicleObject.batteries.count === 0) { return NaN }
        const battery = vehicleObject.batteries.get(0)
        return battery && root._hasFactValue(battery.percentRemaining) ? Number(battery.percentRemaining.rawValue) : NaN
    }
    function _formatFactValue(fact, includeUnits = true, unavailableText = "--") {
        if (!root._hasFactValue(fact)) { return unavailableText }
        const units = includeUnits && fact.units !== "" ? (" " + fact.units) : ""
        return fact.valueString + units
    }
    function _formatElapsedTime(fact) {
        if (!root._hasFactValue(fact)) { return "--:--" }
        const totalSeconds = Math.max(0, Math.round(Number(fact.rawValue)))
        const hours = Math.floor(totalSeconds / 3600)
        const minutes = Math.floor((totalSeconds % 3600) / 60)
        const seconds = totalSeconds % 60
        const minutesText = minutes < 10 ? ("0" + minutes) : ("" + minutes)
        const secondsText = seconds < 10 ? ("0" + seconds) : ("" + seconds)
        if (hours > 0) {
            const hoursText = hours < 10 ? ("0" + hours) : ("" + hours)
            return hoursText + ":" + minutesText + ":" + secondsText
        }
        return minutesText + ":" + secondsText
    }
    function _formatSignedValue(value, precision = 0, suffix = "") {
        if (isNaN(Number(value))) { return "--" }
        const numericValue = Number(value)
        const fixed = numericValue.toFixed(precision)
        const signed = numericValue > 0 ? ("+" + fixed) : fixed
        return signed + suffix
    }
    function _batteryColor() {
        if (!root._hasFactValue(root.batteryFact)) {
            return qgcPal.text
        }
        const percent = Number(root.batteryFact.rawValue)
        if (percent <= 20) { return qgcPal.colorRed }
        if (percent <= 40) { return qgcPal.colorOrange }
        return qgcPal.colorGreen
    }
    function _batteryIcon(percent) {
        if (isNaN(percent)) { return "/InstrumentValueIcons/battery-half.svg" }
        if (percent <= 25) { return "/InstrumentValueIcons/battery-low.svg" }
        if (percent <= 60) { return "/InstrumentValueIcons/battery-half.svg" }
        return "/InstrumentValueIcons/battery-full.svg"
    }

    QGCPalette {
        id: qgcPal
        colorGroupEnabled: true
    }

    Flickable {
        id: instrumentFlick
        anchors.fill: parent
        anchors.leftMargin: root.panelLeftMargin
        anchors.rightMargin: root.panelRightMargin
        anchors.bottomMargin: root.panelBottomMargin
        anchors.topMargin: root.panelTopMargin
        clip: true
        contentWidth: width
        contentHeight: contentLayout.implicitHeight
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: verticalScrollBar
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: contentLayout
            width: instrumentFlick.width - (verticalScrollBar.visible ? verticalScrollBar.width : 0)
            spacing: root._rowSpacing

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: root.showHeader ? root.headerHeight : 0
                spacing: root.headerSpacing
                visible: root.showHeader

                QGCLabel {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: root.headerTitle
                    color: root.headerTitleColor
                    font.weight: Font.DemiBold
                    font.pixelSize: root.headerTitleSize
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    Layout.preferredWidth: root.headerActionSize
                    Layout.preferredHeight: Layout.preferredWidth
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: root.headerActionRightMargin
                    visible: root.showHeaderAction
                    color: headerActionMouseArea.pressed
                        ? root.headerActionPressedColor
                        : (headerActionMouseArea.containsMouse ? root.headerActionHoverColor : root.headerActionColor)
                    radius: root.headerActionRadius
                    border.width: 1
                    border.color: root.headerActionBorderColor

                    Behavior on color {
                        ColorAnimation { duration: root.headerTransitionDuration }
                    }

                    QGCColoredImage {
                        anchors.centerIn: parent
                        width: parent.height * root.headerActionIconScale
                        height: width
                        color: root.headerActionIconColor
                        fillMode: Image.PreserveAspectFit
                        source: "/InstrumentValueIcons/cog.svg"
                    }

                    QGCMouseArea {
                        id: headerActionMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.headerActionTriggered()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                spacing: root._columnSpacing

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root._cardColor
                    border.color: root._cardBorderColor
                    border.width: 1
                    radius: ScreenTools.defaultFontPixelHeight * 0.12

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.24
                        spacing: ScreenTools.defaultFontPixelWidth * 0.22

                        QGCLabel {
                            Layout.fillWidth: true
                            color: root._textMutedColor
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.66
                            text: qsTr("Flight Time")
                        }

                        QGCLabel {
                            color: qgcPal.text
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.74
                            font.weight: Font.DemiBold
                            text: root._formatElapsedTime(root.flightTimeFact)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root._cardColor
                    border.color: root._cardBorderColor
                    border.width: 1
                    radius: ScreenTools.defaultFontPixelHeight * 0.12

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.24
                        spacing: ScreenTools.defaultFontPixelWidth * 0.18

                        QGCLabel {
                            Layout.fillWidth: true
                            color: root._textMutedColor
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.66
                            text: qsTr("Battery")
                        }

                        QGCColoredImage {
                            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.66
                            Layout.preferredHeight: Layout.preferredWidth
                            color: root._batteryColor()
                            fillMode: Image.PreserveAspectFit
                            source: root._batteryIcon(root._batteryPercentForVehicle(root.vehicle))
                        }

                        QGCLabel {
                            color: root._batteryColor()
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.74
                            font.weight: Font.DemiBold
                            text: root._formatFactValue(root.batteryFact, true, "--")
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                columns: 2
                columnSpacing: root._columnSpacing
                rowSpacing: root._rowSpacing

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root._dialCardHeight
                    Layout.minimumHeight: root._dialCardHeight
                    color: root._cardColor
                    border.color: root._cardBorderColor
                    border.width: 1
                    radius: ScreenTools.defaultFontPixelHeight * 0.12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.24
                    spacing: ScreenTools.defaultFontPixelHeight * 0.2

                    QGCLabel {
                        color: root._textMutedColor
                        text: qsTr("Attitude")
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.66
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        QGCAttitudeWidget {
                            anchors.centerIn: parent
                            size: Math.min(parent.width, parent.height) * 0.84
                            vehicle: root.vehicle
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root._dialCardHeight
                Layout.minimumHeight: root._dialCardHeight
                color: root._cardColor
                border.color: root._cardBorderColor
                border.width: 1
                radius: ScreenTools.defaultFontPixelHeight * 0.12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.24
                    spacing: ScreenTools.defaultFontPixelHeight * 0.2

                    QGCLabel {
                        color: root._textMutedColor
                        text: qsTr("Heading")
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.66
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        QGCCompassWidget {
                            anchors.centerIn: parent
                            size: Math.min(parent.width, parent.height) * 0.84
                            vehicle: root.vehicle
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root._dialCardHeight
                Layout.minimumHeight: root._dialCardHeight
                color: root._cardColor
                border.color: root._cardBorderColor
                border.width: 1
                radius: ScreenTools.defaultFontPixelHeight * 0.12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.24
                    spacing: ScreenTools.defaultFontPixelHeight * 0.2

                    QGCLabel {
                        color: root._textMutedColor
                        text: qsTr("Altitude")
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.66
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            id: altitudeDial
                            width: Math.min(parent.width, parent.height) * 0.86
                            height: width
                            radius: width / 2
                            color: Qt.rgba(0, 0, 0, 0)
                            border.color: qgcPal.text
                            border.width: 2
                            anchors.centerIn: parent
                        }

                        QGCLabel {
                            anchors.centerIn: altitudeDial
                            color: qgcPal.text
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.98
                            font.weight: Font.DemiBold
                            text: root._formatFactValue(root.altitudeFact, true, "--")
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root._dialCardHeight
                Layout.minimumHeight: root._dialCardHeight
                color: root._cardColor
                border.color: root._cardBorderColor
                border.width: 1
                radius: ScreenTools.defaultFontPixelHeight * 0.12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.24
                    spacing: ScreenTools.defaultFontPixelHeight * 0.2

                    QGCLabel {
                        color: root._textMutedColor
                        text: qsTr("Air Speed")
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.66
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            id: airSpeedDial
                            width: Math.min(parent.width, parent.height) * 0.86
                            height: width
                            radius: width / 2
                            color: Qt.rgba(0, 0, 0, 0)
                            border.color: qgcPal.text
                            border.width: 2
                            anchors.centerIn: parent
                        }

                        Canvas {
                            id: airSpeedArc
                            anchors.fill: airSpeedDial

                            onPaint: {
                                const ctx = getContext("2d")
                                const radius = width * 0.44
                                const cx = width * 0.5
                                const cy = height * 0.5
                                ctx.clearRect(0, 0, width, height)
                                ctx.lineWidth = Math.max(2, width * 0.035)
                                ctx.lineCap = "round"

                                const drawArc = (startDeg, endDeg, color) => {
                                    ctx.beginPath()
                                    ctx.strokeStyle = color
                                    ctx.arc(cx, cy, radius, (startDeg - 90) * Math.PI / 180, (endDeg - 90) * Math.PI / 180, false)
                                    ctx.stroke()
                                }

                                drawArc(210, 250, qgcPal.colorRed)
                                drawArc(250, 285, qgcPal.colorOrange)
                                drawArc(285, 355, qgcPal.colorGreen)
                            }

                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                        }

                        Rectangle {
                            width: airSpeedDial.width * 0.33
                            height: Math.max(2, ScreenTools.defaultFontPixelWidth / 3)
                            radius: height / 2
                            x: airSpeedDial.x + (airSpeedDial.width / 2)
                            y: airSpeedDial.y + ((airSpeedDial.height - height) / 2)
                            transformOrigin: Item.Left
                            rotation: root.airSpeedNeedleRotation
                            color: qgcPal.text
                        }

                        Rectangle {
                            width: ScreenTools.defaultFontPixelWidth
                            height: width
                            radius: width / 2
                            color: qgcPal.text
                            anchors.centerIn: airSpeedDial
                        }

                        QGCLabel {
                            anchors.centerIn: airSpeedDial
                            color: qgcPal.text
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.92
                            font.weight: Font.DemiBold
                            text: root._formatFactValue(root.airSpeedFact, true, "--")
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root._dialCardHeight
                Layout.minimumHeight: root._dialCardHeight
                color: root._cardColor
                border.color: root._cardBorderColor
                border.width: 1
                radius: ScreenTools.defaultFontPixelHeight * 0.12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.24
                    spacing: ScreenTools.defaultFontPixelHeight * 0.2

                    QGCLabel {
                        color: root._textMutedColor
                        text: qsTr("Turn Coordinator")
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.66
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            id: turnDial
                            width: Math.min(parent.width, parent.height) * 0.86
                            height: width
                            radius: width / 2
                            color: Qt.rgba(0, 0, 0, 0)
                            border.color: qgcPal.text
                            border.width: 2
                            anchors.centerIn: parent
                        }

                        Rectangle {
                            width: turnDial.width * 0.34
                            height: Math.max(2, ScreenTools.defaultFontPixelWidth / 3)
                            radius: height / 2
                            x: turnDial.x + (turnDial.width / 2)
                            y: turnDial.y + ((turnDial.height - height) / 2)
                            transformOrigin: Item.Left
                            rotation: root.turnNeedleRotation
                            color: qgcPal.text
                        }

                        Rectangle {
                            width: ScreenTools.defaultFontPixelWidth
                            height: width
                            radius: width / 2
                            color: qgcPal.text
                            anchors.centerIn: turnDial
                        }

                        QGCLabel {
                            anchors.horizontalCenter: turnDial.horizontalCenter
                            anchors.bottom: parent.bottom
                            color: qgcPal.text
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.84
                            font.weight: Font.DemiBold
                            text: root.hasTurnValue ? root._formatSignedValue(root.turnValue, 0, "\u00B0") : "--"
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root._dialCardHeight
                Layout.minimumHeight: root._dialCardHeight
                color: root._cardColor
                border.color: root._cardBorderColor
                border.width: 1
                radius: ScreenTools.defaultFontPixelHeight * 0.12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.24
                    spacing: ScreenTools.defaultFontPixelHeight * 0.2

                    QGCLabel {
                        color: root._textMutedColor
                        text: qsTr("Vertical Speed")
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.66
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            id: verticalSpeedDial
                            width: Math.min(parent.width, parent.height) * 0.86
                            height: width
                            radius: width / 2
                            color: Qt.rgba(0, 0, 0, 0)
                            border.color: qgcPal.text
                            border.width: 2
                            anchors.centerIn: parent
                        }

                        Rectangle {
                            width: verticalSpeedDial.width * 0.34
                            height: Math.max(2, ScreenTools.defaultFontPixelWidth / 3)
                            radius: height / 2
                            x: verticalSpeedDial.x + (verticalSpeedDial.width / 2)
                            y: verticalSpeedDial.y + ((verticalSpeedDial.height - height) / 2)
                            transformOrigin: Item.Left
                            rotation: root.verticalNeedleRotation
                            color: qgcPal.text
                        }

                        Rectangle {
                            width: ScreenTools.defaultFontPixelWidth
                            height: width
                            radius: width / 2
                            color: qgcPal.text
                            anchors.centerIn: verticalSpeedDial
                        }

                        QGCLabel {
                            anchors.centerIn: verticalSpeedDial
                            color: qgcPal.text
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.84
                            font.weight: Font.DemiBold
                            text: root._formatFactValue(root.climbRateFact, true, "--")
                        }
                    }
                }
            }
        }
    }
}
}
