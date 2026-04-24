import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.PlanView

QGCButton {
    id: control

    property bool secondary: !primary

    PlanEditorTheme { id: theme }

    backRadius: theme.radius
    showBorder: true
    borderColor: primary ? theme.accentColor : theme.borderColor
    textColor: theme.textColor
    overlayColor: "transparent"
    hoverOverlayOpacity: 0
    pressedOverlayOpacity: 0
    stateAnimationDuration: theme.stateAnimationDuration
    backgroundColor: primary
        ? (pressed ? theme.accentHoverColor : (hovered ? theme.accentHoverColor : theme.accentColor))
        : (pressed ? theme.panelPressedColor : (hovered ? theme.panelHoverColor : theme.borderColor))
}
