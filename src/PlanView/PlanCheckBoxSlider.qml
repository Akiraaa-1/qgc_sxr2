import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.PlanView

QGCCheckBoxSlider {
    PlanEditorTheme { id: theme }

    textColor: theme.secondaryTextColor
    trackColor: theme.inputColor
    trackOnColor: theme.accentColor
    trackBorderColor: theme.borderColor
    handleColor: theme.textColor
    sliderRadius: theme.radius
}
