import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.PlanView

QGCComboBox {
    PlanEditorTheme { id: theme }

    backgroundColor: hovered ? theme.panelHoverColor : theme.inputColor
    borderColor: theme.borderColor
    focusBorderColor: theme.accentColor
    textColor: theme.textColor
    popupBackgroundColor: theme.popupColor
    popupBorderColor: theme.borderColor
    delegateBackgroundColor: theme.popupColor
    delegateSelectedBackgroundColor: theme.accentColor
    delegateTextColor: theme.textColor
    delegateSelectedTextColor: theme.textColor
    borderRadius: theme.radius
    showFocusBorder: true
}
