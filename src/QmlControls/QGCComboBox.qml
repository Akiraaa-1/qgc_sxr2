import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Templates as T

import QGroundControl
import QGroundControl.Controls

T.ComboBox {
    property bool sizeToContents: false
    property string alternateText: ""
    property color backgroundColor: qgcPal.button
    property color borderColor: qgcPal.buttonBorder
    property color focusBorderColor: borderColor
    property color textColor: qgcPal.buttonText
    property color popupBackgroundColor: qgcPal.window
    property color popupBorderColor: qgcPal.text
    property color delegateBackgroundColor: qgcPal.button
    property color delegateHoveredBackgroundColor: delegateBackgroundColor
    property color delegateSelectedBackgroundColor: qgcPal.buttonHighlight
    property color delegateTextColor: qgcPal.buttonText
    property color delegateSelectedTextColor: qgcPal.buttonHighlightText
    property real borderRadius: ScreenTools.defaultBorderRadius
    property bool showFocusBorder: false
    property int stateAnimationDuration: 200
    property bool useExplicitPopupColors: false

    id: control
    padding: ScreenTools.comboBoxPadding
    spacing: ScreenTools.defaultFontPixelWidth
    font.pointSize: ScreenTools.defaultFontPointSize
    font.family: ScreenTools.normalFontFamily
    implicitWidth: Math.max(background.implicitWidth,
                            (control.sizeToContents ? _largestTextWidth : contentItem.implicitWidth) + leftPadding + rightPadding + padding)
    implicitHeight: Math.max(background.implicitHeight,
                             Math.max(contentItem.implicitHeight, indicator ? indicator.implicitHeight : 0) + topPadding + bottomPadding)
    baselineOffset: contentItem.y + text.baselineOffset
    leftPadding: padding + (!control.mirrored || !indicator || !indicator.visible ? 0 : indicator.width + spacing)
    rightPadding: padding + (control.mirrored || !indicator || !indicator.visible ? 0 : indicator.width)

    property real _popupWidth: width
    property real _largestTextWidth: 0
    property bool _onCompleted: false
    property bool _showBorder: qgcPal.globalTheme === QGCPalette.Light
    property bool _showHighlight: enabled && pressed
    readonly property bool _popupStyled: popupStyle.inPopupContext(control)
    readonly property bool _usePopupStyle: _popupStyled && !useExplicitPopupColors

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }
    QGCPopupStyle { id: popupStyle }

    TextMetrics {
        id: textMetrics
        font.family: control.font.family
        font.pointSize: control.font.pointSize
    }

    ItemDelegate {
        id: itemDelegateMetrics
        visible: false
        font.family: control.font.family
        font.pointSize: control.font.pointSize
    }

    function _calcPopupWidth() {
        if (!_onCompleted) {
            return
        }

        let widestText = 0
        if (control.count > 0) {
            for (let i = 0; i < control.count; i++) {
                textMetrics.text = control.textAt(i)
                widestText = Math.max(textMetrics.width, widestText)
            }
        }

        _largestTextWidth = widestText

        const popupHorizontalMargins = control._popupStyled ? 8 : 0
        const contentWidth = widestText > 0
            ? widestText + itemDelegateMetrics.leftPadding + itemDelegateMetrics.rightPadding + popupHorizontalMargins
            : control.width

        _popupWidth = Math.max(control.width, contentWidth)
    }

    onModelChanged: _calcPopupWidth()
    onCountChanged: _calcPopupWidth()
    onWidthChanged: _calcPopupWidth()

    Component.onCompleted: {
        _onCompleted = true
        _calcPopupWidth()
    }

    // The items in the popup
    delegate: ItemDelegate {
        width: ListView.view
            ? Math.max(0, ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin)
            : control._popupWidth
        height: Math.round(popupItemMetrics.height * 1.75)

        property string _text: control.textRole ?
                                    (model.hasOwnProperty(control.textRole) ? model[control.textRole] : modelData[control.textRole]) :
                                    modelData

        TextMetrics {
            id: popupItemMetrics
            font: control.font
            text: _text
        }

        contentItem: Text {
            text: _text
            font: control.font
            color: control._usePopupStyle
                ? (control.enabled ? popupStyle.primaryTextColor : popupStyle.disabledTextColor)
                : (control.currentIndex === index ? control.delegateSelectedTextColor : control.delegateTextColor)
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: control._popupStyled ? popupStyle.cornerRadius : 0
            color: control._usePopupStyle
                ? (pressed
                    ? popupStyle.pressedColor(popupStyle.panelBackground)
                    : ((highlighted || hovered || control.currentIndex === index)
                        ? popupStyle.hoverColor(popupStyle.panelBackground)
                        : "transparent"))
                : (control.currentIndex === index
                    ? control.delegateSelectedBackgroundColor
                    : ((highlighted || hovered || pressed) ? control.delegateHoveredBackgroundColor : control.delegateBackgroundColor))
            Behavior on color { ColorAnimation { duration: control.stateAnimationDuration } }
        }

        highlighted: control.highlightedIndex === index
    }

    indicator: QGCColoredImage {
        anchors.rightMargin: control.padding
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: ScreenTools.defaultFontPixelWidth
        width: height
        source: "/qmlimages/arrow-down.png"
        color: control._usePopupStyle ? popupStyle.primaryTextColor : control.textColor
    }

    // The label of the button
    contentItem: QGCLabel {
        id: text
        text: control.alternateText === "" ? control.currentText : control.alternateText
        font: control.font
        color: control._usePopupStyle
            ? (control.enabled ? popupStyle.primaryTextColor : popupStyle.disabledTextColor)
            : control.textColor
        elide: Text.ElideRight
    }

    background: Rectangle {
        color: control._usePopupStyle ? popupStyle.inputBackground : control.backgroundColor
        border.color: (control.showFocusBorder || control._usePopupStyle) && control.activeFocus
            ? (control._usePopupStyle ? popupStyle.accentColor : control.focusBorderColor)
            : (control._usePopupStyle ? popupStyle.borderColor : control.borderColor)
        border.width: (control._usePopupStyle || control._showBorder || control.showFocusBorder) ? 1 : 0
        radius: control._usePopupStyle ? popupStyle.cornerRadius : control.borderRadius

        Behavior on color { ColorAnimation { duration: control.stateAnimationDuration } }
        Behavior on border.color { ColorAnimation { duration: control.stateAnimationDuration } }

        Rectangle {
            anchors.fill: parent
            color: control._usePopupStyle ? popupStyle.focusGlowColor(0.35) : control.delegateSelectedBackgroundColor
            opacity: control._usePopupStyle
                ? (control.activeFocus ? 1 : 0)
                : (control._showHighlight ? 1 : control.enabled && control.hovered ? .2 : 0)
            radius: parent.radius
            Behavior on opacity { NumberAnimation { duration: control.stateAnimationDuration } }
        }
    }

    popup: T.Popup {
        x: Math.max(-_controlPos.x, Math.min(control.width - control._popupWidth, control.Window.width - _controlPos.x - control._popupWidth))
        y: _openAbove ? -height : control.height
        width: control._popupWidth
        height: Math.min(contentItem.implicitHeight, _openAbove ? _spaceAbove : _spaceBelow)
        topMargin: 6
        bottomMargin: 6

        readonly property point _controlPos:    control.mapToItem(null, 0, 0)
        readonly property real  _spaceBelow:    Math.max(0, control.Window.height - _controlPos.y - control.height - bottomMargin)
        readonly property real  _spaceAbove:    Math.max(0, _controlPos.y - topMargin)
        readonly property bool  _openAbove:     contentItem.implicitHeight > _spaceBelow && _spaceAbove > _spaceBelow

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            highlightMoveDuration: 0
            spacing: control._popupStyled ? 2 : 0
            leftMargin: control._popupStyled ? 4 : 0
            rightMargin: control._popupStyled ? 4 : 0
            topMargin: control._popupStyled ? 4 : 0
            bottomMargin: control._popupStyled ? 4 : 0

            T.ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: Item {
            implicitWidth: control._popupWidth
            implicitHeight: contentItem.implicitHeight

            Rectangle {
                id:         comboPopupShadowSource
                anchors.fill: parent
                radius:     control._usePopupStyle ? popupStyle.cornerRadius : control.borderRadius
                color:      control._usePopupStyle ? popupStyle.popupBackground : control.popupBackgroundColor
                visible:    false
            }

            MultiEffect {
                anchors.fill: parent
                source: comboPopupShadowSource
                shadowEnabled: true
                shadowColor: "#80000000"
                shadowBlur: 0.8
                shadowScale: 1.0
                shadowVerticalOffset: 4
            }

            Rectangle {
                anchors.fill: parent
                color: control._usePopupStyle ? popupStyle.popupBackground : control.popupBackgroundColor
                border.width: 1
                border.color: control._usePopupStyle ? popupStyle.borderColor : control.popupBorderColor
                radius: control._usePopupStyle ? popupStyle.cornerRadius : control.borderRadius
            }
        }
    }
}
