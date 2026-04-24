import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Toolbar used for things like Polygon editing tools
Item {
    property bool _qgcPopupChrome: true

    width:  Math.min(toolsRowLayout.implicitWidth + (_margins * 2), availableWidth)
    height: toolsFlickable.y + toolsFlickable.height + _margins
    z:      QGroundControl.zOrderMapItems + 2

    property real availableWidth

    property real _radius:              popupStyle.cornerRadius
    property real _margins:             ScreenTools.defaultFontPixelWidth * 0.55
    property real _buttonPointSize:     Math.max(10, ScreenTools.defaultFontPointSize - 3)
    property real _buttonPadding:       ScreenTools.defaultFontPixelWidth * 0.85
    property real _buttonHeightFactor:  0.45

    function _styleToolbarControl(control) {
        if (!control) {
            return
        }

        if (typeof control.showBorder !== "undefined") {
            control.showBorder = true
        }
        if (typeof control.backRadius !== "undefined") {
            control.backRadius = popupStyle.cornerRadius
        }
        if (typeof control.pointSize !== "undefined") {
            control.pointSize = _buttonPointSize
        }
        if (typeof control.heightFactor !== "undefined") {
            control.heightFactor = _buttonHeightFactor
        }
        if (typeof control._horizontalPadding !== "undefined") {
            control._horizontalPadding = _buttonPadding
        }
        if (typeof control.stateAnimationDuration !== "undefined") {
            control.stateAnimationDuration = popupStyle.stateAnimationDuration
        }
    }

    function _centerVisibleContent() {
        if (toolsFlickable.contentWidth <= toolsFlickable.width) {
            toolsFlickable.contentX = 0
            return
        }

        toolsFlickable.contentX = (toolsFlickable.contentWidth - toolsFlickable.width) / 2
    }

    QGCPopupStyle {
        id: popupStyle
    }

    Component.onCompleted: {
        // Move the child controls from consumer into the layout control
        var moveList = []
        var i
        for (i = 2; i < children.length; i++) {
            moveList.push(children[i])
        }
        for (i = 0; i < moveList.length; i++) {
            moveList[i].parent = toolsRowLayout
            _styleToolbarControl(moveList[i])
        }
        instructionComponent.createObject(toolsRowLayout)
        _centerVisibleContent()
    }

    onWidthChanged: _centerVisibleContent()

    Rectangle {
        anchors.fill:  parent
        radius:        _radius
        color:         popupStyle.popupBackground
        opacity:       0.62
        border.width:  1
        border.color:  popupStyle.borderColor

        Rectangle {
            anchors.fill:    parent
            anchors.margins: 1
            radius:          Math.max(0, _radius - 1)
            color:           popupStyle.panelBackground
            opacity:         0.72
        }
    }

    QGCFlickable {
        id:                 toolsFlickable
        anchors.margins:    _margins
        anchors.top:        parent.top
        anchors.left:       parent.left
        anchors.right:      parent.right
        height:             toolsRowLayout.implicitHeight
        clip:               true
        flickableDirection: Flickable.HorizontalFlick
        contentWidth:       toolsRowLayout.implicitWidth
        boundsBehavior:     Flickable.StopAtBounds

        onWidthChanged: _centerVisibleContent()
        onContentWidthChanged: _centerVisibleContent()

        RowLayout {
            id:                 toolsRowLayout
            spacing:            _margins
        }
    }

    Component {
        id: instructionComponent

        QGCLabel {
            id:                 instructionLabel
            text:               _instructionText
            color:              popupStyle.secondaryTextColor
            font.pointSize:     Math.max(9, ScreenTools.defaultFontPointSize - 4)
            wrapMode:           Text.NoWrap
            verticalAlignment:  Text.AlignVCenter
        }
    }
}
