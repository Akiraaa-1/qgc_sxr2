import QtQuick

import QGroundControl
import QGroundControl.Controls

SettingsButton {
    id: control

    property bool setupComplete: true
    property color accentColor: "#2563EB"
    property color outlineColor: "#333333"
    property color hoverColor: "#343434"
    property color pressedColor: "#252525"
    property color checkedColor: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.28)
    property real cornerRadius: 8
    property int stateAnimationDuration: 200

    icon.color: setupComplete ? textColor : accentColor

    background: Rectangle {
        color: control.checked
            ? control.checkedColor
            : (control.pressed
                ? control.pressedColor
                : (control.enabled && control.hovered
                    ? control.hoverColor
                    : "transparent"))
        radius: control.cornerRadius
        border.width: control.checked ? 1 : 0
        border.color: control.checked ? control.accentColor : control.outlineColor

        Behavior on color { ColorAnimation { duration: control.stateAnimationDuration } }
        Behavior on border.color { ColorAnimation { duration: control.stateAnimationDuration } }
    }
}
