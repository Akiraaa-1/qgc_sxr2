import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import QGroundControl
import QGroundControl.Controls

/// Drop panel that displays positioned next to the specified click position.
/// By default the panel drops to the right of the click position. If there isn't
/// enough room to the right then the panel will drop to the left.
Popup {
    id:             _root
    property bool _qgcPopupChrome: true
    padding:        _innerMargin
    leftPadding:    _dropRight ? _innerMargin + _arrowPointWidth : _innerMargin
    rightPadding:   _dropRight ? _innerMargin : _innerMargin + _arrowPointWidth
    modal:          true
    focus:          true
    closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside
    clip:           false
    dim:            false

    property var  sourceComponent                                               // Component to display within the popup
    property var  clickRect:        Qt.rect(0, 0, 0, 0)                         // Rectangle of clicked item - used to position drop down
    property var  dropViewPort:     Qt.rect(0, 0, parent.width, parent.height)  // Available viewport for dropdown
    property color backgroundColor: popupStyle.popupBackground
    property color borderColor:     popupStyle.borderColor
    property real  borderWidth:     1
    property real  panelRadius:     popupStyle.cornerRadius

    property var  _qgcPal:              QGroundControl.globalPalette
    property real _innerMargin:         ScreenTools.defaultFontPixelWidth * 0.5 // Margin between content and rectanglular portion of background
    property real _arrowPointWidth:     ScreenTools.defaultFontPixelWidth * 2   // Distance from vertical side to point
    property real _arrowPointPositionY: height / 2
    property bool _dropRight:           true

    QGCPopupStyle { id: popupStyle }

    onAboutToShow: {
        // Panel defaults to dropping to the right of click position
        let xPos = clickRect.x + clickRect.width

        // If there isn't room to the right then we switch to drop to the left
        if (xPos + _root.width > dropViewPort.x + dropViewPort.width) {
            _dropRight = false
            xPos = clickRect.x - _root.width
        }

        // Default position of panel is vertically centered on click position
        let yPos = clickRect.y + (clickRect.height / 2)
        yPos -= _root.height / 2

        // Make sure panel is within viewport
        let originalYPos = yPos
        yPos = Math.max(yPos, dropViewPort.y)
        yPos = Math.min(yPos, dropViewPort.y + dropViewPort.height - _root.height)

        _root.x = xPos
        _root.y = yPos

        // Adjust arrow position back to point at click position
        _arrowPointPositionY += originalYPos - yPos
    }

    background: Item {
        implicitWidth:  contentItem.implicitWidth + _innerMargin * 2 + _arrowPointWidth
        implicitHeight: contentItem.implicitHeight + _innerMargin * 2

        Item {
            anchors.fill: parent

            Rectangle {
                id:         shadowSource
                anchors.fill: parent
                radius:     _root.panelRadius
                color:      _root.backgroundColor
                visible:    false
            }

            MultiEffect {
                anchors.fill: parent
                source: shadowSource
                shadowEnabled: true
                shadowColor: "#80000000"
                shadowBlur: 0.8
                shadowScale: 1.0
                shadowVerticalOffset: 4
            }
        }

        Rectangle {
            x:      _dropRight ? _arrowPointWidth : 0
            radius: _root.panelRadius
            width:  parent.implicitWidth - _arrowPointWidth
            height: parent.implicitHeight
            color:  _root.backgroundColor
            border.color: _root.borderColor
            border.width: _root.borderWidth
        }

        // Arrowhead
        Canvas {
            x:      _dropRight ? 0 : parent.width - _arrowPointWidth
            y:      _arrowPointPositionY - _arrowPointWidth
            width:  _arrowPointWidth
            height: _arrowPointWidth * 2

            onPaint: {
                var context = getContext("2d")
                context.reset()
                context.beginPath()
                context.moveTo(_dropRight ? 0 : _arrowPointWidth, _arrowPointWidth)
                context.lineTo(_dropRight ? _arrowPointWidth : 0, 0)
                context.lineTo(_dropRight ? _arrowPointWidth : 0, _arrowPointWidth * 2)
                context.closePath()
                context.fillStyle = _root.backgroundColor
                context.fill()
            }
        }
    }

    contentItem: SettingsGroupLayout {
        Loader {
            sourceComponent: _root.sourceComponent
        }
    }
}
