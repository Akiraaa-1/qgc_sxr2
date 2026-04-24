import QtQuick
import QtQuick.Controls
import QtQuick.Effects

import QGroundControl.Controls

Menu {
    id: control
    property bool _qgcPopupChrome: true
    margins: 6
    topPadding: 4
    bottomPadding: 4
    leftPadding: 4
    rightPadding: 4

    QGCPopupStyle { id: popupStyle }

    background: Item {
        implicitWidth: Math.max(control.contentItem ? control.contentItem.implicitWidth : 0, ScreenTools.implicitButtonWidth)
        implicitHeight: Math.max(control.contentItem ? control.contentItem.implicitHeight : 0, ScreenTools.implicitButtonHeight)

        Rectangle {
            id:         menuShadowSource
            anchors.fill: parent
            radius:     popupStyle.cornerRadius
            color:      popupStyle.popupBackground
            visible:    false
        }

        MultiEffect {
            anchors.fill: parent
            source: menuShadowSource
            shadowEnabled: true
            shadowColor: "#80000000"
            shadowBlur: 0.8
            shadowScale: 1.0
            shadowVerticalOffset: 4
        }

        Rectangle {
            anchors.fill: parent
            radius: popupStyle.cornerRadius
            color: popupStyle.popupBackground
            border.width: 1
            border.color: popupStyle.borderColor
        }
    }
}
