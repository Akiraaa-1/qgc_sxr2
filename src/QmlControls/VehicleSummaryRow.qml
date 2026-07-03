import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

RowLayout {
    id: root
    Layout.fillWidth: true
    spacing: ScreenTools.defaultFontPixelWidth * 2.4

    property string labelText: "Label"
    property string valueText: "value"
    property string valueColor: ""
    property color  labelColor: "#B0B0B0"
    property color  defaultValueColor: "#FFFFFF"
    property real   labelPointSize: ScreenTools.defaultFontPointSize * 0.94
    property real   valuePointSize: ScreenTools.defaultFontPointSize * 1.02
    property real labelColumnMinWidth: ScreenTools.defaultFontPixelWidth * 10
    property real valueColumnMinWidth: ScreenTools.defaultFontPixelWidth * 10
    property real valueColumnMaxWidth: ScreenTools.defaultFontPixelWidth * 30
    readonly property real _valueColumnWidthCap: Math.min(valueColumnMaxWidth, width * 0.40)

    function _displayText(text) {
        if (text === undefined || text === null) {
            return ""
        }

        const value = text.toString()
        switch (value) {
        case "Joystick":                    return qsTr("Joystick")
        case "No joystick detected":        return qsTr("No joystick detected")
        case "Buttons only":                return qsTr("Buttons only")
        case "Ready":                       return qsTr("Ready")
        case "Calibrated":                  return qsTr("Calibrated")
        case "Needs calibration":           return qsTr("Needs calibration")
        case "Gamepad":                     return qsTr("Gamepad")
        case "Unavailable":                 return qsTr("Unavailable")
        case "Setup required":              return qsTr("Setup required")
        case "Configured":                  return qsTr("Configured")
        case "Multirotor":                  return qsTr("Multirotor")
        case "Quadrotor":                   return qsTr("Quadrotor")
        case "Quadcopter":                  return qsTr("Quadcopter")
        case "Power Module":                return qsTr("Power Module")
        case "External":                    return qsTr("External")
        case "ESCs":                        return qsTr("ESCs")
        case "Warning":                     return qsTr("Warning")
        case "Hold mode":                   return qsTr("Hold mode")
        case "Disabled":                    return qsTr("Disabled")
        case "Land immediately":            return qsTr("Land immediately")
        case "Loiter and do not land":      return qsTr("Loiter and do not land")
        case "Loiter and land after specified time": return qsTr("Loiter and land after specified time")
        case "Position":                    return qsTr("Position")
        case "Mission":                     return qsTr("Mission")
        case "Stabilized":                  return qsTr("Stabilized")
        case "Unassigned":                  return qsTr("Unassigned")
        }

        if (value.indexOf("Quadrotor ") === 0) {
            return qsTr("Quadrotor %1").arg(value.substring("Quadrotor ".length))
        }
        if (value.indexOf("Channel ") === 0) {
            return qsTr("Channel %1").arg(value.substring("Channel ".length))
        }

        let match = value.match(/^(\d+)\s+groups?$/)
        if (match) {
            return qsTr("%1 groups").arg(match[1])
        }
        match = value.match(/^(\d+)\s+channels?$/)
        if (match) {
            return qsTr("%1 channels").arg(match[1])
        }
        match = value.match(/^(\d+)\s+axes$/)
        if (match) {
            return qsTr("%1 axes").arg(match[1])
        }
        match = value.match(/^(\d+)\s+buttons$/)
        if (match) {
            return qsTr("%1 buttons").arg(match[1])
        }

        return value
    }

    QGCLabel {
        id: label
        Layout.fillWidth: true
        Layout.minimumWidth: root.labelColumnMinWidth
        text: root._displayText(root.labelText)
        elide: Text.ElideNone
        clip: true
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        color: root.labelColor
        font.pointSize: root.labelPointSize
    }

    QGCLabel {
        Layout.preferredWidth: Math.max(root.valueColumnMinWidth, Math.min(implicitWidth, root._valueColumnWidthCap))
        Layout.maximumWidth: root.valueColumnMaxWidth
        Layout.alignment: Qt.AlignRight
        text: root._displayText(root.valueText)
        color: root.valueColor !== "" ? root.valueColor : root.defaultValueColor
        elide: Text.ElideNone
        clip: true
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        font.pointSize: root.valuePointSize
    }
}
