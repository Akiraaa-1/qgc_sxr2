import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

ColumnLayout {
    id: control
    spacing: ScreenTools.defaultFontPixelHeight * 0.42

    default property alias contentItem: _controlsColumn.data

    property string heading
    property string iconSource

    property real _margins: ScreenTools.defaultFontPixelHeight * 0.75
    property real cornerRadius: ScreenTools.defaultFontPixelHeight * 0.66
    property color panelBackgroundColor: "#2D2D2D"
    property color panelBorderColor: "#333333"
    property color dividerColor: "#333333"
    property color headingColor: "#FFFFFF"
    property color subtleTextColor: "#B0B0B0"
    property color iconChipColor: "#3A3A3A"
    property color iconColor: "#FFFFFF"
    property color shadowColor: Qt.rgba(0, 0, 0, 0.22)
    readonly property int _animDuration: 200

    Rectangle {
        id: cardBackground
        Layout.fillWidth: true
        implicitWidth: Math.max(_headerRow.implicitWidth, _controlsColumn.implicitWidth) + (_margins * 2)
        implicitHeight: _contentColumn.implicitHeight + (_margins * 2)
        radius: cornerRadius
        border.width: 1
        border.color: panelBorderColor
        color: panelBackgroundColor

        Behavior on color { ColorAnimation { duration: control._animDuration } }
        Behavior on border.color { ColorAnimation { duration: control._animDuration } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: shadowColor
            z: -1
        }

        ColumnLayout {
            id: _contentColumn
            anchors.fill: parent
            anchors.margins: _margins
            spacing: ScreenTools.defaultFontPixelHeight * 0.58

            RowLayout {
                id: _headerRow
                Layout.fillWidth: true
                visible: control.heading !== "" || control.iconSource !== ""
                spacing: ScreenTools.defaultFontPixelWidth * 0.65

                Rectangle {
                    visible: control.iconSource !== ""
                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.55
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: ScreenTools.defaultFontPixelHeight * 0.5
                    color: control.iconChipColor
                    border.width: 1
                    border.color: control.panelBorderColor

                    QGCColoredImage {
                        anchors.centerIn: parent
                        width: parent.width * 0.62
                        height: width
                        source: control.iconSource
                        color: control.iconColor
                        fillMode: Image.PreserveAspectFit
                    }
                }

                QGCLabel {
                    Layout.fillWidth: true
                    text: control.heading
                    font.pointSize: ScreenTools.defaultFontPointSize * 1.12
                    font.bold: true
                    color: control.headingColor
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideNone
                    horizontalAlignment: Text.AlignLeft
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                visible: control.heading !== "" || control.iconSource !== ""
                color: control.dividerColor
            }

            ColumnLayout {
                id: _controlsColumn
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelHeight * 0.5
            }
        }
    }
}
