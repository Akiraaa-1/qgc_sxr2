import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.PlanView

QGCRadioButton {
    PlanEditorTheme { id: theme }

    textColor: theme.secondaryTextColor
    indicatorBackgroundColor: theme.inputColor
    indicatorBorderColor: activeFocus ? theme.accentColor : theme.borderColor
    indicatorHoverColor: theme.accentColor
    indicatorDotColor: theme.accentColor
}
