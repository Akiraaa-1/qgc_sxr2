import QtQuick

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.PlanView

LabelledFactComboBox {
    PlanEditorTheme { id: theme }

    property real uiScale: 1.0

    labelPointSize: ScreenTools.defaultFontPointSize * uiScale
    comboBox.font.pointSize: ScreenTools.defaultFontPointSize * uiScale
    labelColor: theme.secondaryTextColor
    comboBoxBackgroundColor: theme.inputColor
    comboBoxBorderColor: theme.borderColor
    comboBoxFocusBorderColor: theme.accentColor
    comboBoxTextColor: theme.textColor
    comboBoxPopupBackgroundColor: theme.popupColor
    comboBoxPopupBorderColor: theme.borderColor
    comboBoxSelectedColor: theme.accentColor
    comboBoxSelectedTextColor: theme.textColor
    comboBoxRadius: theme.radius
    comboBoxShowFocusBorder: true
}
