import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// We implement our own TabButton to get around the fact that QtQuick.Controls TabBar does not
// support hiding tabs. This version supports hiding tabs by setting the visible property
// on the QGCTabButton instances.
Button {
    id: control
    Layout.fillWidth: true
    topPadding: _verticalPadding
    bottomPadding: _verticalPadding
    leftPadding: _horizontalPadding
    rightPadding: _horizontalPadding
    focusPolicy: Qt.ClickFocus
    checkable: true

    property bool primary: false ///< primary button for a group of buttons
    property real pointSize: ScreenTools.defaultFontPointSize ///< Point size for button text
    property bool showBorder: qgcPal.globalTheme === QGCPalette.Light
    property real backRadius: ScreenTools.defaultBorderRadius
    property real heightFactor: 0.5
    property color buttonColor: qgcPal.button
    property color checkedButtonColor: qgcPal.buttonHighlight
    property color hoverButtonColor: buttonColor
    property color buttonBorderColor: qgcPal.buttonBorder
    property color buttonTextColor: qgcPal.buttonText
    property color checkedButtonTextColor: qgcPal.buttonHighlightText
    property color separatorColor: Qt.darker(qgcPal.buttonText, 1.5)
    property int stateAnimationDuration: 200

    property bool _showSeparator: false
    property bool _showHighlight: enabled && (pressed | checked)
    property int _horizontalPadding: ScreenTools.defaultFontPixelWidth
    property int _verticalPadding: Math.round(ScreenTools.defaultFontPixelHeight * heightFactor)
    property bool _showIcon: control.icon.source != ""

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    background: Rectangle {
        id: backRect
        implicitWidth: ScreenTools.implicitButtonWidth
        implicitHeight: ScreenTools.implicitButtonHeight
        radius: backRadius
        border.width: showBorder ? 1 : 0
        border.color: buttonBorderColor
        color: control.checked || control.pressed ? checkedButtonColor : (control.hovered ? hoverButtonColor : buttonColor)

        Behavior on color { ColorAnimation { duration: control.stateAnimationDuration } }
        Behavior on border.color { ColorAnimation { duration: control.stateAnimationDuration } }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: _vertMargin
            anchors.bottomMargin: _vertMargin
            width: 1
            color: control.separatorColor
            visible: control._showSeparator

            property real _vertMargin: ScreenTools.defaultFontPixelHeight * 0.25
        }
    }

    contentItem: Item {
        implicitWidth: _showIcon ? icon.width : text.implicitWidth
        implicitHeight: _showIcon ? icon.height : text.implicitHeight
        baselineOffset: text.y + text.baselineOffset

        QGCColoredImage {
            id: icon
            anchors.centerIn: parent
            source: control.icon.source
            height: source === "" ? 0 : ScreenTools.defaultFontPixelHeight
            width: height
            color: control.checked || control.pressed ? checkedButtonTextColor : buttonTextColor
            fillMode: Image.PreserveAspectFit
            sourceSize.height: height
            visible: _showIcon
        }

        Text {
            id: text
            anchors.centerIn: parent
            antialiasing: true
            text: control.text
            font.pointSize: control.pointSize
            font.family: ScreenTools.normalFontFamily
            color: control.checked || control.pressed ? checkedButtonTextColor : buttonTextColor
            visible: !_showIcon
        }
    }
}
