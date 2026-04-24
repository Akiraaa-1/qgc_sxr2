import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

GroupBox {
    id: control
    readonly property bool _popupStyled: popupStyle.inPopupContext(control)

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }
    QGCPopupStyle { id: popupStyle }

    background: Rectangle {
        y:      control.topPadding - control.padding
        width:  parent.width
        height: parent.height - control.topPadding + control.padding
        color:  control._popupStyled ? popupStyle.panelBackground : qgcPal.windowShade
        radius: control._popupStyled ? popupStyle.cornerRadius : 0
        border.width: control._popupStyled ? 1 : 0
        border.color: popupStyle.borderColor
    }

    label: QGCLabel {
        width:  control.availableWidth
        text:   control.title
        font.bold: true
    }
}
