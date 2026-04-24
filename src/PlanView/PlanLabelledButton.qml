import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.PlanView

LabelledButton {
    PlanEditorTheme { id: theme }

    labelControl.color: theme.secondaryTextColor
    buttonControl.backRadius: theme.radius
    buttonControl.showBorder: true
    buttonControl.borderColor: theme.borderColor
    buttonControl.backgroundColor: buttonControl.pressed ? theme.panelPressedColor : (buttonControl.hovered ? theme.panelHoverColor : theme.borderColor)
    buttonControl.textColor: theme.textColor
    buttonControl.overlayColor: "transparent"
    buttonControl.hoverOverlayOpacity: 0
    buttonControl.pressedOverlayOpacity: 0
}
