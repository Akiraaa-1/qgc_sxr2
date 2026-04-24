import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Standard push button control:
///     If there is both an icon and text the icon will be to the left of the text
///     If icon only, icon will be centered
Button {
    property bool primary: false
    property bool showBorder: qgcPal.globalTheme === QGCPalette.Light
    property real backRadius: ScreenTools.defaultBorderRadius
    property real heightFactor: 0.5
    property string iconSource: ""
    property real fontWeight: Font.Normal // default for qml Text
    property real pointSize: ScreenTools.defaultFontPointSize

    property alias wrapMode: text.wrapMode
    property alias horizontalAlignment: text.horizontalAlignment
    property alias backgroundColor: backRect.color
    property alias borderColor: backRect.border.color
    property alias textColor: text.color
    property color overlayColor: qgcPal.buttonHighlight
    property real hoverOverlayOpacity: 0.2
    property real pressedOverlayOpacity: 1.0
    property int stateAnimationDuration: 200

    id: control
    hoverEnabled: !ScreenTools.isMobile
    topPadding: _verticalPadding
    bottomPadding: _verticalPadding
    leftPadding: _horizontalPadding
    rightPadding: _horizontalPadding
    focusPolicy: Qt.ClickFocus
    font.family: ScreenTools.normalFontFamily
    text: ""

    property bool _showHighlight: enabled && (pressed | checked)
    readonly property bool _popupStyled: popupStyle.inPopupContext(control)
    property int _horizontalPadding: ScreenTools.defaultFontPixelWidth * 2
    property int _verticalPadding: Math.round(ScreenTools.defaultFontPixelHeight * heightFactor) - (iconSource === "" ? 0 : (_iconHeight - ScreenTools.defaultFontPixelHeight)  / 2)
    property real _iconHeight: text.height * 1.5

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }
    QGCPopupStyle { id: popupStyle }

    background: Rectangle {
        id: backRect
        radius: control._popupStyled ? popupStyle.cornerRadius : backRadius
        implicitWidth: ScreenTools.implicitButtonWidth
        implicitHeight: ScreenTools.implicitButtonHeight
        border.width: (control._popupStyled || showBorder) ? 1 : 0
        border.color: control._popupStyled
            ? popupStyle.borderColor
            : qgcPal.buttonBorder
        color: control._popupStyled
            ? (primary
                ? (control.pressed
                    ? popupStyle.primaryButtonPressedColor()
                    : (control.hovered ? popupStyle.primaryButtonHoverColor() : popupStyle.primaryButtonColor))
                : (control.pressed
                    ? popupStyle.secondaryButtonPressedColor()
                    : (control.hovered ? popupStyle.secondaryButtonHoverColor() : popupStyle.secondaryButtonColor)))
            : (primary ? qgcPal.primaryButton : qgcPal.button)

        Behavior on color { ColorAnimation { duration: control.stateAnimationDuration } }
        Behavior on border.color { ColorAnimation { duration: control.stateAnimationDuration } }

        Rectangle {
            anchors.fill: parent
            color: control.overlayColor
            opacity: control._popupStyled ? 0 : (_showHighlight ? control.pressedOverlayOpacity : control.enabled && control.hovered ? control.hoverOverlayOpacity : 0)
            radius: parent.radius
            Behavior on opacity { NumberAnimation { duration: control.stateAnimationDuration } }
        }
    }

    contentItem: RowLayout {
        spacing: ScreenTools.defaultFontPixelWidth

        QGCColoredImage {
            id: icon
            Layout.alignment: Qt.AlignHCenter
            source: control.iconSource
            height: _iconHeight
            width: height
            color: text.color
            fillMode: Image.PreserveAspectFit
            sourceSize.height: height
            visible: control.iconSource !== ""
        }

        QGCLabel {
            id: text
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: control.iconSource === ""
            text: control.text
            font.pointSize: control.pointSize
            font.family: control.font.family
            font.weight: fontWeight
            color: control._popupStyled
                ? (control.enabled ? popupStyle.primaryTextColor : popupStyle.disabledTextColor)
                : (_showHighlight ? qgcPal.buttonHighlightText : (primary ? qgcPal.primaryButtonText : qgcPal.buttonText))
            visible: control.text !== ""
        }
    }
}
