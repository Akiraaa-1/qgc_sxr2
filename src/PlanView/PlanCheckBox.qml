import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.PlanView

QGCCheckBox {
    PlanEditorTheme { id: theme }

    textColor: theme.secondaryTextColor
    boxBackgroundColor: theme.inputColor
    boxBorderColor: activeFocus ? theme.accentColor : theme.borderColor
    checkColor: theme.accentColor
    hoverColor: theme.accentColor
}
