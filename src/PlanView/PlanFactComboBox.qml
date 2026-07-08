import QtQuick

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.PlanView

FactComboBox {
    PlanEditorTheme { id: theme }

    property real uiScale: 1.0

    font.pointSize: ScreenTools.defaultFontPointSize * uiScale
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
