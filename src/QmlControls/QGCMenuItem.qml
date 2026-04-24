import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

MenuItem {
    id: control
    // MenuItem doesn't support !visible so we have to hack it in
    height: visible ? implicitHeight : 0
    padding: ScreenTools.defaultFontPixelWidth
    topPadding: Math.round(ScreenTools.defaultFontPixelHeight / 2)
    bottomPadding: topPadding
    leftPadding: ScreenTools.defaultFontPixelWidth * 1.25
    rightPadding: leftPadding

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }
    QGCPopupStyle { id: popupStyle }

    contentItem: QGCLabel {
        text: control.text
        color: control.enabled ? popupStyle.primaryTextColor : popupStyle.disabledTextColor
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: popupStyle.cornerRadius
        color: control.down
            ? popupStyle.pressedColor(popupStyle.panelBackground)
            : ((control.hovered || control.highlighted) ? popupStyle.hoverColor(popupStyle.panelBackground) : "transparent")

        Behavior on color { ColorAnimation { duration: popupStyle.stateAnimationDuration } }
    }
}
