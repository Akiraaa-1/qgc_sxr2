import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

RowLayout {
    property string label:                   fact ? fact.shortDescription : ""
    property alias  fact:                    _factTextField.fact
    property real   textFieldPreferredWidth: -1
    property alias  textFieldUnitsLabel:     _factTextField.unitsLabel
    property alias  textFieldShowUnits:      _factTextField.showUnits
    property alias  textFieldShowHelp:       _factTextField.showHelp
    property alias  textField:               _factTextField
    property color  labelColor:              qgcPal.text
    property real   labelPointSize:          ScreenTools.defaultFontPointSize
    property color  textFieldBackgroundColor: qgcPal.textField
    property color  textFieldBorderColor:     qgcPal.buttonBorder
    property color  textFieldFocusBorderColor: textFieldBorderColor
    property color  textFieldColor:          qgcPal.textFieldText
    property bool   textFieldShowFocusGlow:  false

    spacing: ScreenTools.defaultFontPixelWidth * 2
    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    QGCLabel {
        Layout.fillWidth:    true
        Layout.minimumWidth: implicitWidth
        text:                label
        visible:             label !== ""
        color:               labelColor
        font.pointSize:      labelPointSize
    }

    FactTextField {
        id:                     _factTextField
        Layout.preferredWidth:  textFieldPreferredWidth
        backgroundColor:        textFieldBackgroundColor
        borderColor:            textFieldBorderColor
        focusBorderColor:       textFieldFocusBorderColor
        textColor:              textFieldColor
        showFocusGlow:          textFieldShowFocusGlow
    }
}
