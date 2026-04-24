import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

RowLayout {
    property alias label:                   label.text
    property alias fact:                    _comboBox.fact
    property alias indexModel:              _comboBox.indexModel
    property var   comboBox:                _comboBox
    property real  comboBoxPreferredWidth:  -1
    property color labelColor:              qgcPal.text
    property real  labelPointSize:          ScreenTools.defaultFontPointSize
    property color comboBoxBackgroundColor: qgcPal.button
    property color comboBoxBorderColor:     qgcPal.buttonBorder
    property color comboBoxFocusBorderColor: comboBoxBorderColor
    property color comboBoxTextColor:       qgcPal.buttonText
    property color comboBoxPopupBackgroundColor: qgcPal.window
    property color comboBoxPopupBorderColor: qgcPal.text
    property color comboBoxSelectedColor:   qgcPal.buttonHighlight
    property color comboBoxSelectedTextColor: qgcPal.buttonHighlightText
    property real  comboBoxRadius:          ScreenTools.defaultBorderRadius
    property bool  comboBoxShowFocusBorder: false

    spacing: ScreenTools.defaultFontPixelWidth * 2
    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    signal activated(int index)

    QGCLabel {
        id:                 label
        Layout.fillWidth:   true
        Layout.minimumWidth: implicitWidth
        color:              labelColor
        font.pointSize:     labelPointSize
    }

    FactComboBox {
        id:                     _comboBox
        Layout.preferredWidth:  comboBoxPreferredWidth
        sizeToContents:         true
        backgroundColor:        comboBoxBackgroundColor
        borderColor:            comboBoxBorderColor
        focusBorderColor:       comboBoxFocusBorderColor
        textColor:              comboBoxTextColor
        popupBackgroundColor:   comboBoxPopupBackgroundColor
        popupBorderColor:       comboBoxPopupBorderColor
        delegateSelectedBackgroundColor: comboBoxSelectedColor
        delegateSelectedTextColor: comboBoxSelectedTextColor
        borderRadius:           comboBoxRadius
        showFocusBorder:        comboBoxShowFocusBorder

        onActivated: (index) => { parent.activated(index) }
    }
}
