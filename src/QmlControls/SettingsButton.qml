import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Button {
    id:             control
    padding:        ScreenTools.defaultFontPixelWidth * 0.75
    hoverEnabled:   !ScreenTools.isMobile
    autoExclusive:  true
    icon.color:     textColor

    property color textColor: checked || pressed
        ? (control._popupStyled ? popupStyle.primaryTextColor : qgcPal.buttonHighlightText)
        : (control._popupStyled ? popupStyle.secondaryTextColor : qgcPal.buttonText)
    property bool expandable: false
    property bool expanded:   false

    signal toggleExpand()

    readonly property bool _popupStyled: popupStyle.inPopupContext(control)

    QGCPalette {
        id:                 qgcPal
        colorGroupEnabled:  control.enabled
    }

    QGCPopupStyle { id: popupStyle }

    background: Rectangle {
        color: control._popupStyled
            ? (control.checked
                ? Qt.rgba(popupStyle.accentColor.r, popupStyle.accentColor.g, popupStyle.accentColor.b, 0.24)
                : (control.pressed
                    ? popupStyle.pressedColor(popupStyle.panelBackground)
                    : (control.enabled && control.hovered
                        ? popupStyle.hoverColor(popupStyle.panelBackground)
                        : "transparent")))
            : qgcPal.buttonHighlight
        opacity: control._popupStyled ? 1 : (control.checked || control.pressed ? 1 : control.enabled && control.hovered ? .2 : 0)
        radius: control._popupStyled ? popupStyle.cornerRadius : ScreenTools.defaultFontPixelWidth / 2
        border.width: control._popupStyled && control.checked ? 1 : 0
        border.color: control.checked ? popupStyle.accentColor : popupStyle.borderColor

        Behavior on color { ColorAnimation { duration: popupStyle.stateAnimationDuration } }
        Behavior on border.color { ColorAnimation { duration: popupStyle.stateAnimationDuration } }
    }

    contentItem: RowLayout {
        spacing: ScreenTools.defaultFontPixelWidth

        QGCColoredImage {
            source: control.icon.source
            color:  control.icon.color
            width:  ScreenTools.defaultFontPixelHeight
            height: ScreenTools.defaultFontPixelHeight
        }

        QGCLabel {
            id:                     displayText
            Layout.fillWidth:       true
            text:                   control.text
            color:                  control.textColor
            horizontalAlignment:    QGCLabel.AlignLeft
        }

        QGCColoredImage {
            visible:    control.expandable
            source:     "/InstrumentValueIcons/cheveron-right.svg"
            color:      control.textColor
            width:      ScreenTools.defaultFontPixelHeight * 0.75
            height:     width
            rotation:   control.expanded ? 90 : 0

            MouseArea {
                anchors.fill: parent
                anchors.margins: -ScreenTools.defaultFontPixelWidth
                onClicked: control.toggleExpand()
            }
        }
    }
}
