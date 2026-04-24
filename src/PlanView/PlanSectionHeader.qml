import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.PlanView

CheckBox {
    id: control

    focusPolicy: Qt.ClickFocus
    checked: true
    leftPadding: 0

    property bool showSpacer: true
    property ButtonGroup buttonGroup: null
    property real sectionSpacing: ScreenTools.defaultFontPixelHeight * 0.45

    PlanEditorTheme { id: theme }

    onButtonGroupChanged: {
        if (buttonGroup) {
            buttonGroup.addButton(control)
        }
    }

    indicator: Item {}

    contentItem: ColumnLayout {
        spacing: ScreenTools.defaultFontPixelHeight * 0.28

        Item {
            Layout.preferredHeight: control.sectionSpacing
            visible: control.showSpacer
        }

        Rectangle {
            Layout.fillWidth: true
            radius: theme.radius
            border.width: 1
            border.color: control.checked ? theme.accentColor : theme.borderColor
            color: control.down ? theme.panelPressedColor : (control.hovered ? theme.panelHoverColor : theme.panelColor)
            implicitHeight: Math.round(ScreenTools.defaultFontPixelHeight * 2.3)

            Behavior on color { ColorAnimation { duration: theme.stateAnimationDuration } }
            Behavior on border.color { ColorAnimation { duration: theme.stateAnimationDuration } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth
                spacing: ScreenTools.defaultFontPixelWidth * 0.75

                QGCLabel {
                    Layout.fillWidth: true
                    text: control.text
                    color: control.enabled ? theme.textColor : theme.disabledTextColor
                    font.pointSize: ScreenTools.defaultFontPointSize * 1.02
                    font.bold: true
                    elide: Text.ElideRight
                }

                QGCColoredImage {
                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.75
                    Layout.preferredHeight: Layout.preferredWidth
                    source: "/qmlimages/arrow-down.png"
                    color: control.checked ? theme.textColor : theme.secondaryTextColor
                    rotation: control.checked ? 0 : -90
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.borderColor
            visible: control.checked
        }
    }
}
