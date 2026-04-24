import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Text {
    id: label
    font.pointSize: ScreenTools.defaultFontPointSize
    font.family:    ScreenTools.normalFontFamily
    color:          popupStyle.inPopupContext(label)
                        ? (label.enabled ? popupStyle.primaryTextColor : popupStyle.disabledTextColor)
                        : qgcPal.text
    antialiasing:   true

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }
    QGCPopupStyle { id: popupStyle }
}
