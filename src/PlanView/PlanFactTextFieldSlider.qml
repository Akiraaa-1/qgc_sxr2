import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.PlanView

FactTextFieldSlider {
    PlanEditorTheme { id: theme }

    property real uiScale: 1.0

    backgroundColor: theme.panelColor
    controlRadius: theme.radius
    labelPointSize: ScreenTools.defaultFontPointSize * uiScale
    textFieldPointSize: ScreenTools.defaultFontPointSize * uiScale
    checkBoxPointSize: ScreenTools.defaultFontPointSize * uiScale
    sliderLabelPointSize: ScreenTools.smallFontPointSize * uiScale
    sliderBarHeight: Math.max(3, ScreenTools.defaultFontPixelHeight * uiScale / 3)
    sliderHandleDiameter: ScreenTools.defaultFontPixelHeight * uiScale
    sliderReserveBoundaryLabelSpace: true
    sliderBoundaryLabelGap: ScreenTools.defaultFontPixelHeight * 0.18 * uiScale
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
