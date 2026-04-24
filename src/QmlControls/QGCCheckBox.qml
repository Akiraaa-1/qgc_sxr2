import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

CheckBox {
    id:             control
    spacing:        _noText ? 0 : ScreenTools.defaultFontPixelWidth
    focusPolicy:    Qt.ClickFocus
    leftPadding:    0

    Component.onCompleted: {
        if (_noText) {
            rightPadding = 0
        }
    }

    property color  textColor:          qgcPal.buttonText
    property color  boxBackgroundColor: control.enabled ? "white" : "transparent"
    property color  boxBorderColor:     qgcPal.buttonBorder
    property color  checkColor:         qgcPal.buttonHighlight
    property color  hoverColor:         qgcPal.buttonHighlight
    property bool   textBold:           false
    property real   textFontPointSize:  ScreenTools.defaultFontPointSize
    property ButtonGroup buttonGroup: null
    property int stateAnimationDuration: 200

    property bool _noText: text === ""
    readonly property bool _popupStyled: popupStyle.inPopupContext(control)

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }
    QGCPopupStyle { id: popupStyle }

    onButtonGroupChanged: {
        if (buttonGroup) {
            buttonGroup.addButton(control)
        }
    }

    contentItem: Text {
        //implicitWidth:  _noText ? 0 : text.implicitWidth + ScreenTools.defaultFontPixelWidth * 0.25
        //implicitHeight: _noText ? 0 : Math.max(text.implicitHeight, ScreenTools.checkBoxIndicatorSize)
        leftPadding:        control.indicator.width + control.spacing
        verticalAlignment:  Text.AlignVCenter
        text:               control.text
        font.pointSize:     textFontPointSize
        font.bold:          control.textBold
        font.family:        ScreenTools.normalFontFamily
        color:              control._popupStyled
            ? (control.enabled ? popupStyle.primaryTextColor : popupStyle.disabledTextColor)
            : control.textColor
    }

    indicator:  Rectangle {
        implicitWidth:  ScreenTools.implicitCheckBoxHeight
        implicitHeight: implicitWidth
        x:              control.leftPadding
        y:              parent.height / 2 - height / 2
        color:          control._popupStyled ? popupStyle.inputBackground : control.boxBackgroundColor
        border.color:   control._popupStyled ? (control.checked ? popupStyle.accentColor : popupStyle.borderColor) : control.boxBorderColor
        border.width:   1
        radius:         control._popupStyled ? popupStyle.cornerRadius : ScreenTools.defaultBorderRadius
        opacity:        control.checkedState === Qt.PartiallyChecked ? 0.5 : 1
        Behavior on color { ColorAnimation { duration: control.stateAnimationDuration } }
        Behavior on border.color { ColorAnimation { duration: control.stateAnimationDuration } }

        Rectangle {
            anchors.fill:   parent
            color:          control._popupStyled ? popupStyle.hoverColor(popupStyle.inputBackground) : control.hoverColor
            opacity:        control.hovered ? .2 : 0
            radius:         parent.radius
            Behavior on opacity { NumberAnimation { duration: control.stateAnimationDuration } }
        }

        QGCColoredImage {
            source:             "/qmlimages/checkbox-check.svg"
            color:              control._popupStyled ? popupStyle.accentColor : control.checkColor
            mipmap:             true
            fillMode:           Image.PreserveAspectFit
            width:              parent.implicitWidth * 0.75
            height:             width
            sourceSize.height:  height
            visible:            control.checked
            anchors.centerIn:   parent
        }
    }
}
