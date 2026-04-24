import QtQuick

import QGroundControl
import QGroundControl.PlanView

Rectangle {
    id: control

    property bool elevated: false
    property bool hovered: false
    property bool pressed: false
    property color panelColor: theme.panelColor
    property color hoverColor: theme.panelHoverColor
    property color pressedColor: theme.panelPressedColor
    property color borderColor: theme.borderColor

    color: pressed ? pressedColor : (hovered ? hoverColor : panelColor)
    radius: theme.radius
    border.width: 1
    border.color: borderColor

    PlanEditorTheme { id: theme }

    Behavior on color { ColorAnimation { duration: theme.stateAnimationDuration } }
    Behavior on border.color { ColorAnimation { duration: theme.stateAnimationDuration } }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: parent.radius + 1
        color: theme.shadowColor
        opacity: control.elevated ? 1 : 0
        z: -1
    }
}
