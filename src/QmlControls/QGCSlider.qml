import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Slider {
    property bool zeroCentered: false ///< Value indicator starts display from zero instead of min value
    property bool displayValue: false ///< true: Show value on handle
    property bool showBoundaryValues: false ///< true: Show min/max values at slider ends
    property bool reserveBoundaryLabelSpace: false ///< true: keep handle/track above boundary labels
    property real boundaryLabelGap: 0

    id: control
    implicitHeight: ScreenTools.implicitSliderHeight
                    + (showBoundaryValues ? Math.max(minLabel.contentHeight, maxLabel.contentHeight) : 0)
                    + (showBoundaryValues && reserveBoundaryLabelSpace ? boundaryLabelGap : 0)
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: showBoundaryValues && reserveBoundaryLabelSpace
                   ? Math.max(minLabel.contentHeight, maxLabel.contentHeight) + boundaryLabelGap
                   : 0
    wheelEnabled: false

    property real _implicitBarLength: Math.round(ScreenTools.defaultFontPixelWidth * 20)
    property real barHeight: ScreenTools.defaultFontPixelHeight / 3
    property real handleDiameter: ScreenTools.defaultFontPixelHeight
    property real labelPointSize: ScreenTools.smallFontPointSize
    property real _barHeight: Math.round(barHeight)
    property color trackColor: qgcPal.button
    property color trackBorderColor: qgcPal.buttonText
    property color handleColor: qgcPal.button
    property color handleBorderColor: qgcPal.buttonText
    property color labelColor: qgcPal.buttonText

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    background: Rectangle {
        x: control.horizontal ? control.leftPadding : control.leftPadding + control.availableWidth / 2 - width / 2
        y: control.horizontal ? control.topPadding + control.availableHeight / 2 - height / 2 : control.topPadding
        implicitWidth: control.horizontal ? control._implicitBarLength : control._barHeight
        implicitHeight: control.horizontal ? control._barHeight : control._implicitBarLength
        width: control.horizontal ? control.availableWidth : implicitWidth
        height: control.horizontal ? implicitHeight : control.availableHeight
        radius: control._barHeight / 2
        color: control.trackColor
        border.width: 1
        border.color: control.trackBorderColor
    }

    handle: Rectangle {
        x: control.horizontal ?
               control.leftPadding + control.visualPosition * (control.availableWidth - width) :
               control.leftPadding + control.availableWidth / 2 - width / 2
        y: control.horizontal ?
               control.topPadding + control.availableHeight / 2 - height / 2 :
               control.topPadding + control.visualPosition * (control.availableHeight - height)
        implicitWidth: _radius * 2
        implicitHeight: _radius * 2
        color: control.handleColor
        border.color: control.handleBorderColor
        border.width: 1
        radius: _radius

        property real _radius: control.handleDiameter / 2

        Label {
            text: control.value.toFixed(control.to <= 1 ? 1 : 0)
            visible: control.displayValue
            anchors.centerIn: parent
            font.family: ScreenTools.normalFontFamily
            font.pointSize: control.labelPointSize
            color: control.labelColor
        }
    }

    QGCLabel {
        id: minLabel
        anchors.left: parent.left
        anchors.leftMargin: control.leftPadding
        anchors.bottom: parent.bottom
        text: control.from.toFixed(1)
        font.pointSize: control.labelPointSize
        color: control.labelColor
        visible: control.showBoundaryValues
    }

    QGCLabel {
        id: maxLabel
        anchors.right: parent.right
        anchors.rightMargin: control.rightPadding
        anchors.bottom: parent.bottom
        text: control.to.toFixed(1)
        font.pointSize: control.labelPointSize
        color: control.labelColor
        visible: control.showBoundaryValues
    }
}
