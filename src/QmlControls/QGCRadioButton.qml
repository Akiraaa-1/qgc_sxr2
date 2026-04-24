import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

RadioButton {
    id:             control
    font.family:    ScreenTools.normalFontFamily
    font.pointSize: ScreenTools.defaultFontPointSize

    property color  textColor:  qgcPal.text
    property color  indicatorBackgroundColor: control.enabled ? "white" : "transparent"
    property color  indicatorBorderColor: qgcPal.buttonBorder
    property color  indicatorHoverColor: qgcPal.buttonHighlight
    property color  indicatorDotColor: qgcPal.buttonHighlight
    property int stateAnimationDuration: 200
    property bool   _noText:    text === ""
    readonly property bool _popupStyled: popupStyle.inPopupContext(control)

    QGCPalette { id:qgcPal; colorGroupEnabled: enabled }
    QGCPopupStyle { id: popupStyle }

    indicator: Rectangle {
        implicitWidth:          ScreenTools.radioButtonIndicatorSize
        implicitHeight:         width
        color:                  control._popupStyled ? popupStyle.inputBackground : control.indicatorBackgroundColor
        border.color:           control._popupStyled ? (control.checked ? popupStyle.accentColor : popupStyle.borderColor) : control.indicatorBorderColor
        border.width:           1
        radius:                 height / 2
        x:                      control.leftPadding
        y:                      parent.height / 2 - height / 2
        Behavior on color { ColorAnimation { duration: control.stateAnimationDuration } }
        Behavior on border.color { ColorAnimation { duration: control.stateAnimationDuration } }

        Rectangle {
            anchors.fill:   parent
            color:          control._popupStyled ? popupStyle.hoverColor(popupStyle.inputBackground) : control.indicatorHoverColor
            opacity:        control.hovered ? .2 : 0
            radius:         parent.radius
            Behavior on opacity { NumberAnimation { duration: control.stateAnimationDuration } }
        }

        Rectangle {
            anchors.centerIn:   parent
            // Width should be an odd number to be centralized by the parent properly
            width:              2 * Math.floor(parent.width / 4) + 1
            height:             width
            antialiasing:       true
            radius:             height * 0.5
            color:              control._popupStyled ? popupStyle.accentColor : control.indicatorDotColor
            visible:            control.checked
        }
    }

    contentItem: Text {
        text:               control.text
        font.family:        control.font.pointSize
        font.pointSize:     control.font.pointSize
        font.bold:          control.font.bold
        color:              control._popupStyled
            ? (control.enabled ? popupStyle.primaryTextColor : popupStyle.disabledTextColor)
            : control.textColor
        verticalAlignment:  Text.AlignVCenter
        leftPadding:        control.indicator.width + (_noText ? 0 : ScreenTools.defaultFontPixelWidth * 0.25)
    }

}
