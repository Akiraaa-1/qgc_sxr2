import QtQuick

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.PlanView

LabelledFactTextField {
    PlanEditorTheme { id: theme }

    labelColor: theme.secondaryTextColor
    textFieldBackgroundColor: theme.inputColor
    textFieldBorderColor: theme.borderColor
    textFieldFocusBorderColor: theme.accentColor
    textFieldColor: theme.textColor
    textFieldShowFocusGlow: true
}
