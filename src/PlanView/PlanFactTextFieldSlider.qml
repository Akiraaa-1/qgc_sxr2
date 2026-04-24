import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.PlanView

FactTextFieldSlider {
    PlanEditorTheme { id: theme }

    backgroundColor: theme.panelColor
    controlRadius: theme.radius
    labelColor: theme.secondaryTextColor
    textFieldBackgroundColor: theme.inputColor
    textFieldBorderColor: theme.borderColor
    textFieldFocusBorderColor: theme.accentColor
    textFieldColor: theme.textColor
    textFieldShowFocusGlow: true
    checkBoxTextColor: theme.secondaryTextColor
    checkBoxBoxColor: theme.inputColor
    checkBoxBorderColor: theme.borderColor
    checkBoxCheckColor: theme.accentColor
    checkBoxHoverColor: theme.accentColor
    sliderTrackColor: theme.inputColor
    sliderTrackBorderColor: theme.borderColor
    sliderHandleColor: theme.textColor
    sliderHandleBorderColor: theme.borderColor
    sliderLabelColor: theme.secondaryTextColor
}
