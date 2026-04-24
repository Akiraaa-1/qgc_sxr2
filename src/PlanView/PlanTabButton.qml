import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.PlanView

QGCTabButton {
    PlanEditorTheme { id: theme }

    showBorder: true
    backRadius: theme.radius
    buttonColor: theme.panelColor
    hoverButtonColor: theme.panelHoverColor
    checkedButtonColor: theme.accentColor
    buttonBorderColor: theme.borderColor
    buttonTextColor: theme.secondaryTextColor
    checkedButtonTextColor: theme.textColor
    separatorColor: theme.borderColor
}
