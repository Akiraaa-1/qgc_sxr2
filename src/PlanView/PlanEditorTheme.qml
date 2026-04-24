import QtQuick

import QGroundControl.Controls

QtObject {
    readonly property QtObject popupStyle: QGCPopupStyle { }

    readonly property color windowTopColor: popupStyle.popupBackground
    readonly property color windowBottomColor: "#222222"
    readonly property color panelColor: popupStyle.panelBackground
    readonly property color panelHoverColor: popupStyle.hoverColor(panelColor)
    readonly property color panelPressedColor: popupStyle.pressedColor(panelColor)
    readonly property color inputColor: popupStyle.inputBackground
    readonly property color popupColor: popupStyle.popupBackground
    readonly property color borderColor: popupStyle.borderColor
    readonly property color accentColor: popupStyle.accentColor
    readonly property color accentHoverColor: popupStyle.primaryButtonHoverColor()
    readonly property color textColor: popupStyle.primaryTextColor
    readonly property color secondaryTextColor: popupStyle.secondaryTextColor
    readonly property color disabledTextColor: popupStyle.disabledTextColor
    readonly property color shadowColor: Qt.rgba(0, 0, 0, 0.22)
    readonly property real radius: popupStyle.cornerRadius
    readonly property int stateAnimationDuration: popupStyle.stateAnimationDuration
}
