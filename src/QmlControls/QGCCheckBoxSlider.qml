import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

AbstractButton   {
    id:         control
    checkable:  true
    padding:    0

    property bool _showBorder:      qgcPal.globalTheme === QGCPalette.Light
    property int  _sliderInset:     2
    property bool _showHighlight:   enabled && (pressed || checked)
    property color textColor:       qgcPal.text
    property color trackColor:      qgcPal.button
    property color trackOnColor:    qgcPal.buttonHighlight
    property color trackBorderColor: qgcPal.buttonBorder
    property color handleColor:     qgcPal.buttonText
    property real sliderRadius:     ScreenTools.defaultFontPixelHeight / 2
    property int stateAnimationDuration: 200

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    contentItem: Item {
        implicitWidth:  (label.visible ? label.contentWidth + ScreenTools.defaultFontPixelWidth : 0) + indicator.width
        implicitHeight: label.contentHeight

        QGCLabel {
            id:             label
            anchors.left:   parent.left
            text:           visible ? control.text : "X"
            visible:        control.text !== ""
            color:          control.textColor
        }

        Rectangle {
            id:                     indicator
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter
            height:                 ScreenTools.defaultFontPixelHeight
            width:                  height * 2
            radius:                 control.sliderRadius
            color:                  checked ? control.trackOnColor : control.trackColor
            border.width:           _showBorder ? 1 : 0
            border.color:           control.trackBorderColor

            Behavior on color { ColorAnimation { duration: control.stateAnimationDuration } }
            Behavior on border.color { ColorAnimation { duration: control.stateAnimationDuration } }

            Rectangle {
                anchors.fill:   parent
                color:          control.trackOnColor
                opacity:        _showHighlight ? 1 : control.enabled && control.hovered ? .2 : 0
                radius:         parent.radius
                Behavior on opacity { NumberAnimation { duration: control.stateAnimationDuration } }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x:                      checked ? indicator.width - width - _sliderInset : _sliderInset
                height:                 parent.height - (_sliderInset * 2)
                width:                  height
                radius:                 height / 2
                color:                  control.handleColor
                Behavior on x { NumberAnimation { duration: control.stateAnimationDuration } }
            }
        }
    }
}
