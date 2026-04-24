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

    QGCLabel {
        id: label
        Layout.fillWidth: true
        Layout.minimumWidth: root.labelColumnMinWidth
        text: root.labelText
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
        text: root.valueText
        color: root.valueColor !== "" ? root.valueColor : root.defaultValueColor
        elide: Text.ElideNone
        clip: true
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        font.pointSize: root.valuePointSize
    }
}
