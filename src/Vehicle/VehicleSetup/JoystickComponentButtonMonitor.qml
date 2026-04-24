import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.VehicleSetup
import QGroundControl.FactControls

Flow {
    id: root
    spacing: ScreenTools.defaultFontPixelWidth

    property var _joystick: joystickManager.activeJoystick
    readonly property bool _popupStyled: popupStyle.inPopupContext(root)

    QGCPalette { id: qgcPal }
    QGCPopupStyle { id: popupStyle }

    Connections {
        target: _joystick

        onRawButtonPressedChanged: (index, pressed) => {
            if (buttonRepeater.itemAt(index)) {
                buttonRepeater.itemAt(index).pressed = pressed
            }
        }
    }

    Repeater {
        id: buttonRepeater
        model: _joystick.buttonCount

        Rectangle {
            implicitWidth: ScreenTools.defaultFontPixelHeight * 1.5
            implicitHeight: width
            border.width: 1
            border.color: root._popupStyled ? popupStyle.borderColor : qgcPal.text
            color: root._popupStyled
                ? (pressed ? popupStyle.accentColor : popupStyle.inputBackground)
                : (pressed ? qgcPal.buttonHighlight : qgcPal.button)
            radius: root._popupStyled ? popupStyle.cornerRadius : ScreenTools.defaultBorderRadius

            property bool pressed

            QGCLabel {
                anchors.fill: parent
                color: root._popupStyled
                    ? popupStyle.primaryTextColor
                    : (pressed ? qgcPal.buttonHighlightText : qgcPal.buttonText)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
            }
        }
    }
}
