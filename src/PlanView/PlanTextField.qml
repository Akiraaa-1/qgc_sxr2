import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.PlanView

QGCTextField {
    PlanEditorTheme { id: theme }

    backgroundColor: theme.inputColor
    borderColor: theme.borderColor
    focusBorderColor: theme.accentColor
    focusGlowColor: theme.accentColor
    textColor: theme.textColor
    borderRadius: theme.radius
    borderWidth: 1
    focusBorderWidth: 1
    showFocusGlow: true
}
