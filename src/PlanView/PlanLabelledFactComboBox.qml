import QtQuick

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.PlanView

LabelledFactComboBox {
    PlanEditorTheme { id: theme }

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
