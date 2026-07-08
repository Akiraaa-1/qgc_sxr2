import QtQuick

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.PlanView

LabelledFactTextField {
    PlanEditorTheme { id: theme }

    property real uiScale: 1.0

    labelPointSize: ScreenTools.defaultFontPointSize * uiScale
    textField.font.pointSize: ScreenTools.defaultFontPointSize * uiScale
    labelColor: theme.secondaryTextColor
    textFieldBackgroundColor: theme.inputColor
    textFieldBorderColor: theme.borderColor
    textFieldFocusBorderColor: theme.accentColor
    textFieldColor: theme.textColor
    textFieldShowFocusGlow: true
}
